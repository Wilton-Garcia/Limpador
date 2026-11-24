import SwiftUI
@preconcurrency import UserNotifications

struct LowSpacePolicy {
    var wasLow: Bool?
    var lastSent: Date?
    mutating func shouldNotify(available: Int64, threshold: Int64, now: Date) -> Bool {
        let low = available < threshold
        let crossed = wasLow == false && low
        wasLow = low
        guard low else { return false }
        return crossed || lastSent == nil || now.timeIntervalSince(lastSent!) >= 24 * 60 * 60
    }
}

@MainActor @Observable
final class NativeNotifications {
    static let shared = NativeNotifications()
    private var task: Task<Void, Never>?
    private(set) var issue: String?
    private var policy = LowSpacePolicy(lastSent: UserDefaults.standard.object(forKey: "lastLowSpaceNotification") as? Date)
    func start() {
        guard task == nil else { return }
        task = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                await self?.checkSpace()
                do { try await Task.sleep(for: .seconds(60)) } catch { break }
            }
        }
    }
    func stop() { task?.cancel(); task = nil }
    func requestPermission() async -> Bool {
        do { return try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) }
        catch { issue = error.localizedDescription; return false }
    }
    private func checkSpace() async {
        guard UserDefaults.standard.bool(forKey: "lowSpaceAlerts") else { return }
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        guard settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional else {
            issue = "Avisos de pouco espaço aguardam autorização nas notificações do macOS."; return
        }
        do {
            let disk = try DiskSnapshot.read()
            let thresholdGB = min(1000, max(1, UserDefaults.standard.integer(forKey: "lowSpaceThresholdGB") == 0 ? 10 : UserDefaults.standard.integer(forKey: "lowSpaceThresholdGB")))
            let now = Date()
            guard policy.shouldNotify(available: disk.available, threshold: Int64(thresholdGB) * 1_000_000_000, now: now) else { return }
            let content = UNMutableNotificationContent()
            content.title = "Pouco espaço no seu Mac"
            content.body = "Disponível em " + disk.name + ": " + ByteCountFormatter.string(fromByteCount: disk.available, countStyle: .file) + ". Abra o Limpador para revisar seus arquivos."
            content.sound = .default
            try await UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: "limpador.low-space", content: content, trigger: nil))
            policy.lastSent = now
            UserDefaults.standard.set(now, forKey: "lastLowSpaceNotification")
            issue = nil
        } catch { issue = error.localizedDescription }
    }
}

final class LimpadorApplicationDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) { NativeNotifications.shared.start() }
    func applicationWillTerminate(_ notification: Notification) { NativeNotifications.shared.stop() }
}

struct NotificationPreferencesView: View {
    @AppStorage("lowSpaceAlerts") private var enabled = false
    @AppStorage("lowSpaceThresholdGB") private var threshold = 10
    @State private var message: String?
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Avisos de pouco espaço").font(.headline)
            Toggle("Avisar quando o espaço disponível estiver baixo", isOn: $enabled)
                .onChange(of: enabled) { _, value in
                    if value {
                        Task { @MainActor in
                            let allowed = await NativeNotifications.shared.requestPermission()
                            message = allowed ? "Notificações autorizadas." : "Autorize as notificações nos Ajustes do Sistema."
                        }
                    }
                }
            Stepper("Limite: \(threshold) GB", value: $threshold, in: 1...1000).disabled(!enabled)
            Text("Verificação a cada minuto enquanto o Limpador estiver aberto. Repete após 24 horas ou se o espaço se recuperar e voltar a ficar baixo.").font(.caption).foregroundStyle(.secondary)
            if let message { Text(message).font(.caption) }
            if let issue = NativeNotifications.shared.issue { Text(issue).font(.caption).foregroundStyle(.orange) }
        }
    }
}
