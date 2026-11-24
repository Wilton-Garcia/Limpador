import SwiftUI

struct ApplicationDataView: View {
    let app: InstalledApplication
    @Environment(\.dismiss) private var dismiss
    @State private var report: ApplicationDataReport?
    @State private var error: String?
    @State private var reviewing: AssociatedData?
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack { Text("Dados de " + app.name).font(.title2.bold()); Spacer(); Button("Concluir") { dismiss() } }
            if let report {
                Text(report.note).font(.caption).foregroundStyle(.secondary)
                List(report.items) { item in
                    VStack(alignment: .leading, spacing: 7) {
                        HStack {
                            Text(item.title).font(.headline)
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
        .sheet(item: $reviewing) { item in
            if item.isDirectory { FileReviewView(root: item.url) }
            else { FilePreviewView(url: item.url) }
        }
        .task(id: app.id) {
            let task = Task.detached(priority: .utility) { try ApplicationDataAnalyzer.inspect(app) }
            do {
                let value = try await withTaskCancellationHandler { try await task.value } onCancel: { task.cancel() }
                try Task.checkCancellation(); report = value
            } catch is CancellationError {} catch { self.error = error.localizedDescription }
        }
    }
}
