import SwiftUI

struct ApplicationDataView: View {
    let app: InstalledApplication
    var identityMatches = 1
    var history: AnalysisHistory? = nil
    @Environment(\.dismiss) private var dismiss
    @State private var report: ApplicationDataReport?
    @State private var error: String?
    @State private var snapshot: BundleSnapshot?
    @State private var preparing = false
    @State private var confirming = false
    @State private var uninstallReport: RemovalReport?
    @State private var operation: Task<Void, Never>?
    @State private var reviewing: AssociatedData?
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack { Text("Dados de " + app.name).font(.title2.bold()); Spacer(); Button("Concluir") { dismiss() } }
            if let report {
                Text(report.note).font(.caption).foregroundStyle(.secondary)
                Text("Revise os dados abaixo antes de desinstalar. A desinstalação envia apenas o pacote .app à Lixeira; dados compartilhados nunca são removidos automaticamente.").font(.caption)
                HStack {
                    Button("Preparar desinstalação", role: .destructive) { prepareUninstall() }.disabled(preparing || uninstallReport?.movedCount == 1)
                    if preparing { ProgressView().controlSize(.small); Button("Cancelar") { operation?.cancel() } }
                }
                if let error { Text(error).foregroundStyle(.orange) }
                if let uninstallReport { RemovalReportView(report: uninstallReport) }
                List(report.items) { item in
                    VStack(alignment: .leading, spacing: 7) {
                        HStack {
                            Text(item.title).font(.headline)
                            Text(item.shared ? "Compartilhado / uso múltiplo" : "Exclusividade não comprovada").font(.caption).foregroundStyle(item.shared ? Color.orange : .secondary)
                            Spacer()
                            Text(item.state.rawValue)
                            if let bytes = item.bytes { Text(ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)) }
                            if item.state == .present { Button("Revisar") { reviewing = item } }
                        }
                        Text(item.url.path).font(.caption).textSelection(.enabled)
                        Text(item.detail).font(.caption).foregroundStyle(.secondary)
                    }.padding(.vertical, 6)
                }
            } else if let error { Text(error).foregroundStyle(.orange) }
            else { ProgressView("Localizando e medindo dados…").frame(maxWidth: .infinity, maxHeight: .infinity) }
        }.padding(24).frame(minWidth: 800, minHeight: 560)
        .confirmationDialog("Desinstalar " + app.name + "?", isPresented: $confirming, titleVisibility: .visible) {
            Button("Enviar aplicativo à Lixeira", role: .destructive) { uninstall() }
            Button("Cancelar", role: .cancel) { snapshot = nil }
        } message: { Text(app.url.path + "\nSomente o pacote do aplicativo será enviado à Lixeira. Os dados associados permanecem para revisão individual.") }
        .onDisappear { operation?.cancel() }
        .sheet(item: $reviewing) { item in
            if item.isDirectory { FileReviewView(root: item.url, allowsRemoval: !item.shared, history: history) }
            else { FilePreviewView(url: item.url) }
        }
        .task(id: app.id) {
            let task = Task.detached(priority: .utility) { try ApplicationDataAnalyzer.inspect(app, identityMatches: identityMatches) }
            do {
                let value = try await withTaskCancellationHandler { try await task.value } onCancel: { task.cancel() }
                try Task.checkCancellation(); report = value
            } catch is CancellationError {} catch { self.error = error.localizedDescription }
        }
    }
    private func prepareUninstall() {
        guard !preparing else { return }
        preparing = true; error = nil
        operation = Task { @MainActor in
            let worker = Task.detached(priority: .utility) { try BundleSnapshot.prepare(app.url) }
            defer { preparing = false; operation = nil }
            do {
                let value = try await withTaskCancellationHandler { try await worker.value } onCancel: { worker.cancel() }
                try Task.checkCancellation(); snapshot = value; confirming = true
            } catch { self.error = error.localizedDescription }
        }
    }
    private func uninstall() {
        guard !preparing, let snapshot else { return }
        preparing = true
        operation = Task { @MainActor in
            let worker = Task.detached(priority: .utility) { await BundleUninstaller.run(snapshot) }
            let report = await withTaskCancellationHandler { await worker.value } onCancel: { worker.cancel() }
            uninstallReport = report
            history?.record(scope: app.name, outcome: "Desinstalação: \(report.movedCount) pacote enviado à Lixeira", itemCount: report.entries.count, report: report)
            preparing = false; operation = nil; self.snapshot = nil
        }
    }

}
