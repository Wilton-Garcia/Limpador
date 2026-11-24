import SwiftUI

@MainActor @Observable
final class MacDataModel {
    let history = AnalysisHistory()
    var disk: DiskSnapshot?
    var diskError: String?
    var inventory: ApplicationInventory?
    var inventoryError: String?
    var loading = false
    var progress: InventoryProgress?
    var cancelling = false
    private var worker: Task<ApplicationInventory, Error>?

    func refresh() async {
        guard !loading else { return }
        loading = true
        progress = nil
        diskError = nil
        inventoryError = nil
        defer { loading = false; progress = nil; worker = nil; cancelling = false }
        // A refresh replaces previous results so old observations never appear current.
        disk = nil
        inventory = nil
        do { disk = try DiskSnapshot.read() }
        catch { diskError = error.localizedDescription }
        let worker = Task.detached(priority: .utility) {
            try await MacInventory.applications { progress in
                await self.setProgress(progress)
            }
        }
        self.worker = worker
        do {
            let result = try await withTaskCancellationHandler {
                try await worker.value
            } onCancel: {
                worker.cancel()
            }
            try Task.checkCancellation()
            inventory = result
            history.record(scope: "Aplicativos", outcome: result.issues.isEmpty && result.apps.allSatisfy { $0.size.complete } ? "Concluída" : "Parcial", itemCount: result.apps.count, bytes: result.apps.reduce(0) { $0 + $1.size.bytes })
        } catch is CancellationError {
            history.record(scope: "Aplicativos", outcome: "Cancelada")
            inventoryError = "Leitura interrompida. Atualize para tentar novamente."
        } catch { inventoryError = error.localizedDescription; history.record(scope: "Aplicativos", outcome: "Falha: " + error.localizedDescription) }
    }

    func cancel() {
        guard loading else { return }
        cancelling = true
        worker?.cancel()
    }

    private func setProgress(_ progress: InventoryProgress) { self.progress = progress }
}

struct ApplicationRow: View {
    let app: InstalledApplication
    var onInspect: () -> Void = {}
    @State private var image: NSImage?
    var body: some View {
        HStack(spacing: 14) {
            Group {
                if let image { Image(nsImage: image).resizable().scaledToFit() }
                else { Image(systemName: "app.dashed").resizable().scaledToFit().padding(8) }
            }.frame(width: 42, height: 42).accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 5) {
                Text(app.name).font(.system(size: 14, weight: .semibold))
                Text(app.version.map { "Versão \($0)" } ?? "Versão não informada")
                    .font(.system(size: 11)).foregroundStyle(.secondary)
                Text(app.url.path).font(.system(size: 10)).foregroundStyle(.secondary)
                    .lineLimit(1).truncationMode(.middle).help(app.url.path)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 4) {
                Text(ByteCountFormatter.string(fromByteCount: app.size.bytes, countStyle: .file))
                    .font(.system(size: 13, weight: .medium)).monospacedDigit()
                Text(app.size.complete ? "Pacote · tamanho lógico" : "Parcial · \(app.size.unreadableEntries) falhas")
                    .font(.system(size: 10)).foregroundStyle(app.size.complete ? Color.secondary : .orange)
            }
            Button("Arquivos", action: onInspect).buttonStyle(.borderless)
            Button { NSWorkspace.shared.activateFileViewerSelecting([app.url]) } label: {
                Image(systemName: "folder")
            }.buttonStyle(.borderless).help("Mostrar no Finder").accessibilityLabel("Mostrar \(app.name) no Finder")
        }
        .padding(20)
        .task(id: app.id) { image = NSWorkspace.shared.icon(forFile: app.url.path) }
    }
}
