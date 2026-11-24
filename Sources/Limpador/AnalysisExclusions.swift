import SwiftUI
import UniformTypeIdentifiers

struct AnalysisExclusions: Sendable {
    let paths: [String]
    init(paths: [String]) { self.paths = paths.map { URL(fileURLWithPath: $0).standardizedFileURL.path } }
    static func load() -> Self { Self(paths: UserDefaults.standard.stringArray(forKey: "excludedAnalysisPaths") ?? []) }
    func contains(_ path: String) -> Bool {
        let normalized = URL(fileURLWithPath: path).standardizedFileURL.path
        return paths.contains { normalized == $0 || normalized.hasPrefix($0 == "/" ? "/" : $0 + "/") }
    }
}

struct AnalysisExclusionPreferences: View {
    @State private var paths = AnalysisExclusions.load().paths
    @State private var choosing = false
    @State private var error: String?
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Exclusões da análise de arquivos").font(.headline)
            Text("Aplicam-se às próximas leituras de pastas, Downloads e arquivos de aplicativos. O inventário geral de aplicativos continua independente.").font(.caption).foregroundStyle(.secondary)
            ForEach(paths, id: \.self) { path in
                HStack {
                    Text(path).font(.caption).textSelection(.enabled)
                    Spacer()
                    Button("Retirar da lista") { paths.removeAll { $0 == path }; save() }
                }
            }
            if let error { Text(error).font(.caption).foregroundStyle(.orange) }
            Button("Adicionar exclusão") { choosing = true }
        }
        .fileImporter(isPresented: $choosing, allowedContentTypes: [.item, .folder], allowsMultipleSelection: true) { result in
            switch result {
            case .success(let urls): paths = Array(Set(paths + urls.map(\.path))).sorted(); save()
            case .failure(let issue): error = issue.localizedDescription
            }
        }
    }
    private func save() { UserDefaults.standard.set(paths, forKey: "excludedAnalysisPaths") }
}
