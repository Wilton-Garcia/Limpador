import SwiftUI

struct PathPermission: Identifiable, Sendable {
    enum Status: String, Sendable { case readable = "Leitura permitida neste caminho", missing = "Caminho não encontrado", denied = "Leitura negada", unknown = "Não foi possível determinar" }
    let url: URL
    let status: Status
    let detail: String
    var id: String { url.path }
}

enum PermissionProbe {
    static func inspect(_ url: URL) -> PathPermission {
        do {
            _ = try FileManager.default.contentsOfDirectory(at: url, includingPropertiesForKeys: [])
            return PathPermission(url: url, status: .readable, detail: "Foi possível listar esta pasta. Isso não comprova Acesso Total ao Disco.")
        } catch let error as CocoaError where error.code == .fileReadNoSuchFile {
            return PathPermission(url: url, status: .missing, detail: error.localizedDescription)
        } catch let error as CocoaError where error.code == .fileReadNoPermission {
            return PathPermission(url: url, status: .denied, detail: error.localizedDescription)
        } catch let error as POSIXError where error.code == .EACCES || error.code == .EPERM {
            return PathPermission(url: url, status: .denied, detail: error.localizedDescription)
        } catch { return PathPermission(url: url, status: .unknown, detail: error.localizedDescription) }
    }
}

struct PrivacyPermissionsView: View {
    @State private var results: [PathPermission] = []
    @State private var request = 0
    @State private var loading = false
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Permissões e áreas protegidas").font(.headline)
            Text("O macOS pode bloquear a leitura de Lixeira, pastas de suporte e outras áreas. Para analisar essas áreas, abra Privacidade e Segurança → Acesso Total ao Disco, adicione este Limpador e reabra o aplicativo. A escolha de uma pasta na análise também permite conceder acesso àquela seleção.").font(.caption).foregroundStyle(.secondary)
            HStack {
                Button("Abrir Acesso Total ao Disco") { NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles")!) }
                Button("Mostrar este Limpador no Finder") { NSWorkspace.shared.activateFileViewerSelecting([Bundle.main.bundleURL]) }
            }
            Button("Testar leitura de pastas protegidas") { request += 1 }.disabled(loading)
            Text("O diagnóstico apenas tenta listar as pastas indicadas. Não altera permissões nem configurações de privacidade.").font(.caption).foregroundStyle(.secondary)
            ForEach(results) { result in
                VStack(alignment: .leading, spacing: 4) {
                    Text(result.url.path).font(.caption).textSelection(.enabled)
                    Text(result.status.rawValue).font(.caption.bold()).foregroundStyle(result.status == .readable ? Color.secondary : .orange)
                    Text(result.detail).font(.caption2).foregroundStyle(.secondary)
                }
            }
        }
        .task(id: request) {
            guard request > 0 else { return }
            loading = true
            defer { loading = false }
            let home = FileManager.default.homeDirectoryForCurrentUser
            let paths = [home.appendingPathComponent(".Trash"), home.appendingPathComponent("Library/Caches")]
            let worker = Task.detached(priority: .utility) { paths.map(PermissionProbe.inspect) }
            let report = await worker.value
            guard !Task.isCancelled else { return }
            results = report
        }
    }
}
