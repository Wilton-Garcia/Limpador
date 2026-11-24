import Foundation
import Security

enum ApplicationGroups {
    static func declared(at url: URL) throws -> [String] {
        var code: SecStaticCode?
        let createStatus = SecStaticCodeCreateWithPath(url as CFURL, SecCSFlags(), &code)
        guard createStatus == errSecSuccess, let code else { throw NSError(domain: NSOSStatusErrorDomain, code: Int(createStatus)) }
        var info: CFDictionary?
        let status = SecCodeCopySigningInformation(code, SecCSFlags(rawValue: kSecCSSigningInformation), &info)
        guard status == errSecSuccess, let dictionary = info as? [String: Any] else { throw NSError(domain: NSOSStatusErrorDomain, code: Int(status)) }
        let entitlements = dictionary[kSecCodeInfoEntitlementsDict as String] as? [String: Any]
        guard let raw = entitlements?["com.apple.security.application-groups"] else { return [] }
        guard let names = raw as? [String], names.allSatisfy(validComponent) else { throw CocoaError(.fileReadCorruptFile) }
        return Array(Set(names)).sorted()
    }
    static func validComponent(_ name: String) -> Bool {
        !name.isEmpty && name != "." && name != ".." && !name.contains("/") && !name.contains("\\") && !name.contains("\0")
    }
}
