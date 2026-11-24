import SwiftUI

struct ApplicationUpdatesView: View {
    let app: InstalledApplication
    @Environment(\.dismiss) private var dismiss
    @State private var feed: URL?
    @State private var versions: [AppcastVersion]?
    @State private var message = ""
    @State private var loading = false
    @State private var request = 0
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack { Text("Atualizações de " + app.name).font(.title2.bold()); Spacer(); Button("Concluir") { dismiss() } }
            Text("Instalado: " + (app.version ?? "versão desconhecida") + " · build " + (app.buildVersion ?? "desconhecido"))
            Text("Consulta informativa. Não baixa nem instala atualizações. Condições de sistema, hardware, canais e licenciamento devem ser verificadas no atualizador do aplicativo.").font(.caption).foregroundStyle(.secondary)
            if let feed { Text("Feed declarado no aplicativo assinado: " + feed.absoluteString).font(.caption).textSelection(.enabled) }
            Text(message).font(.caption)
            HStack {
                Button("Consultar feed declarado") { request += 1 }.disabled(loading)
                Button("Abrir atualizações da App Store") { NSWorkspace.shared.open(URL(string: "macappstore://showUpdatesPage")!) }
            }
            if loading { ProgressView("Verificando fonte e consultando versões…") }
            if let versions {
                List(Array(versions.enumerated()), id: \.offset) { _, release in
                    VStack(alignment: .leading, spacing: 5) {
                        Text("Versão " + (release.display.isEmpty ? release.build : release.display) + " · build " + release.build)
                        if let installed = app.buildVersion, let comparison = ApplicationUpdates.compareNumeric(release.build, installed) {
                            Text(comparison == .orderedDescending ? "Build numericamente superior ao instalado; confirme os requisitos no aplicativo." : "Este item não possui build numericamente superior.").font(.caption)
                        } else { Text("Comparação automática indisponível para estas versões.").font(.caption) }
                        Text("macOS mínimo: " + (release.minimumSystem.isEmpty ? "não declarado" : release.minimumSystem) + " · canal: " + (release.channel.isEmpty ? "padrão" : release.channel)).font(.caption).foregroundStyle(.secondary)
                    }.padding(.vertical, 5)
                }.frame(minHeight: 200)
            }
        }.padding(24).frame(minWidth: 760, minHeight: 440)
        .task(id: request) {
            guard request > 0 else { return }
            loading = true; versions = nil; message = ""; feed = nil
            defer { loading = false }
            do {
                let worker = Task.detached(priority: .utility) { try ApplicationUpdates.feed(for: app) }
                let source = try await withTaskCancellationHandler { try await worker.value } onCancel: { worker.cancel() }
                guard let source else { message = "Nenhum feed SUFeedURL declarado. Use a App Store ou o atualizador do aplicativo."; return }
                feed = source
                versions = try await ApplicationUpdates.fetch(source)
                message = "A lista contém somente as versões anunciadas por esta fonte; não é uma confirmação de compatibilidade."
            } catch is CancellationError {} catch { message = error.localizedDescription }
        }
    }
}
