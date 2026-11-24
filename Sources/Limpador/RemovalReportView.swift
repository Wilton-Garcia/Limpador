import SwiftUI

struct RemovalReportView: View {
    let report: RemovalReport
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Resultado da operação").font(.headline)
            Text("\(report.movedCount) enviados à Lixeira · \(report.entries.filter { $0.outcome == .skipped }.count) ignorados · \(report.entries.filter { $0.outcome == .failed }.count) falhas")
            List(report.entries) { entry in
                VStack(alignment: .leading, spacing: 5) {
                    Text(entry.path).font(.caption).textSelection(.enabled)
                    Text(entry.detail).font(.caption).foregroundStyle(entry.outcome == .trashed ? .secondary : Color.orange)
                }
            }.frame(minHeight: 160)
        }
    }
}
