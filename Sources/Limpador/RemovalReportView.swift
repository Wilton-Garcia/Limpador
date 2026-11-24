import SwiftUI

struct RemovalReportView: View {
    let report: RemovalReport
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Resultado da operação").font(.headline)
            Text("Os itens enviados podem ser recuperados pelo Finder com Colocar de Volta. Nenhuma exclusão permanente é usada.").font(.caption).foregroundStyle(.secondary)
            Text("\(report.movedCount) enviados à Lixeira · \(report.entries.filter { $0.outcome == .skipped }.count) ignorados · \(report.entries.filter { $0.outcome == .failed }.count) falhas")
            List(report.entries) { entry in
                VStack(alignment: .leading, spacing: 5) {
                    Text(entry.path).font(.caption).textSelection(.enabled)
                    Text(entry.detail).font(.caption).foregroundStyle(entry.outcome == .trashed ? .secondary : Color.orange)
                    if entry.outcome == .trashed, let destination = entry.destination {
                        Button("Localizar destino na Lixeira") { NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: destination)]) }
                        Text(destination).font(.caption2).foregroundStyle(.secondary).textSelection(.enabled)
                    } else if entry.outcome == .trashed {
                        Text("O macOS confirmou o envio, mas não retornou o caminho de destino.").font(.caption).foregroundStyle(.secondary)
                    }
                }
            }.frame(minHeight: 160)
        }
    }
}
