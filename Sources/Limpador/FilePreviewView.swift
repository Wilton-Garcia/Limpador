import SwiftUI
import QuickLookUI

private struct NativeFilePreview: NSViewRepresentable {
    let url: URL
    func makeNSView(context: Context) -> QLPreviewView {
        QLPreviewView(frame: .zero, style: .normal)
    }
    func updateNSView(_ view: QLPreviewView, context: Context) { view.previewItem = url as NSURL }
    static func dismantleNSView(_ view: QLPreviewView, coordinator: ()) { view.previewItem = nil }
}

struct FilePreviewView: View {
    let url: URL
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        VStack(spacing: 12) {
            HStack { Text(url.lastPathComponent).font(.headline); Spacer(); Button("Concluir") { dismiss() } }
            NativeFilePreview(url: url)
            Text(url.path).font(.caption).foregroundStyle(.secondary).textSelection(.enabled)
        }.padding(20).frame(minWidth: 700, minHeight: 500)
    }
}
