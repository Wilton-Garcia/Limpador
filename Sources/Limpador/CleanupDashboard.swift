import SwiftUI

struct CleanupDashboard: View {
    let model: CleanupModel
    let history: AnalysisHistory
    @State private var reviewing = false
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Cada arquivo, uma escolha.").font(.title.bold())
            Text("Analise uma origem, revise os arquivos e confirme antes de enviar uma seleção à Lixeira.").foregroundStyle(.secondary)
            ForEach(CleanupSource.sources) { source in
                HStack(alignment: .top, spacing: 16) {
                    Image(systemName: "sparkles").font(.title2).foregroundStyle(.teal)
                    VStack(alignment: .leading, spacing: 8) {
                        Text(source.title).font(.headline)
                        Text(source.explanation).font(.caption).foregroundStyle(.secondary)
                        DisclosureGroup("Origem e finalidade") {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Origem: " + source.root.path).textSelection(.enabled)
                                Text(source.explanation)
                                Text("A categoria é definida pela pasta de origem. Ela não comprova que o arquivo esteja sem uso ou possa ser removido. Revise os itens individualmente.")
                            }.font(.caption).foregroundStyle(.secondary).padding(.top, 6)
                        }
                    }
                    Spacer()
                    Button("Analisar") { Task { await model.scan(source, history: history) } }.disabled(model.loading)
                }.padding(20).background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 16))
            }
            if model.loading {
                HStack { ProgressView("Lendo " + (model.source?.title ?? "arquivos") + "…"); Spacer(); Button("Cancelar") { model.cancel() } }
            }
            if let error = model.error { Label(error, systemImage: "exclamationmark.triangle").foregroundStyle(.orange) }
            if let result = model.result {
                VStack(alignment: .leading, spacing: 12) {
                    Text(model.source?.title ?? "Resultado").font(.headline)
                    Text("\(result.files.count) arquivos · " + ByteCountFormatter.string(fromByteCount: result.bytes, countStyle: .file))
                    Text("Tamanho lógico, não uma estimativa de espaço liberado. \(result.unreadableEntries) entradas inacessíveis; \(result.excludedEntries) entradas excluídas.").font(.caption).foregroundStyle(.secondary)
                    Button("Revisar arquivos") { reviewing = true }
                }.padding(20).frame(maxWidth: .infinity, alignment: .leading).background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 16))
            }
        }
        .sheet(isPresented: $reviewing) { if let result = model.result { FileReviewView(root: result.root, initialResult: result, allowsRemoval: true, history: history) } }
    }
}
