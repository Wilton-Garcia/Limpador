import Foundation

struct SpaceLensNode: Identifiable, Sendable {
    enum Kind: Sendable { case directory, file, unreadable }
    let id: String
    var url: URL
    let parentID: String?
    var kind: Kind
    var isHidden: Bool?
    var isPackage: Bool?
    var fileIndex: Int?
    var bytes: Int64 = 0
    var fileCount = 0
    var unreadableCount = 0
    var children: [String] = []
    var name: String { url.lastPathComponent.isEmpty ? url.path : url.lastPathComponent }
}

struct SpaceLensSnapshot: Sendable {
    let analysis: FileAnalysis
    let nodes: [String: SpaceLensNode]

    static func build(_ analysis: FileAnalysis) throws -> Self {
        var nodes: [String: SpaceLensNode] = ["": SpaceLensNode(id: "", url: analysis.root, parentID: nil, kind: .directory)]
        func ensureDirectory(_ id: String) {
            guard !id.isEmpty else { return }
            var parent = ""
            for component in id.split(separator: "/") {
                let current = parent.isEmpty ? String(component) : parent + "/" + component
                if nodes[current] == nil {
                    nodes[current] = SpaceLensNode(id: current, url: analysis.root.appendingPathComponent(current), parentID: parent, kind: .directory)
                }
                parent = current
            }
        }
        func parentID(_ id: String) -> String { id.split(separator: "/").dropLast().joined(separator: "/") }
        for directory in analysis.directories {
            try Task.checkCancellation()
            ensureDirectory(directory.relativePath)
            nodes[directory.relativePath]?.url = URL(fileURLWithPath: directory.path)
            nodes[directory.relativePath]?.isHidden = directory.isHidden
            nodes[directory.relativePath]?.isPackage = directory.isPackage
        }
        for (index, file) in analysis.files.enumerated() {
            try Task.checkCancellation()
            let parent = parentID(file.relativePath)
            ensureDirectory(parent)
            nodes[file.relativePath] = SpaceLensNode(id: file.relativePath, url: file.url, parentID: parent, kind: .file, isHidden: file.isHidden, fileIndex: index, bytes: file.bytes, fileCount: 1)
        }
        let physicalRoot = FileLocation.canonical(analysis.root.path) ?? analysis.root.path
        let rootComponents = URL(fileURLWithPath: physicalRoot).pathComponents
        for issue in analysis.issues {
            try Task.checkCancellation()
            let components = URL(fileURLWithPath: issue.path).pathComponents
            guard components.starts(with: rootComponents) else { nodes[""]?.unreadableCount += 1; continue }
            let id = components.dropFirst(rootComponents.count).joined(separator: "/")
            if nodes[id] == nil {
                let parent = parentID(id)
                ensureDirectory(parent)
                nodes[id] = SpaceLensNode(id: id, url: URL(fileURLWithPath: issue.path), parentID: parent, kind: .unreadable)
            }
            nodes[id]?.unreadableCount += 1
        }
        for id in Array(nodes.keys) where !id.isEmpty {
            if let parent = nodes[id]?.parentID { nodes[parent]?.children.append(id) }
        }
        let descending = nodes.keys.filter { !$0.isEmpty }.sorted {
            let left = $0.split(separator: "/").count, right = $1.split(separator: "/").count
            return left == right ? $0 < $1 : left > right
        }
        for id in descending {
            try Task.checkCancellation()
            guard let node = nodes[id], let parent = node.parentID else { continue }
            nodes[parent]?.bytes += node.bytes
            nodes[parent]?.fileCount += node.fileCount
            nodes[parent]?.unreadableCount += node.unreadableCount
        }
        for id in Array(nodes.keys) {
            let children = nodes[id]?.children ?? []
            let ordered = children.sorted {
                let left = nodes[$0]!, right = nodes[$1]!
                if left.bytes != right.bytes { return left.bytes > right.bytes }
                let order = left.name.localizedStandardCompare(right.name)
                return order == .orderedSame ? left.id < right.id : order == .orderedAscending
            }
            nodes[id]?.children = ordered
        }
        return Self(analysis: analysis, nodes: nodes)
    }

    func children(of id: String, showHidden: Bool) -> [SpaceLensNode] {
        (nodes[id]?.children ?? []).compactMap { nodes[$0] }.filter { showHidden || $0.isHidden != true }
    }
    func breadcrumbs(to id: String) -> [SpaceLensNode] {
        var result: [SpaceLensNode] = [], current: String? = id
        while let key = current, let node = nodes[key] { result.append(node); current = node.parentID }
        return result.reversed()
    }
    func review(nodeIDs: [String]) throws -> FileAnalysis {
        var stack = nodeIDs, visited = Set<String>(), indices = Set<Int>()
        while let id = stack.popLast() {
            try Task.checkCancellation()
            guard visited.insert(id).inserted, let node = nodes[id] else { continue }
            if let index = node.fileIndex { indices.insert(index) }
            stack.append(contentsOf: node.children)
        }
        return FileAnalysis(root: analysis.root, files: indices.sorted().map { analysis.files[$0] }, issues: analysis.issues,
                            observedAt: analysis.observedAt, excludedEntries: analysis.excludedEntries,
                            rootIdentity: analysis.rootIdentity, directories: analysis.directories, skippedLinks: analysis.skippedLinks)
    }
}
