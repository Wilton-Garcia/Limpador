import SwiftUI

struct LeftoverView: View {
    let inventory: ApplicationInventory
    let history: AnalysisHistory
    @Environment(\.dismiss) private var dismiss
    @State private var report: LeftoverReport?
    @State private var error: String?
    @State private var reviewing: AssociatedData?
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack { Text("Possíveis sobras de aplicativos").font(.title2.bold()); Spacer(); Button("Concluir") { dismiss() } }
            Text("São caminhos com nomes semelhantes a identificadores não encontrados no inventário atual. Isso não comprova que sejam sobras: outros aplicativos, serviços ou instalações fora das pastas pesquisadas podem utilizá-los. Grupos compartilhados não entram nesta busca.").font(.caption).foregroundStyle(.secondary)
            if !inventory.issues.isEmpty { Text("O inventário de aplicativos está parcial; as associações também são incertas.").foregroundStyle(.orange) }
            if let report {
                Text("\(report.items.count) candidatos")
                ForEach(report.issues, id: \.self) { Text($0).font(.caption).foregroundStyle(.orange) }
                List(report.items) { item in
                    HStack {
                        VStack(alignment: .leading, spacing: 5) { Text(item.title); Text(item.url.path).font(.caption).textSelection(.enabled); Text(item.detail).font(.caption).foregroundStyle(.secondary) }
                        Spacer()
                        Text(item.state.rawValue).font(.caption)
                        if item.state == .present { Button("Revisar") { reviewing = item } }
                    }.padding(.vertical, 5)
                }
            } else if let error { Text(error).foregroundStyle(.orange) }
            else { ProgressView("Localizando candidatos…").frame(maxWidth: .infinity, maxHeight: .infinity) }
        }.padding(24).frame(minWidth: 800, minHeight: 560)
        .sheet(item: $reviewing) { item in
            if item.isDirectory { FileReviewView(root: item.url, allowsRemoval: true, history: history) }
            else { FilePreviewView(url: item.url) }
        }
        .task {
            let ids = Set(inventory.apps.compactMap(\.bundleID))
            let worker = Task.detached(priority: .utility) { try LeftoverAnalyzer.inspect(installedIDs: ids) }
            do {
                let value = try await withTaskCancellationHandler { try await worker.value } onCancel: { worker.cancel() }
                try Task.checkCancellation(); report = value
            } catch is CancellationError {} catch { self.error = error.localizedDescription }
        }
    }
}
