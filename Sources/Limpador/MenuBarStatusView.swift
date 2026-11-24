import SwiftUI

struct MenuBarStatusView: View {
    @Environment(\.openWindow) private var openWindow
    @State private var disk: DiskSnapshot?
    @State private var error: String?
    @State private var request = 0
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("Limpador", systemImage: "sparkles").font(.headline)
            if let disk {
                Text(disk.name).font(.caption).foregroundStyle(.secondary)
                Text(ByteCountFormatter.string(fromByteCount: disk.available, countStyle: .file) + " disponíveis").font(.title3.bold())
                ProgressView(value: Double(disk.used), total: Double(disk.total))
                Text("Lido às " + disk.observedAt.formatted(date: .omitted, time: .standard)).font(.caption2).foregroundStyle(.secondary)
            } else if let error { Text(error).font(.caption).foregroundStyle(.orange) }
            else { ProgressView("Lendo armazenamento…") }
            Button("Atualizar leitura") { request += 1 }
            Divider()
            Button("Abrir Limpador") { openWindow(id: "main"); NSApp.activate(ignoringOtherApps: true) }
                .keyboardShortcut("o", modifiers: .command)
            Button("Encerrar Limpador") { NSApp.terminate(nil) }.keyboardShortcut("q", modifiers: .command)
        }.padding(20).frame(width: 300)
        .task(id: request) {
            disk = nil; error = nil
            do { disk = try DiskSnapshot.read() } catch { self.error = error.localizedDescription }
        }
    }
}
