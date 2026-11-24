import Foundation

struct PreferencesBackup: Sendable {
    let identifier: String
    let url: URL
}

enum PreferenceReset {
    static func validate(_ identifier: String, running: RunningAppGuard) throws {
        guard ApplicationGroups.validComponent(identifier), !identifier.hasPrefix("com.apple."), identifier != "local.limpador.app" else { throw CocoaError(.fileWriteNoPermission) }
        guard !running.apps.contains(where: { $0.bundleID == identifier }) else { throw NSError(domain: "Limpador", code: 1, userInfo: [NSLocalizedDescriptionKey: "Encerre o aplicativo antes de alterar suas preferências."]) }
    }
    static func reset(_ identifier: String, running: RunningAppGuard,
                      backupRoot: URL = URL.applicationSupportDirectory.appendingPathComponent("Limpador/PreferenceBackups")) throws -> PreferencesBackup {
        try validate(identifier, running: running)
        let defaults = UserDefaults.standard
        guard defaults.synchronize(), let values = defaults.persistentDomain(forName: identifier), !values.isEmpty else {
            throw NSError(domain: "Limpador", code: 2, userInfo: [NSLocalizedDescriptionKey: "Nenhuma preferência acessível no domínio padrão. Contêineres sandbox não são alterados."])
        }
        let backup = backupRoot.appendingPathComponent(UUID().uuidString + ".plist")
        try FileManager.default.createDirectory(at: backupRoot, withIntermediateDirectories: true)
        let data = try PropertyListSerialization.data(fromPropertyList: ["identifier": identifier, "values": values, "createdAt": Date()], format: .binary, options: 0)
        try data.write(to: backup, options: .atomic)
        guard try Data(contentsOf: backup) == data else { throw CocoaError(.fileWriteUnknown) }
        defaults.removePersistentDomain(forName: identifier)
        guard defaults.synchronize() else { throw NSError(domain: "Limpador", code: 3, userInfo: [NSLocalizedDescriptionKey: "Não foi possível confirmar a gravação. Backup preservado em " + backup.path]) }
        return PreferencesBackup(identifier: identifier, url: backup)
    }
    static func restore(_ backup: PreferencesBackup, running: RunningAppGuard) throws {
        try validate(backup.identifier, running: running)
        let object = try PropertyListSerialization.propertyList(from: Data(contentsOf: backup.url), format: nil)
        guard let dictionary = object as? [String: Any], dictionary["identifier"] as? String == backup.identifier,
              let values = dictionary["values"] as? [String: Any] else { throw CocoaError(.fileReadCorruptFile) }
        UserDefaults.standard.setPersistentDomain(values, forName: backup.identifier)
        guard UserDefaults.standard.synchronize() else { throw CocoaError(.fileWriteUnknown) }
    }
}
