import Foundation
import Testing
@testable import Limpador

@MainActor struct HistoryTests {
    @Test func persistsRecordsAndPreservesMalformedHistory() throws {
        let root = URL(fileURLWithPath: "/private/tmp").appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let file = root.appendingPathComponent("history.json")
        let history = AnalysisHistory(file: file)
        history.record(scope: "Aplicativos", outcome: "Concluída", itemCount: 3, bytes: 123)
        let restored = AnalysisHistory(file: file)
        #expect(restored.records.first?.bytes == 123)
        #expect(restored.error == nil)
        let malformed = Data("invalid history".utf8)
        try malformed.write(to: file)
        let damaged = AnalysisHistory(file: file)
        damaged.record(scope: "Aplicativos", outcome: "Cancelada")
        #expect(damaged.error != nil)
        #expect(try Data(contentsOf: file) == malformed)
    }
}
