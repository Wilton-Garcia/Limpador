import Foundation

struct AnalyzedFile: Identifiable, Sendable, Codable {
    let path: String
    let bytes: Int64
    let modifiedAt: Date?
    let relativePath: String
    let identity: FileIdentity?
    init(path: String, bytes: Int64, modifiedAt: Date?, relativePath: String? = nil, identity: FileIdentity? = nil) {
        self.identity = identity
        self.path = path; self.bytes = bytes; self.modifiedAt = modifiedAt
        self.relativePath = relativePath ?? URL(fileURLWithPath: path).lastPathComponent
    }
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

struct FileReadIssue: Sendable {
    let path: String
    let reason: String
}

struct FileAnalysis: Sendable {
    let root: URL
    let files: [AnalyzedFile]
    let issues: [FileReadIssue]
    var unreadableEntries: Int { issues.count }
    let observedAt: Date
    var excludedEntries = 0
    var bytes: Int64 { files.reduce(0) { $0 + $1.bytes } }
    func distribution(byCategory: Bool) -> [(name: String, bytes: Int64)] {
        let groups = Dictionary(grouping: files) { file in
            byCategory ? file.category : (file.relativePath.contains("/") ? String(file.relativePath.split(separator: "/")[0]) : "Nesta pasta")
        }
        return groups.map { (name: $0.key, bytes: $0.value.reduce(0) { $0 + $1.bytes }) }
            .sorted { $0.bytes == $1.bytes ? $0.name < $1.name : $0.bytes > $1.bytes }
    }
}

enum FileAnalyzer {
    static func scan(_ root: URL, excluding exclusions: AnalysisExclusions = .load()) throws -> FileAnalysis {
        var excluded = 0
        if exclusions.contains(root.path) { return FileAnalysis(root: root, files: [], issues: [], observedAt: Date(), excludedEntries: 1) }
        let keys: Set<URLResourceKey> = [.isSymbolicLinkKey, .isRegularFileKey, .isDirectoryKey]
        let rootFacts = try root.resourceValues(forKeys: keys)
        guard rootFacts.isDirectory == true, rootFacts.isSymbolicLink != true else {
            throw CocoaError(.fileReadUnsupportedScheme)
        }
        var issues: [FileReadIssue] = []
        var files: [AnalyzedFile] = []
        guard let entries = FileManager.default.enumerator(at: root, includingPropertiesForKeys: Array(keys), options: [], errorHandler: { url, error in
            issues.append(FileReadIssue(path: url.path, reason: error.localizedDescription)); return true
        }) else { throw CocoaError(.fileReadNoPermission) }
        for case let url as URL in entries {
            try Task.checkCancellation()
            if exclusions.contains(url.path) {
                excluded += 1
                if (try? url.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey])).map({ $0.isDirectory == true && $0.isSymbolicLink != true }) == true { entries.skipDescendants() }
                continue
            }
            do {
                let facts = try url.resourceValues(forKeys: keys)
                guard facts.isSymbolicLink != true, facts.isRegularFile == true else { continue }
                let identity = try FileIdentity.read(url.path)
                files.append(AnalyzedFile(path: url.path, bytes: identity.bytes, modifiedAt: identity.modifiedAt, relativePath: url.pathComponents.suffix(entries.level).joined(separator: "/"), identity: identity))
            } catch { issues.append(FileReadIssue(path: url.path, reason: error.localizedDescription)) }
        }
        try Task.checkCancellation()
        return FileAnalysis(root: root, files: files.sorted { $0.path.localizedStandardCompare($1.path) == .orderedAscending }, issues: issues, observedAt: Date(), excludedEntries: excluded)
    }
}
