import SwiftUI

struct StartupInventoryView: View {
    @State private var report: LaunchdReport?
    @State private var error: String?
    @State private var request = 0
    @State private var loading = false
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("O que acompanha sua sessão.").font(.title.bold())
            Text("Inventário de declarações LaunchAgents do usuário, compartilhadas e do sistema. Presença, RunAtLoad e Disabled não comprovam o estado efetivo: overrides do launchd e itens modernos de login podem diferir.").font(.caption).foregroundStyle(.secondary)
            HStack {
                Button("Atualizar") { request += 1 }.disabled(loading)
                Button("Abrir Itens de Início de Sessão") { NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.LoginItems-Settings.extension")!) }
            }
            if loading { ProgressView("Lendo declarações…") }
            if let error { Text(error).foregroundStyle(.orange) }
            if let report {
                Text("\(report.records.count) declarações").font(.headline)
                ForEach(report.issues, id: \.self) { Text($0).font(.caption).foregroundStyle(.orange) }
                LazyVStack(alignment: .leading, spacing: 12) {
                    ForEach(report.records) { record in
                        VStack(alignment: .leading, spacing: 8) {
                            Text(record.label ?? record.url.lastPathComponent).font(.headline)
                            Text(record.url.path).font(.caption).textSelection(.enabled)
                            LabeledContent("Programa declarado", value: record.program ?? "Não informado")
                            LabeledContent("RunAtLoad declarado", value: record.runAtLoad.map { $0 ? "Sim" : "Não" } ?? "Não informado")
                            LabeledContent("Disabled declarado", value: record.disabled.map { $0 ? "Sim" : "Não" } ?? "Não informado")
                            LabeledContent("KeepAlive declarado", value: record.keepAlive ?? "Não informado")
                            ForEach(record.issues, id: \.self) { Text($0).foregroundStyle(.orange) }
                            Button("Mostrar declaração no Finder") { NSWorkspace.shared.activateFileViewerSelecting([record.url]) }
                        }.font(.caption).padding(20).frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 16))
                    }
                }
            }
        }
        .task(id: request) {
            loading = true; error = nil
            defer { loading = false }
            let worker = Task.detached(priority: .utility) { try LaunchdInventory.inspect() }
            do {
                let value = try await withTaskCancellationHandler { try await worker.value } onCancel: { worker.cancel() }
                try Task.checkCancellation(); report = value
            } catch is CancellationError {} catch { self.error = error.localizedDescription }
        }
    }
}
