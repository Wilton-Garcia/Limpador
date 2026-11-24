import SwiftUI

struct DuplicateReviewView: View {
    let files: [AnalyzedFile]
    @Environment(\.dismiss) private var dismiss
    @State private var report: DuplicateReport?
    @State private var error: String?
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack { Text("Duplicados por conteúdo").font(.title2.bold()); Spacer(); Button("Concluir") { dismiss() } }
            Text("Compara tamanho e SHA-256. Links simbólicos não são seguidos; nomes do mesmo arquivo físico não contam como cópias. Nenhum item é removido.").font(.caption).foregroundStyle(.secondary)
            if let report {
                Text("\(report.groups.count) grupos · \(report.skipped) arquivos não verificados")
                if report.groups.isEmpty { ContentUnavailableView("Nenhum duplicado confirmado", systemImage: "doc.on.doc", description: Text("Resultado limitado aos arquivos lidos nesta análise.")) }
                List(Array(report.groups.enumerated()), id: \.offset) { index, group in
                    Section("Grupo \(index + 1) · \(group.count) arquivos") {
                        ForEach(group) { file in
                            HStack {
                                Text(file.path).textSelection(.enabled)
                                Spacer()
                                Button("Finder") { NSWorkspace.shared.activateFileViewerSelecting([file.url]) }
                            }
                        }
                    }
                }
            } else if let error { Text(error).foregroundStyle(.orange) }
            else { ProgressView("Comparando conteúdo… Feche esta janela para cancelar.").frame(maxWidth: .infinity, maxHeight: .infinity) }
        }.padding(24).frame(minWidth: 760, minHeight: 500)
        .task {
            let task = Task.detached(priority: .utility) { try DuplicateAnalyzer.find(in: files) }
            do {
                let value = try await withTaskCancellationHandler { try await task.value } onCancel: { task.cancel() }
                try Task.checkCancellation(); report = value
            } catch is CancellationError {} catch { self.error = error.localizedDescription }
        }
    }
}
