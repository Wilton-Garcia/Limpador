import SwiftUI
import UniformTypeIdentifiers

struct FolderUsageView: View {
    @State private var choosing = false
    @State private var volumes: [URL] = []
    var onCompleted: (FileAnalysis) -> Void = { _ in }
    @State private var root: URL?
    @State private var request = UUID()
    @State private var result: FileAnalysis?
    @State private var error: String?
    @State private var worker: Task<FileAnalysis, Error>?
    @State private var reviewing = false
    @State private var grouping = "Categoria"

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Distribuição de arquivos").font(.headline)
                Spacer()
                if worker != nil { Button("Cancelar") { worker?.cancel() } }
                Button("Revisar Downloads") { select(URL.downloadsDirectory) }.disabled(worker != nil)
                Button("Escolher pasta") { choosing = true }.disabled(worker != nil)
                Menu("Volumes") {
                    ForEach(volumes, id: \.path) { volume in
                        Button((try? volume.resourceValues(forKeys: [.volumeNameKey]).volumeName) ?? volume.path) { select(volume) }
                    }
                }.disabled(worker != nil || volumes.isEmpty)
            }
            if let root { Text(root.path).font(.caption).textSelection(.enabled) }
            if worker != nil { ProgressView("Lendo a pasta…") }
            if let error { Label(error, systemImage: "exclamationmark.triangle").font(.caption).foregroundStyle(.orange) }
            if let result {
                Text("\(result.files.count) arquivos · " + ByteCountFormatter.string(fromByteCount: result.bytes, countStyle: .file))
                if result.unreadableEntries > 0 { Text("Leitura parcial: \(result.unreadableEntries) entradas inacessíveis").foregroundStyle(.orange) }
                Picker("Agrupar por", selection: $grouping) { Text("Categoria").tag("Categoria"); Text("Subpasta").tag("Subpasta") }.pickerStyle(.segmented)
                ForEach(result.distribution(byCategory: grouping == "Categoria"), id: \.name) { group in
                    VStack(spacing: 5) {
                        HStack { Text(group.name); Spacer(); Text(ByteCountFormatter.string(fromByteCount: group.bytes, countStyle: .file)) }
                        ProgressView(value: Double(group.bytes), total: Double(max(result.bytes, 1)))
                    }.font(.caption)
                }
                Button("Revisar arquivos") { reviewing = true }
            } else if worker == nil {
                Text("Escolha uma pasta para ver quais arquivos ocupam espaço. A análise não segue links simbólicos nem altera arquivos.").font(.caption).foregroundStyle(.secondary)
            }
        }
        .padding(24).background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 16))
        .onAppear { volumes = FileManager.default.mountedVolumeURLs(includingResourceValuesForKeys: [.volumeNameKey], options: [.skipHiddenVolumes]) ?? [] }
        .fileImporter(isPresented: $choosing, allowedContentTypes: [.folder]) { selection in
            switch selection {
            case .success(let url): select(url)
            case .failure(let error): self.error = error.localizedDescription
            }
        }
        .sheet(isPresented: $reviewing) { if let result { FileReviewView(root: result.root, initialResult: result) } }
        .task(id: request) {
            guard let root else { return }
            error = nil; result = nil
            let scoped = root.startAccessingSecurityScopedResource()
            defer { if scoped { root.stopAccessingSecurityScopedResource() } }
            let task = Task.detached(priority: .utility) { try FileAnalyzer.scan(root) }
            worker = task
            defer { worker = nil }
            do {
                let analysis = try await withTaskCancellationHandler { try await task.value } onCancel: { task.cancel() }
                try Task.checkCancellation()
                result = analysis
                onCompleted(analysis)
            } catch is CancellationError { error = "Análise cancelada." }
            catch { self.error = error.localizedDescription }
        }
    }

    private func select(_ url: URL) { root = url; request = UUID() }
}
