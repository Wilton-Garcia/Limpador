import SwiftUI

struct ProjectRelease: Decodable, Sendable {
    let tag_name: String
    let html_url: URL
    let draft: Bool
    let prerelease: Bool
}

enum ProjectUpdates {
    static func parse(_ data: Data) throws -> ProjectRelease {
        let release = try JSONDecoder().decode(ProjectRelease.self, from: data)
        guard release.html_url.scheme == "https", release.html_url.host == "github.com",
              release.html_url.path.hasPrefix("/Wilton-Garcia/Limpador/releases/"), !release.draft, !release.prerelease else { throw CocoaError(.fileReadCorruptFile) }
        return release
    }
    static func latest() async throws -> ProjectRelease? {
        let url = URL(string: "https://api.github.com/repos/Wilton-Garcia/Limpador/releases/latest")!
        var request = URLRequest(url: url)
        request.timeoutInterval = 20
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("Limpador/" + AppIdentity.version, forHTTPHeaderField: "User-Agent")
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let response = response as? HTTPURLResponse else { throw URLError(.badServerResponse) }
        if response.statusCode == 404 { return nil }
        guard response.statusCode == 200 else { throw NSError(domain: "Limpador", code: response.statusCode, userInfo: [NSLocalizedDescriptionKey: "GitHub retornou HTTP \(response.statusCode). Tente novamente mais tarde."]) }
        return try parse(data)
    }
}

struct ProjectUpdatePreferences: View {
    @State private var request = 0
    @State private var loading = false
    @State private var release: ProjectRelease?
    @State private var message: String?
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Atualização do Limpador").font(.headline)
            Text("Versão instalada: " + AppIdentity.version).font(.caption)
            Button("Consultar releases do projeto") { request += 1 }.disabled(loading)
            if loading { ProgressView().controlSize(.small) }
            if let message { Text(message).font(.caption) }
            if let release { Link("Abrir release " + release.tag_name, destination: release.html_url) }
            Link("Abrir repositório do Limpador", destination: AppIdentity.projectURL)
            Text("Atualização manual: consulte a release, encerre o aplicativo e use o instalador local da versão revisada. Ele preserva a instalação anterior. Nenhum download de executável ou instalação é iniciado por esta consulta.").font(.caption).foregroundStyle(.secondary)
        }
        .task(id: request) {
            guard request > 0 else { return }
            loading = true; release = nil; message = nil
            defer { loading = false }
            do {
                guard let latest = try await ProjectUpdates.latest() else { message = "Nenhuma release estável publicada ou repositório indisponível para consulta pública. Consulte o repositório."; return }
                try Task.checkCancellation(); release = latest
                let version = latest.tag_name.hasPrefix("v") ? String(latest.tag_name.dropFirst()) : latest.tag_name
                switch ApplicationUpdates.compareNumeric(version, AppIdentity.version) {
                case .orderedDescending?: message = "Há uma release com versão superior."
                case .orderedSame?, .orderedAscending?: message = "Não há versão numericamente superior nesta consulta."
                case nil: message = "A comparação automática de versões não está disponível."
                }
            } catch is CancellationError {} catch { message = error.localizedDescription }
        }
    }
}
