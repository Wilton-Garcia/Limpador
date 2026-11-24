import Foundation

enum AppIdentity {
    static var version: String { Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "desenvolvimento" }
    static var build: String? { Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String }
    static let projectURL = URL(string: "https://github.com/Wilton-Garcia/Limpador")!
}
