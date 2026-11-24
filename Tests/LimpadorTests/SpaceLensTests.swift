import Foundation
import Testing
@testable import Limpador

struct SpaceLensTests {
    @Test func accountsForFilesHiddenItemsEmptyFoldersAndPackagesWithoutFollowingLinks() throws {
        let root = URL(fileURLWithPath: "/private/tmp").appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        for directory in ["Documentos", "Videos", "Vazia", "Demo.app/Contents"] {
            try FileManager.default.createDirectory(at: root.appendingPathComponent(directory), withIntermediateDirectories: true)
        }
        for (path, count) in [("Documentos/large.txt", 60), ("Videos/video.bin", 30), (".hidden", 10), ("Demo.app/Contents/file", 5)] {
            try Data(repeating: 1, count: count).write(to: root.appendingPathComponent(path))
        }
        try FileManager.default.createSymbolicLink(at: root.appendingPathComponent("linked"), withDestinationURL: root.appendingPathComponent("Documentos"))
        let analysis = try FileAnalyzer.scan(root, excluding: .init(paths: []))
        let snapshot = try SpaceLensSnapshot.build(analysis)
        #expect(snapshot.nodes[""]?.bytes == 105)
        #expect(snapshot.nodes[""]?.fileCount == 4)
        #expect(snapshot.nodes["Vazia"]?.bytes == 0)
        #expect(snapshot.nodes["Vazia"]?.kind == .directory)
        #expect(snapshot.nodes["Demo.app"]?.isPackage == true)
        #expect(snapshot.nodes[".hidden"]?.isHidden == true)
        #expect(snapshot.nodes["linked"] == nil)
        #expect(analysis.skippedLinks == 1)
        #expect(snapshot.children(of: "", showHidden: false).contains { $0.id == ".hidden" } == false)
        #expect(snapshot.breadcrumbs(to: "Demo.app/Contents").map(\.id) == ["", "Demo.app", "Demo.app/Contents"])
        let review = try snapshot.review(nodeIDs: ["Documentos", "Documentos/large.txt"])
        #expect(review.files.count == 1)
        #expect(review.bytes == 60)
        #expect(review.rootIdentity == analysis.rootIdentity)
    }

    @Test func unreadableItemsRemainUnknownAndDoNotBecomeFreeSpace() throws {
        let root = URL(fileURLWithPath: "/private/tmp")
        let analysis = FileAnalysis(root: root, files: [AnalyzedFile(path: "/private/tmp/readable", bytes: 30, modifiedAt: nil, relativePath: "readable")], issues: [.init(path: "/private/tmp/blocked", reason: "Permission denied")], observedAt: Date())
        let snapshot = try SpaceLensSnapshot.build(analysis)
        #expect(snapshot.nodes["blocked"]?.kind == .unreadable)
        #expect(snapshot.nodes["blocked"]?.unreadableCount == 1)
        #expect(snapshot.nodes[""]?.unreadableCount == 1)
        #expect(snapshot.nodes[""]?.bytes == 30)
        #expect(snapshot.children(of: "", showHidden: true).count == 2)
    }

    @Test func treemapConservesAreaProportionsAndSmallItemCoverage() {
        let nodes = (1...100).map { number in
            SpaceLensNode(id: String(number), url: URL(fileURLWithPath: "/file-\(number)"), parentID: "", kind: .file, bytes: Int64(number), fileCount: 1)
        }
        let tiles = SpaceMapTile.make(nodes, limit: 8)
        #expect(tiles.count == 8)
        #expect(Set(tiles.flatMap(\.nodeIDs)) == Set(nodes.map(\.id)))
        #expect(tiles.reduce(0) { $0 + $1.bytes } == 5050)
        let bounds = CGRect(x: 0, y: 0, width: 800, height: 400)
        let placements = SpaceTreemapLayout.layout(tiles, in: bounds)
        let area = placements.reduce(0.0) { $0 + $1.rect.width * $1.rect.height }
        #expect(abs(area - bounds.width * bounds.height) < 0.001)
        for (index, placement) in placements.enumerated() {
            let fraction = placement.rect.width * placement.rect.height / (bounds.width * bounds.height)
            #expect(abs(fraction - Double(placement.tile.bytes) / 5050) < 0.000001)
            #expect(placement.rect.minX >= -0.001 && placement.rect.maxX <= bounds.maxX + 0.001)
            #expect(placement.rect.minY >= -0.001 && placement.rect.maxY <= bounds.maxY + 0.001)
            for other in placements.dropFirst(index + 1) {
                let overlap = placement.rect.intersection(other.rect)
                #expect(overlap.isNull || overlap.width < 0.000001 || overlap.height < 0.000001)
            }
        }
        #expect(SpaceTreemapLayout.layout(tiles, in: .zero).isEmpty)
        #expect(SpaceMapTile.make([]).isEmpty)
    }

    @Test func fileScanCanCancelFromObservedProgress() async throws {
        let root = URL(fileURLWithPath: "/private/tmp").appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        for index in 0..<260 { try Data([1]).write(to: root.appendingPathComponent(String(index))) }
        do {
            _ = try await Task {
                try FileAnalyzer.scan(root, excluding: .init(paths: [])) { progress in
                    if progress.entriesExamined >= 256 { withUnsafeCurrentTask { $0?.cancel() } }
                }
            }.value
            Issue.record("Expected cancellation before finishing the scan")
        } catch is CancellationError {}
    }
}
