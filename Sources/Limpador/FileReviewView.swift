import SwiftUI
import QuickLookUI

struct FileReviewView: View {
    let root: URL
    var initialResult: FileAnalysis? = nil
    var allowsRemoval = false
    var history: AnalysisHistory? = nil
    @Environment(\.dismiss) private var dismiss
    @State private var result: FileAnalysis?
    @State private var error: String?
    @State private var activeApps = RunningAppGuard(apps: [])
    @State private var query = FileQuery()
    @State private var ageMonths = 0
    @State private var findingDuplicates = false
    @State private var previewURL: URL?
    @State private var estimate: RecoveryEstimate?
    @State private var confirmingRemoval = false
    @State private var approvedFiles: [AnalyzedFile] = []
    @State private var removalTask: Task<Void, Never>?
    @State private var removalReport: RemovalReport?
    @State private var selected: Set<String> = []

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 5) {
                    Text("Revisar arquivos").font(.title2.bold())
                    Text(root.path).font(.caption).textSelection(.enabled)
                }
                Spacer()
                Button("Concluir") { dismiss() }.keyboardShortcut(.cancelAction)
            }
            if let result {
                let filtered = query.apply(to: result.files)
                HStack {
                    TextField("Buscar arquivos", text: $query.search).textFieldStyle(.roundedBorder)
                    Picker("Tipo", selection: $query.category) {
                        ForEach(["Todas"] + Set(result.files.map(\.category)).sorted(), id: \.self) { Text($0).tag($0) }
                    }.frame(width: 200)
                    Picker("Ordenar", selection: $query.order) {
                        ForEach(FileQuery.Order.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                    }.frame(width: 220)
                }
                Picker("Tamanho mínimo", selection: $query.minimumBytes) {
                    Text("Qualquer tamanho").tag(Int64(0))
                    Text("100 MB").tag(Int64(100_000_000))
                    Text("1 GB").tag(Int64(1_000_000_000))
                    Text("10 GB").tag(Int64(10_000_000_000))
                }.frame(maxWidth: 300)
                Picker("Última modificação", selection: $ageMonths) {
                    Text("Qualquer data").tag(0)
                    Text("Há mais de 6 meses").tag(6)
                    Text("Há mais de 1 ano").tag(12)
                    Text("Há mais de 2 anos").tag(24)
                }.frame(maxWidth: 330)
                .onChange(of: ageMonths) { _, months in
                    query.modifiedBefore = months == 0 ? nil : Calendar.current.date(byAdding: .month, value: -months, to: result.observedAt)
                }
                Toggle("Possíveis instaladores (.dmg, .pkg, .mpkg)", isOn: $query.installersOnly).toggleStyle(.checkbox)
                Text("\(filtered.count) arquivos visíveis").font(.caption).foregroundStyle(.secondary)
                Text("\(result.files.count) arquivos · \(selected.count) selecionados · " + ByteCountFormatter.string(fromByteCount: selectedBytes(result), countStyle: .file))
                Text("\(result.excludedEntries) entradas excluídas pelas preferências").font(.caption).foregroundStyle(.secondary)
                if result.unreadableEntries > 0 {
                    Label("Leitura parcial: \(result.unreadableEntries) entradas inacessíveis", systemImage: "exclamationmark.triangle").foregroundStyle(.orange)
                }
                HStack {
                    Button("Selecionar visíveis") { selected.formUnion(filtered.map(\.id)) }
                    Button("Encontrar duplicados") { findingDuplicates = true }
                    Button("Desmarcar") { selected.removeAll() }.disabled(selected.isEmpty)
                }
                List(filtered) { file in
                    HStack {
                        Toggle(isOn: Binding(get: { selected.contains(file.id) }, set: { value in
                            if value { selected.insert(file.id) } else { selected.remove(file.id) }
                        })) {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(file.url.lastPathComponent).lineLimit(1)
                                Text(file.path).font(.caption2).foregroundStyle(.secondary).lineLimit(1).truncationMode(.middle).help(file.path)
                            }
                        }.toggleStyle(.checkbox)
                        Spacer()
                        Text(ByteCountFormatter.string(fromByteCount: file.bytes, countStyle: .file)).monospacedDigit()
                        Button { previewURL = file.url } label: { Image(systemName: "eye") }
                            .help("Visualização rápida").accessibilityLabel("Visualizar \(file.url.lastPathComponent)")
                        Button { NSWorkspace.shared.activateFileViewerSelecting([file.url]) } label: { Image(systemName: "folder") }
                            .help("Mostrar no Finder").accessibilityLabel("Mostrar \(file.url.lastPathComponent) no Finder")
                    }.padding(.vertical, 5)
                }
                if let estimate {
                    Text("Espaço alocado estimado da seleção: " + ByteCountFormatter.string(fromByteCount: estimate.allocatedBytes, countStyle: .file))
                    Text("\(estimate.unverified) arquivos não verificados; \(estimate.sharedLinks) com múltiplos links. Clones, compressão e snapshots APFS podem alterar o espaço efetivamente liberado. Enviar à Lixeira não libera esse espaço imediatamente.").font(.caption).foregroundStyle(.secondary)
                }
                if allowsRemoval {
                    HStack {
                        Button("Enviar seleção à Lixeira", role: .destructive) {
                            approvedFiles = result.files.filter { selected.contains($0.id) }
                            confirmingRemoval = true
                        }.disabled(selected.isEmpty || removalTask != nil)
                        if removalTask != nil { ProgressView().controlSize(.small); Button("Cancelar operação") { removalTask?.cancel() } }
                    }
                }
                if let removalReport { RemovalReportView(report: removalReport) }
                Text("A associação usa o pacote ou identificador do app. Não detectar associação não comprova que um arquivo esteja sem uso. Remoções exigem confirmação. Os tamanhos são lógicos.").font(.caption).foregroundStyle(.secondary)
            } else if let error {
                ContentUnavailableView("Não foi possível ler esta pasta", systemImage: "exclamationmark.triangle", description: Text(error))
            } else {
                ProgressView("Lendo arquivos…").frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }.padding(24).frame(minWidth: 760, minHeight: 540)
        .confirmationDialog("Enviar \(approvedFiles.count) arquivos selecionados à Lixeira?", isPresented: $confirmingRemoval, titleVisibility: .visible) {
            Button("Confirmar envio à Lixeira", role: .destructive) { performRemoval() }
            Button("Cancelar", role: .cancel) { approvedFiles = [] }
        } message: { Text("Os arquivos serão retirados das pastas de origem. Aplicativos podem precisar recriá-los. Arquivos alterados, protegidos ou associados a apps em execução serão ignorados.") }
        .onDisappear { removalTask?.cancel() }
        .sheet(isPresented: Binding(get: { previewURL != nil }, set: { if !$0 { previewURL = nil } })) { if let previewURL { FilePreviewView(url: previewURL) } }
        .sheet(isPresented: $findingDuplicates) { if let result { DuplicateReviewView(files: result.files) } }
        .task(id: selected) {
            estimate = nil
            guard let result else { return }
            let files = result.files.filter { selected.contains($0.id) }
            let task = Task.detached(priority: .utility) { try RecoveryEstimate.calculate(files) }
            do {
                let value = try await withTaskCancellationHandler { try await task.value } onCancel: { task.cancel() }
                try Task.checkCancellation(); estimate = value
            } catch {}
        }
        .onReceive(NSWorkspace.shared.notificationCenter.publisher(for: NSWorkspace.didLaunchApplicationNotification)) { _ in activeApps = .snapshot() }
        .onReceive(NSWorkspace.shared.notificationCenter.publisher(for: NSWorkspace.didTerminateApplicationNotification)) { _ in activeApps = .snapshot() }
        .task(id: root) {
            activeApps = .snapshot()
            if let initialResult { result = initialResult; return }
            let worker = Task.detached(priority: .utility) { try FileAnalyzer.scan(root) }
            do {
                let analysis = try await withTaskCancellationHandler { try await worker.value } onCancel: { worker.cancel() }
                try Task.checkCancellation()
                result = analysis
            } catch is CancellationError {} catch { self.error = error.localizedDescription }
        }
    }

    private func performRemoval() {
        guard allowsRemoval, removalTask == nil, !approvedFiles.isEmpty else { return }
        let files = approvedFiles
        removalTask = Task { @MainActor in
            let worker = Task.detached(priority: .utility) { await FileRemoval.run(files, policy: RemovalPolicy(root: root)) }
            let report = await withTaskCancellationHandler { await worker.value } onCancel: { worker.cancel() }
            removalReport = report
            let moved = Set(report.entries.filter { $0.outcome == .trashed }.map(\.path))
            if let result {
                self.result = FileAnalysis(root: result.root, files: result.files.filter { !moved.contains($0.path) }, unreadableEntries: result.unreadableEntries, observedAt: result.observedAt, excludedEntries: result.excludedEntries)
            }
            selected.subtract(moved)
            history?.record(scope: root.path, outcome: "Limpeza: \(report.movedCount) enviados à Lixeira", itemCount: report.entries.count, report: report)
            approvedFiles = []; removalTask = nil
        }
    }

    private func selectedBytes(_ result: FileAnalysis) -> Int64 {
        result.files.reduce(0) { $0 + (selected.contains($1.id) ? $1.bytes : 0) }
    }
}
