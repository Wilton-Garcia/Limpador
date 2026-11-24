import Foundation
import Observation

struct CleanupSource: Identifiable, Sendable {
    let id: String
    let title: String
    let explanation: String
    let root: URL
    static var caches: Self {
        Self(id: "caches", title: "Caches do usuário", explanation: "Arquivos de apoio em Library/Caches. Aplicativos podem precisar recriá-los; revise antes de limpar.", root: FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Caches"))
    }
    static var sources: [Self] {
        [caches,
         Self(id: "user-logs", title: "Registros e relatórios do usuário", explanation: "Inclui relatórios de diagnóstico em Library/Logs. Use o filtro de última modificação na revisão para encontrar registros antigos.", root: FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Logs")),
         Self(id: "system-logs", title: "Relatórios compartilhados", explanation: "Registros em /Library/Logs. Itens protegidos serão informados como inacessíveis; o app não solicita privilégios de administrador.", root: URL(fileURLWithPath: "/Library/Logs"))]
    }
}

@MainActor @Observable
final class CleanupModel {
    private(set) var loading = false
    private(set) var source: CleanupSource?
    private(set) var result: FileAnalysis?
    private(set) var error: String?
    private var worker: Task<FileAnalysis, Error>?

    func scan(_ source: CleanupSource, history: AnalysisHistory) async {
        guard !loading else { return }
        loading = true; self.source = source; result = nil; error = nil
        defer { worker = nil; loading = false }
        let task = Task.detached(priority: .utility) { try FileAnalyzer.scan(source.root) }
        worker = task
        do {
            let analysis = try await withTaskCancellationHandler { try await task.value } onCancel: { task.cancel() }
            try Task.checkCancellation()
            result = analysis
            history.record(scope: source.title, outcome: analysis.unreadableEntries == 0 ? "Concluída" : "Parcial", itemCount: analysis.files.count, bytes: analysis.bytes)
        } catch is CancellationError {
            error = "Análise cancelada. Nenhum arquivo foi removido."
            history.record(scope: source.title, outcome: "Cancelada")
        } catch {
            self.error = error.localizedDescription
            history.record(scope: source.title, outcome: "Falha: " + error.localizedDescription)
        }
    }

    func cancel() { worker?.cancel() }
}
