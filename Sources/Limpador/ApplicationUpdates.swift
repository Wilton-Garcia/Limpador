import Foundation
#if canImport(FoundationXML)
import FoundationXML
#endif
import Security

struct AppcastVersion: Sendable {
    var build = ""
    var display = ""
    var minimumSystem = ""
    var channel = ""
}

private final class AppcastParser: NSObject, XMLParserDelegate {
    static let sparkle = "http://www.andymatuschak.org/xml-namespaces/sparkle"
    var releases: [AppcastVersion] = []
    private var current: AppcastVersion?
    private var depth = 0
    private var itemDepth = 0
    private var field: String?
    private var text = ""
    private var namespaces: [String: [String]] = [:]
    func parser(_ parser: XMLParser, didStartMappingPrefix prefix: String, toURI namespaceURI: String) { namespaces[prefix, default: []].append(namespaceURI) }
    func parser(_ parser: XMLParser, didEndMappingPrefix prefix: String) { _ = namespaces[prefix]?.popLast() }
    func parser(_ parser: XMLParser, didStartElement name: String, namespaceURI: String?, qualifiedName qName: String?, attributes: [String: String]) {
        depth += 1
        if name == "item", current == nil { current = AppcastVersion(); itemDepth = depth }
        guard current != nil, depth == itemDepth + 1 else { return }
        if namespaceURI == Self.sparkle { field = name; text = "" }
        if name == "enclosure" {
            for (key, value) in attributes {
                let parts = key.split(separator: ":", maxSplits: 1).map(String.init)
                guard parts.count == 2, namespaces[parts[0]]?.last == Self.sparkle else { continue }
                if parts[1] == "version" { current?.build = value }
                if parts[1] == "shortVersionString" { current?.display = value }
            }
        }
    }
    func parser(_ parser: XMLParser, foundCharacters string: String) { if field != nil { text += string } }
    func parser(_ parser: XMLParser, didEndElement name: String, namespaceURI: String?, qualifiedName qName: String?) {
        if depth == itemDepth + 1, let field {
            let value = text.trimmingCharacters(in: .whitespacesAndNewlines)
            switch field {
            case "version": current?.build = value
            case "shortVersionString": current?.display = value
            case "minimumSystemVersion": current?.minimumSystem = value
            case "channel": current?.channel = value
            default: break
            }
            self.field = nil; text = ""
        }
        if name == "item", depth == itemDepth, let current { releases.append(current); self.current = nil }
        depth -= 1
    }
}

enum ApplicationUpdates {
    static func parse(_ data: Data) throws -> [AppcastVersion] {
        let delegate = AppcastParser()
        let parser = XMLParser(data: data)
        parser.shouldProcessNamespaces = true
        parser.shouldReportNamespacePrefixes = true
        parser.shouldResolveExternalEntities = false
        parser.delegate = delegate
        guard parser.parse() else { throw parser.parserError ?? CocoaError(.fileReadCorruptFile) }
        return delegate.releases
    }
    static func compareNumeric(_ left: String, _ right: String) -> ComparisonResult? {
        func components(_ value: String) -> [String]? {
            let parts = value.split(separator: ".", omittingEmptySubsequences: false).map(String.init)
            guard !parts.isEmpty, parts.allSatisfy({ !$0.isEmpty && $0.utf8.allSatisfy { (48...57).contains($0) } }) else { return nil }
            return parts
        }
        guard let a = components(left), let b = components(right) else { return nil }
        for index in 0..<max(a.count, b.count) {
            let x = index < a.count ? a[index] : "0", y = index < b.count ? b[index] : "0"
            let comparison = x.compare(y, options: .numeric)
            if comparison != .orderedSame { return comparison }
        }
        return .orderedSame
    }
    static func feed(for app: InstalledApplication) throws -> URL? {
        guard let raw = Bundle(url: app.url)?.object(forInfoDictionaryKey: "SUFeedURL") as? String else { return nil }
        guard let url = URL(string: raw), url.scheme == "https", url.host != nil, url.user == nil, url.password == nil else { throw URLError(.badURL) }
        var code: SecStaticCode?
        let status = SecStaticCodeCreateWithPath(app.url as CFURL, SecCSFlags(), &code)
        guard status == errSecSuccess, let code else { throw NSError(domain: NSOSStatusErrorDomain, code: Int(status)) }
        let validation = SecStaticCodeCheckValidity(code, SecCSFlags(rawValue: kSecCSStrictValidate), nil)
        guard validation == errSecSuccess else { throw NSError(domain: NSOSStatusErrorDomain, code: Int(validation)) }
        return url
    }
    static func fetch(_ url: URL) async throws -> [AppcastVersion] {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.httpShouldSetCookies = false
        configuration.timeoutIntervalForRequest = 20
        configuration.timeoutIntervalForResource = 60
        let session = URLSession(configuration: configuration)
        defer { session.invalidateAndCancel() }
        let (bytes, response) = try await session.bytes(from: url)
        guard let response = response as? HTTPURLResponse, (200..<300).contains(response.statusCode), response.url?.scheme == "https" else { throw URLError(.badServerResponse) }
        var data = Data()
        for try await byte in bytes {
            try Task.checkCancellation()
            guard data.count < 8 * 1024 * 1024 else { throw NSError(domain: "Limpador", code: 4, userInfo: [NSLocalizedDescriptionKey: "Feed maior que o limite de leitura de 8 MiB. Consulte o atualizador do próprio aplicativo."]) }
            data.append(byte)
        }
        return try parse(data)
    }
}
