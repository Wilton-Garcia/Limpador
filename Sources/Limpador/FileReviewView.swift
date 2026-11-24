import SwiftUI

struct FileReviewView: View {
    let root: URL
    @Environment(\.dismiss) private var dismiss
    @State private var result: FileAnalysis?
    @State private var error: String?
    @State private var query = FileQuery()
    @State private var selected: Set<String> = []

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 5) {
                    Text("Revisar arquivos").font(.title2.bold())
                    Text(root.path).font(.caption).textSelection(.enabled)
                }
                Spacer()
                Button("Concluir") { dismiss() }.keyboardShortcut(.cancelAction)
            }
            if let result {
                let filtered = query.apply(to: result.files)
                HStack {
                    TextField("Buscar arquivos", text: $query.search).textFieldStyle(.roundedBorder)
                    Picker("Tipo", selection: $query.category) {
                        ForEach(["Todas"] + Set(result.files.map(\.category)).sorted(), id: \.self) { Text($0).tag($0) }
                    }.frame(width: 200)
                    Picker("Ordenar", selection: $query.order) {
                        ForEach(FileQuery.Order.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                    }.frame(width: 220)
                }
                Text("\(filtered.count) arquivos visíveis").font(.caption).foregroundStyle(.secondary)
                Text("\(result.files.count) arquivos · \(selected.count) selecionados · " + ByteCountFormatter.string(fromByteCount: selectedBytes(result), countStyle: .file))
                if result.unreadableEntries > 0 {
                    Label("Leitura parcial: \(result.unreadableEntries) entradas inacessíveis", systemImage: "exclamationmark.triangle").foregroundStyle(.orange)
                }
                HStack {
                    Button("Selecionar visíveis") { selected.formUnion(filtered.map(\.id)) }
                    Button("Desmarcar") { selected.removeAll() }.disabled(selected.isEmpty)
                }
                List(filtered) { file in
                    HStack {
                        Toggle(isOn: Binding(get: { selected.contains(file.id) }, set: { value in
                            if value { selected.insert(file.id) } else { selected.remove(file.id) }
                        })) {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(file.url.lastPathComponent).lineLimit(1)
                                Text(file.path).font(.caption2).foregroundStyle(.secondary).lineLimit(1).truncationMode(.middle).help(file.path)
                            }
                        }.toggleStyle(.checkbox)
                        Spacer()
                        Text(ByteCountFormatter.string(fromByteCount: file.bytes, countStyle: .file)).monospacedDigit()
                        Button { NSWorkspace.shared.activateFileViewerSelecting([file.url]) } label: { Image(systemName: "folder") }
                            .help("Mostrar no Finder").accessibilityLabel("Mostrar \(file.url.lastPathComponent) no Finder")
                    }.padding(.vertical, 5)
                }
                Text("Seleção apenas para revisão. Nenhum arquivo será removido. Os tamanhos são lógicos.").font(.caption).foregroundStyle(.secondary)
            } else if let error {
                ContentUnavailableView("Não foi possível ler esta pasta", systemImage: "exclamationmark.triangle", description: Text(error))
            } else {
                ProgressView("Lendo arquivos…").frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }.padding(24).frame(minWidth: 760, minHeight: 540)
        .task(id: root) {
            let worker = Task.detached(priority: .utility) { try FileAnalyzer.scan(root) }
            do {
                let analysis = try await withTaskCancellationHandler { try await worker.value } onCancel: { worker.cancel() }
                try Task.checkCancellation()
                result = analysis
            } catch is CancellationError {} catch { self.error = error.localizedDescription }
        }
    }

    private func selectedBytes(_ result: FileAnalysis) -> Int64 {
        result.files.reduce(0) { $0 + (selected.contains($1.id) ? $1.bytes : 0) }
    }
}
