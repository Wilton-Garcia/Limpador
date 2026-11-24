import Foundation

struct AssociatedData: Identifiable, Sendable {
    enum State: String, Sendable { case present = "Encontrado", absent = "Não encontrado", inaccessible = "Não verificado", link = "Link não seguido" }
    let title: String
    let url: URL
    let state: State
    let bytes: Int64?
    let detail: String
    let isDirectory: Bool
    var shared = false
    var id: String { url.path }
}

struct ApplicationDataReport: Sendable {
    let items: [AssociatedData]
    let note: String
}

enum ApplicationDataAnalyzer {
    static func inspect(_ app: InstalledApplication, home: URL = FileManager.default.homeDirectoryForCurrentUser, identityMatches: Int = 1, declaredGroups: [String]? = nil) throws -> ApplicationDataReport {
        guard let identifier = app.bundleID, ApplicationGroups.validComponent(identifier) else {
            return ApplicationDataReport(items: [], note: "O aplicativo não declarou um identificador utilizável. Não é possível atribuir dados pelo nome de exibição.")
        }
        let locations = [("Caches", "Caches/" + identifier), ("Suporte", "Application Support/" + identifier),
                         ("Preferências", "Preferences/" + identifier + ".plist"), ("Registros", "Logs/" + identifier),
                         ("Estado salvo", "Saved Application State/" + identifier + ".savedState"), ("Contêiner", "Containers/" + identifier)]
        let library = home.appendingPathComponent("Library")
        var items = try locations.map { title, relative in
            try Task.checkCancellation()
            return try inspectLocation(title: title, url: library.appendingPathComponent(relative))
        }
        var note = "Candidatos associados por convenção ao identificador \(identifier). A coincidência do caminho não comprova propriedade exclusiva; aplicativos podem usar outros locais."
        if identityMatches > 1 {
            items = items.map { item in var copy = item; copy.shared = true; return copy }
            note += " Há \(identityMatches) instalações com esse identificador; os dados podem ser usados por todas."
        }
        do {
            let groups = try declaredGroups ?? ApplicationGroups.declared(at: app.url)
            guard groups.allSatisfy(ApplicationGroups.validComponent) else { throw CocoaError(.fileReadCorruptFile) }
            for group in groups {
                try Task.checkCancellation()
                items.append(try inspectLocation(title: "Grupo compartilhado " + group, url: library.appendingPathComponent("Group Containers/" + group), shared: true))
            }
            note += " Os grupos compartilhados vêm dos entitlements declarados, sem atestar a assinatura ou exclusividade."
        } catch is CancellationError { throw CancellationError() }
        catch { note += " Não foi possível verificar grupos compartilhados: " + error.localizedDescription }
        return ApplicationDataReport(items: items, note: note)
    }

    static func inspectLocation(title: String, url: URL, shared: Bool = false) throws -> AssociatedData {
        do {
            let facts = try url.resourceValues(forKeys: [.isSymbolicLinkKey, .isDirectoryKey])
            if facts.isSymbolicLink == true { return AssociatedData(title: title, url: url, state: .link, bytes: nil, detail: "Não foi lido o destino do link.", isDirectory: false, shared: shared) }
            if facts.isDirectory == true {
                let result = try FileAnalyzer.scan(url)
                return AssociatedData(title: title, url: url, state: .present, bytes: result.bytes, detail: "\(result.files.count) arquivos; \(result.unreadableEntries) falhas; \(result.excludedEntries) exclusões.", isDirectory: true, shared: shared)
            }
            let identity = try FileIdentity.read(url.path)
            return AssociatedData(title: title, url: url, state: .present, bytes: identity.bytes, detail: "Arquivo regular.", isDirectory: false, shared: shared)
        } catch is CancellationError { throw CancellationError() }
        catch let issue as CocoaError where issue.code == .fileReadNoSuchFile {
            return AssociatedData(title: title, url: url, state: .absent, bytes: nil, detail: "Este caminho não existe no momento da leitura.", isDirectory: false, shared: shared)
        } catch {
            return AssociatedData(title: title, url: url, state: .inaccessible, bytes: nil, detail: error.localizedDescription, isDirectory: false, shared: shared)
        }
    }
}
