import SwiftUI

struct PreferenceResetView: View {
    let identifier: String
    let history: AnalysisHistory?
    @Environment(\.dismiss) private var dismiss
    @State private var backup: PreferencesBackup?
    @State private var confirmingReset = false
    @State private var confirmingRestore = false
    @State private var message: String?
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack { Text("Configurações do aplicativo").font(.title2.bold()); Spacer(); Button("Concluir") { dismiss() } }
            Text(identifier).font(.caption).textSelection(.enabled)
            Text("Restaura os padrões do domínio de preferências do usuário, com backup prévio. Não altera documentos, credenciais, contêineres sandbox, grupos compartilhados ou preferências específicas deste computador.")
            Text("Encerre o aplicativo antes de continuar. A restauração do backup substitui as preferências atuais desse domínio.").font(.caption).foregroundStyle(.secondary)
            Button("Restaurar padrões…", role: .destructive) { confirmingReset = true }.disabled(backup != nil)
            if let backup {
                Text("Backup: " + backup.url.path).font(.caption).textSelection(.enabled)
                Button("Mostrar backup no Finder") { NSWorkspace.shared.activateFileViewerSelecting([backup.url]) }
                Button("Recuperar configurações do backup…") { confirmingRestore = true }
            }
            if let message { Text(message).font(.caption).textSelection(.enabled) }
        }.padding(24).frame(width: 620)
        .confirmationDialog("Restaurar as configurações padrão?", isPresented: $confirmingReset, titleVisibility: .visible) {
            Button("Criar backup e restaurar padrões", role: .destructive) {
                do {
                    backup = try PreferenceReset.reset(identifier, running: .snapshot())
                    message = "Domínio padrão restaurado. O backup foi preservado."
                    history?.record(scope: identifier, outcome: "Preferências restauradas com backup")
                } catch { message = error.localizedDescription }
            }
        }
        .confirmationDialog("Substituir preferências atuais pelo backup?", isPresented: $confirmingRestore, titleVisibility: .visible) {
            Button("Recuperar backup", role: .destructive) {
                guard let backup else { return }
                do { try PreferenceReset.restore(backup, running: .snapshot()); message = "Configurações recuperadas." }
                catch { message = error.localizedDescription }
            }
        }
    }
}
