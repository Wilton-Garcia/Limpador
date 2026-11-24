import Foundation
import Observation

private final class ScopedFolderAccess: Sendable {
    let url: URL
    let granted: Bool
    init(_ url: URL) { self.url = url; granted = url.startAccessingSecurityScopedResource() }
    deinit { if granted { url.stopAccessingSecurityScopedResource() } }
}

private enum SpaceLensProgress: Sendable {
    case reading(FileScanProgress)
    case indexing
}

@MainActor @Observable
final class SpaceLensModel {
    private(set) var snapshot: SpaceLensSnapshot?
    private(set) var root: URL?
    private(set) var loading = false
    private(set) var progressLabel = ""
    private(set) var error: String?
    var currentID = ""
    var selectedID: String?
    var focusedIDs: Set<String>?
    var stale = false
    private var access: ScopedFolderAccess?
    private var worker: Task<SpaceLensSnapshot, Error>?

    func scan(_ url: URL, history: AnalysisHistory) async {
        guard !loading else { return }
        loading = true; error = nil; snapshot = nil; selectedID = nil; focusedIDs = nil; root = url; stale = false
        progressLabel = "Preparando leitura…"
        let scope = ScopedFolderAccess(url)
        access = scope
        defer { loading = false; worker = nil }
        do {
            let volume = try url.resourceValues(forKeys: [.volumeIsLocalKey])
            guard volume.volumeIsLocal == true else {
                throw NSError(domain: "Limpador", code: 10, userInfo: [NSLocalizedDescriptionKey: "A Lupa de Espaço analisa pastas em volumes locais. Não foi possível confirmar que este volume seja local."])
            }
            let (updates, continuation) = AsyncStream<SpaceLensProgress>.makeStream(bufferingPolicy: .bufferingNewest(1))
            let task = Task.detached(priority: .utility) {
                defer { continuation.finish() }
                return try withExtendedLifetime(scope) {
                    let analysis = try FileAnalyzer.scan(url) { continuation.yield(.reading($0)) }
                    try Task.checkCancellation()
                    continuation.yield(.indexing)
                    return try SpaceLensSnapshot.build(analysis)
                }
            }
            worker = task
            let value = try await withTaskCancellationHandler {
                for await update in updates {
                    switch update {
                    case .reading(let progress):
                        progressLabel = "\(progress.entriesExamined.formatted()) entradas examinadas · " + ByteCountFormatter.string(fromByteCount: progress.logicalBytes, countStyle: .file) + " catalogados"
                    case .indexing: progressLabel = "Organizando o mapa de pastas…"
                    }
                }
                return try await task.value
            } onCancel: { task.cancel() }
            try Task.checkCancellation()
            snapshot = value; currentID = ""
            history.record(scope: "Lupa de Espaço · " + url.path, outcome: value.analysis.unreadableEntries == 0 ? "Concluída" : "Parcial", itemCount: value.analysis.files.count, bytes: value.analysis.bytes)
        } catch is CancellationError {
            error = "Análise cancelada. Nenhum arquivo foi alterado."
        } catch { self.error = error.localizedDescription }
    }
    func cancel() { worker?.cancel() }
    func navigate(to id: String) {
        guard snapshot?.nodes[id]?.kind == .directory else { return }
        currentID = id; selectedID = nil; focusedIDs = nil
    }
    func up() {
        if focusedIDs != nil { focusedIDs = nil; selectedID = nil; return }
        if let parent = snapshot?.nodes[currentID]?.parentID { navigate(to: parent) }
    }
    func reset() {
        guard !loading else { return }
        snapshot = nil; root = nil; selectedID = nil; focusedIDs = nil; access = nil; error = nil; stale = false
    }
}
