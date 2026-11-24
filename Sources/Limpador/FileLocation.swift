import Foundation
import Darwin

enum FileLocation {
    static func canonical(_ path: String) -> String? {
        guard let pointer = realpath(path, nil) else { return nil }
        defer { free(pointer) }
        return String(cString: pointer)
    }
    static func contains(_ path: String, inside root: String) -> Bool {
        guard let path = canonical(path), let root = canonical(root) else { return false }
        return path.hasPrefix(root == "/" ? "/" : root + "/")
    }
}
