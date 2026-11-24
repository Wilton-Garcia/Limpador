import SwiftUI

struct StartupInventoryView: View {
    let applications: [InstalledApplication]?
    @State private var extensions: ExtensionReport?
    @State private var scope = "Agentes"
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
            Picker("Inventário", selection: $scope) {
                Text("Agentes").tag("Agentes")
                Text("Serviços de sistema").tag("Serviços")
                Text("Extensões e auxiliares").tag("Extensões")
            }.pickerStyle(.segmented).onChange(of: scope) { _, _ in request += 1 }
            if scope == "Extensões" {
                Text("Componentes incorporados aos aplicativos inventariados. Presença no pacote não comprova que estejam ativados ou em execução. Não inclui extensões instaladas fora desses pacotes.").font(.caption).foregroundStyle(.secondary)
                if applications == nil { Text("Carregue o inventário de aplicativos para pesquisar seus componentes.").foregroundStyle(.orange) }
            }
            if loading { ProgressView("Lendo declarações…") }
            if let error { Text(error).foregroundStyle(.orange) }
            if scope != "Extensões", let report {
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
            if scope == "Extensões", let extensions {
                Text("\(extensions.entries.count) componentes").font(.headline)
                ForEach(extensions.issues, id: \.self) { Text($0).font(.caption).foregroundStyle(.orange) }
                LazyVStack(alignment: .leading, spacing: 12) {
                    ForEach(extensions.entries) { entry in
                        VStack(alignment: .leading, spacing: 7) {
                            Text(entry.name).font(.headline)
                            Text(entry.kind)
                            Text(entry.identifier ?? "Identificador não declarado")
                            if let point = entry.point { Text("Ponto de extensão: " + point) }
                            Text(entry.url.path).textSelection(.enabled)
                            Button("Mostrar no Finder") { NSWorkspace.shared.activateFileViewerSelecting([entry.url]) }
                        }.font(.caption).padding(20).frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 16))
                    }
                }
            }
        }
        .task(id: request) {
            loading = true; error = nil; report = nil; extensions = nil
            defer { loading = false }
            if scope == "Extensões" {
                let apps = applications ?? []
                let worker = Task.detached(priority: .utility) { try ExtensionInventory.inspect(apps) }
                do {
                    let value = try await withTaskCancellationHandler { try await worker.value } onCancel: { worker.cancel() }
                    try Task.checkCancellation(); extensions = value
                } catch is CancellationError {} catch { self.error = error.localizedDescription }
                return
            }
            let roots = scope == "Serviços" ? LaunchdInventory.daemonRoots : LaunchdInventory.agentRoots
            let worker = Task.detached(priority: .utility) { try LaunchdInventory.inspect(roots: roots) }
            do {
                let value = try await withTaskCancellationHandler { try await worker.value } onCancel: { worker.cancel() }
                try Task.checkCancellation(); report = value
            } catch is CancellationError {} catch { self.error = error.localizedDescription }
        }
    }
}
