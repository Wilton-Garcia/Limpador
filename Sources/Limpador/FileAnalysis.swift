import Foundation

struct AnalyzedFile: Identifiable, Sendable, Codable {
    let path: String
    let bytes: Int64
    let modifiedAt: Date?
    var id: String { path }
    var url: URL { URL(fileURLWithPath: path) }
    var category: String {
        switch url.pathExtension.lowercased() {
        case "jpg", "jpeg", "png", "gif", "heic", "webp", "svg": "Imagens"
        case "mp4", "mov", "mkv", "avi": "Vídeos"
        case "mp3", "m4a", "wav", "flac": "Áudio"
        case "pdf", "txt", "docx", "xlsx", "pages", "numbers", "csv": "Documentos"
        case "zip", "dmg", "pkg", "gz", "tar", "7z": "Arquivos e instaladores"
        default: "Outros"
        }
    }
}

struct FileAnalysis: Sendable {
    let root: URL
    let files: [AnalyzedFile]
    let unreadableEntries: Int
    let observedAt: Date
    var bytes: Int64 { files.reduce(0) { $0 + $1.bytes } }
}

enum FileAnalyzer {
    static func scan(_ root: URL) throws -> FileAnalysis {
        let keys: Set<URLResourceKey> = [.isSymbolicLinkKey, .isRegularFileKey, .isDirectoryKey, .fileSizeKey, .contentModificationDateKey]
        let rootFacts = try root.resourceValues(forKeys: keys)
        guard rootFacts.isDirectory == true, rootFacts.isSymbolicLink != true else {
            throw CocoaError(.fileReadUnsupportedScheme)
        }
        var failures = 0
        var files: [AnalyzedFile] = []
        guard let entries = FileManager.default.enumerator(at: root, includingPropertiesForKeys: Array(keys), options: [], errorHandler: { _, _ in
            failures += 1; return true
        }) else { throw CocoaError(.fileReadNoPermission) }
        for case let url as URL in entries {
            try Task.checkCancellation()
            do {
                let facts = try url.resourceValues(forKeys: keys)
                guard facts.isSymbolicLink != true, facts.isRegularFile == true else { continue }
                guard let bytes = facts.fileSize else { failures += 1; continue }
                files.append(AnalyzedFile(path: url.path, bytes: Int64(bytes), modifiedAt: facts.contentModificationDate))
            } catch { failures += 1 }
        }
        try Task.checkCancellation()
        return FileAnalysis(root: root, files: files.sorted { $0.path.localizedStandardCompare($1.path) == .orderedAscending }, unreadableEntries: failures, observedAt: Date())
    }
}
