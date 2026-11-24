import SwiftUI
import QuickLookUI

struct FileReviewView: View {
    let root: URL
    var initialResult: FileAnalysis? = nil
    @Environment(\.dismiss) private var dismiss
    @State private var result: FileAnalysis?
    @State private var error: String?
    @State private var query = FileQuery()
    @State private var ageMonths = 0
    @State private var findingDuplicates = false
    @State private var previewURL: URL?
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
                Picker("Tamanho mínimo", selection: $query.minimumBytes) {
                    Text("Qualquer tamanho").tag(Int64(0))
                    Text("100 MB").tag(Int64(100_000_000))
                    Text("1 GB").tag(Int64(1_000_000_000))
                    Text("10 GB").tag(Int64(10_000_000_000))
                }.frame(maxWidth: 300)
                Picker("Última modificação", selection: $ageMonths) {
                    Text("Qualquer data").tag(0)
                    Text("Há mais de 6 meses").tag(6)
                    Text("Há mais de 1 ano").tag(12)
                    Text("Há mais de 2 anos").tag(24)
                }.frame(maxWidth: 330)
                .onChange(of: ageMonths) { _, months in
                    query.modifiedBefore = months == 0 ? nil : Calendar.current.date(byAdding: .month, value: -months, to: result.observedAt)
                }
                Text("\(filtered.count) arquivos visíveis").font(.caption).foregroundStyle(.secondary)
                Text("\(result.files.count) arquivos · \(selected.count) selecionados · " + ByteCountFormatter.string(fromByteCount: selectedBytes(result), countStyle: .file))
                if result.unreadableEntries > 0 {
                    Label("Leitura parcial: \(result.unreadableEntries) entradas inacessíveis", systemImage: "exclamationmark.triangle").foregroundStyle(.orange)
                }
                HStack {
                    Button("Selecionar visíveis") { selected.formUnion(filtered.map(\.id)) }
                    Button("Encontrar duplicados") { findingDuplicates = true }
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
                        Button { previewURL = file.url } label: { Image(systemName: "eye") }
                            .help("Visualização rápida").accessibilityLabel("Visualizar \(file.url.lastPathComponent)")
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
        .sheet(isPresented: Binding(get: { previewURL != nil }, set: { if !$0 { previewURL = nil } })) { if let previewURL { FilePreviewView(url: previewURL) } }
        .sheet(isPresented: $findingDuplicates) { if let result { DuplicateReviewView(files: result.files) } }
        .task(id: root) {
            if let initialResult { result = initialResult; return }
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
