import Foundation
import Observation

struct AnalysisRecord: Codable, Identifiable {
    let id: UUID
    let date: Date
    let scope: String
    let outcome: String
    let itemCount: Int?
    let bytes: Int64?
    let cleanupReport: RemovalReport?
}

@MainActor @Observable
final class AnalysisHistory {
    private(set) var records: [AnalysisRecord] = []
    private(set) var error: String?
    private let file: URL
    private var canWrite = true

    init(file: URL = URL.applicationSupportDirectory.appendingPathComponent("Limpador/history.json")) {
        self.file = file
        do {
            records = try JSONDecoder().decode([AnalysisRecord].self, from: Data(contentsOf: file))
        } catch let issue as CocoaError where issue.code == .fileReadNoSuchFile { }
        catch {
            canWrite = false
            self.error = "Histórico preservado, mas não pôde ser lido: \(error.localizedDescription)"
        }
    }

    func record(scope: String, outcome: String, itemCount: Int? = nil, bytes: Int64? = nil, report: RemovalReport? = nil) {
        records.insert(AnalysisRecord(id: UUID(), date: Date(), scope: scope, outcome: outcome, itemCount: itemCount, bytes: bytes, cleanupReport: report), at: 0)
        guard canWrite else { return }
        do {
            try FileManager.default.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
            try JSONEncoder().encode(records).write(to: file, options: .atomic)
            error = nil
        } catch { self.error = "Não foi possível salvar o histórico: \(error.localizedDescription)" }
    }
}
