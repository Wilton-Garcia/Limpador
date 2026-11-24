import SwiftUI
@preconcurrency import UserNotifications

struct ReminderSchedule: Codable, Equatable {
    var enabled = false
    var weekly = true
    var weekday = 2
    var hour = 9
    var minute = 0
    func components(timeZone: TimeZone = .current) -> DateComponents {
        var value = DateComponents()
        value.timeZone = timeZone
        value.hour = hour; value.minute = minute
        if weekly { value.weekday = weekday }
        return value
    }
    var valid: Bool { (0...23).contains(hour) && (0...59).contains(minute) && (1...7).contains(weekday) }
}

@MainActor enum AnalysisReminders {
    static let identifier = "limpador.analysis-reminder"
    static func save(_ schedule: ReminderSchedule) async throws {
        guard schedule.valid else { throw CocoaError(.propertyListReadCorrupt) }
        let center = UNUserNotificationCenter.current()
        if schedule.enabled {
            guard await NativeNotifications.shared.requestPermission() else { throw CocoaError(.userCancelled) }
            let content = UNMutableNotificationContent()
            content.title = "Hora de revisar o espaço do seu Mac"
            content.body = "Abra o Limpador para analisar e revisar seus arquivos. Nenhuma limpeza é executada automaticamente."
            content.sound = .default
            let trigger = UNCalendarNotificationTrigger(dateMatching: schedule.components(), repeats: true)
            try await center.add(UNNotificationRequest(identifier: identifier, content: content, trigger: trigger))
        } else {
            center.removePendingNotificationRequests(withIdentifiers: [identifier])
            center.removeDeliveredNotifications(withIdentifiers: [identifier])
        }
        UserDefaults.standard.set(try JSONEncoder().encode(schedule), forKey: "analysisReminderSchedule")
    }
}

struct AnalysisReminderPreferences: View {
    @State private var schedule = ReminderSchedule()
    @State private var message: String?
    @State private var saving = false
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Lembretes de análise").font(.headline)
            Toggle("Receber lembretes", isOn: $schedule.enabled)
            if schedule.enabled {
                Picker("Frequência", selection: $schedule.weekly) { Text("Diária").tag(false); Text("Semanal").tag(true) }
                if schedule.weekly {
                    Picker("Dia", selection: $schedule.weekday) {
                        ForEach(1...7, id: \.self) { day in Text(Calendar.current.weekdaySymbols[day - 1]).tag(day) }
                    }
                }
                HStack {
                    Stepper("Hora: \(schedule.hour)", value: $schedule.hour, in: 0...23)
                    Stepper("Minuto: \(schedule.minute)", value: $schedule.minute, in: 0...59)
                }
            }
            Button("Salvar lembrete") {
                saving = true
                Task { @MainActor in
                    defer { saving = false }
                    do { try await AnalysisReminders.save(schedule); message = schedule.enabled ? "Lembrete agendado no horário local do Mac." : "Lembrete desativado." }
                    catch { message = "Não foi possível salvar: " + error.localizedDescription }
                }
            }.disabled(saving)
            Text("As mudanças só entram em vigor ao salvar. O lembrete usa notificações do macOS e não executa análises ou limpezas automaticamente.").font(.caption).foregroundStyle(.secondary)
            if let message { Text(message).font(.caption) }
        }
        .task {
            if let data = UserDefaults.standard.data(forKey: "analysisReminderSchedule") {
                do {
                    let stored = try JSONDecoder().decode(ReminderSchedule.self, from: data)
                    guard stored.valid else { throw CocoaError(.propertyListReadCorrupt) }
                    schedule = stored
                } catch { message = "Preferências de lembrete não puderam ser lidas. O registro existente foi preservado." }
            }
        }
    }
}
