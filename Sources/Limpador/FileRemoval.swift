import Foundation
import Darwin

struct RemovalEntry: Codable, Identifiable, Sendable {
    enum Outcome: String, Codable, Sendable { case trashed, skipped, failed }
    let path: String
    let outcome: Outcome
    let detail: String
    let destination: String?
    var id: String { path }
}
struct RemovalReport: Codable, Sendable {
    let date: Date
    let entries: [RemovalEntry]
    var movedCount: Int { entries.filter { $0.outcome == .trashed }.count }
}

struct RemovalPolicy: Sendable {
    let root: URL
    var home = FileManager.default.homeDirectoryForCurrentUser
    func refusal(for file: AnalyzedFile, running: RunningAppGuard) -> String? {
        guard let expected = file.identity else { return "Identidade não registrada. Analise novamente." }
        guard let current = try? FileIdentity.read(file.path), current == expected else { return "Arquivo alterado ou indisponível. Analise novamente." }
        guard current.owner == getuid() else { return "O arquivo pertence a outra conta." }
        guard let realRoot = FileLocation.canonical(root.path), let realFile = FileLocation.canonical(file.path), realFile.hasPrefix(realRoot + "/") else { return "Arquivo fora da origem autorizada." }
        let forbidden = ["/System", "/Library", "/usr", "/bin", "/sbin", "/private/etc", "/private/var/db", "/Applications"]
        if let homePath = FileLocation.canonical(home.path) {
            let protectedUserRoots = ["Library/Group Containers", "Library/Keychains", "Library/Application Support/Limpador"]
            if protectedUserRoots.contains(where: { realFile == homePath + "/" + $0 || realFile.hasPrefix(homePath + "/" + $0 + "/") }) {
                return "Dados compartilhados, credenciais ou registros de recuperação protegidos."
            }
        }
        if forbidden.contains(where: { realFile == $0 || realFile.hasPrefix($0 + "/") }) { return "Local essencial ou aplicativo protegido." }
        if URL(fileURLWithPath: realFile).pathComponents.contains(where: { $0.hasSuffix(".app") || $0 == ".Trash" || $0 == ".Trashes" }) { return "Pacote de aplicativo ou item já na Lixeira." }
        if AnalysisExclusions.load().contains(file.path) { return "Arquivo excluído pelas preferências." }
        let associations = running.associations(for: file.path)
        if !associations.isEmpty { return "Associado a app em execução: " + associations.joined(separator: ", ") }
        return nil
    }

}

enum FileRemoval {
    static func trash(_ url: URL) throws -> URL? {
        var destination: NSURL?
        try FileManager.default.trashItem(at: url, resultingItemURL: &destination)
        return destination as URL?
    }

    static func run(_ files: [AnalyzedFile], policy: RemovalPolicy,
                    running: @Sendable () async -> RunningAppGuard = { await RunningAppGuard.snapshot() },
                    transport: @Sendable (URL) throws -> URL? = { try trash($0) }) async -> RemovalReport {
        var entries: [RemovalEntry] = []
        for file in files {
            if Task.isCancelled {
                entries.append(RemovalEntry(path: file.path, outcome: .skipped, detail: "Operação cancelada antes deste item.", destination: nil))
                continue
            }
            let liveApps = await running()
            if let reason = policy.refusal(for: file, running: liveApps) {
                entries.append(RemovalEntry(path: file.path, outcome: .skipped, detail: reason, destination: nil))
                continue
            }
            // Recheck cancellation after the live application snapshot.
            if Task.isCancelled {
                entries.append(RemovalEntry(path: file.path, outcome: .skipped, detail: "Operação cancelada antes deste item.", destination: nil)); continue
            }
            do {
                let destination = try transport(file.url)
                entries.append(RemovalEntry(path: file.path, outcome: .trashed, detail: "Enviado à Lixeira.", destination: destination?.path))
            } catch {
                entries.append(RemovalEntry(path: file.path, outcome: .failed, detail: error.localizedDescription, destination: nil))
            }
        }
        return RemovalReport(date: Date(), entries: entries)
    }
}
