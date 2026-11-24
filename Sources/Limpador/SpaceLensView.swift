import SwiftUI
import UniformTypeIdentifiers

struct SpaceLensView: View {
    @Bindable var model: SpaceLensModel
    let history: AnalysisHistory
    @AppStorage("spaceLensShowHidden") private var showHidden = true
    @State private var choosing = false
    @State private var volumes: [URL] = []
    @State private var search = ""
    @State private var review: FileAnalysis?
    @State private var reviewTitle: String?
    @State private var reviewTask: Task<Void, Never>?
    @State private var previewURL: URL?
    @State private var viewError: String?

    private var children: [SpaceLensNode] {
        guard let snapshot = model.snapshot else { return [] }
        return snapshot.children(of: model.currentID, showHidden: showHidden).filter {
            (model.focusedIDs == nil || model.focusedIDs!.contains($0.id)) && (search.isEmpty || $0.name.localizedStandardContains(search))
        }
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            heading
            controls
            if let error = model.error ?? viewError { Label(error, systemImage: "exclamationmark.triangle").font(.callout).foregroundStyle(.orange).textSelection(.enabled) }
            if model.loading {
                HStack { ProgressView().controlSize(.small); Text(model.progressLabel).font(.callout); Spacer(); Button("Cancelar análise") { model.cancel() } }
                    .padding(20).background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 14))
            }
            if let snapshot = model.snapshot, let current = snapshot.nodes[model.currentID] {
                breadcrumbs(snapshot)
                summary(current, snapshot: snapshot)
                HStack {
                    TextField("Filtrar itens desta pasta", text: $search).textFieldStyle(.roundedBorder).frame(maxWidth: 340)
                    Spacer()
                    Toggle("Mostrar ocultos", isOn: $showHidden).toggleStyle(.checkbox)
                }
                let visible = children
                let tiles = SpaceMapTile.make(visible)
                if tiles.isEmpty {
                    ContentUnavailableView("Nenhum bloco com tamanho conhecido", systemImage: "square.grid.3x3", description: Text("Pastas vazias, arquivos de tamanho zero e itens não lidos continuam na lista abaixo. Verifique também os filtros e as exclusões."))
                        .frame(minHeight: 220)
                } else {
                    SpaceTreemap(tiles: tiles, selected: model.selectedID, select: selectTile, open: openTile)
                }
                HStack {
                    Text("\(visible.count) itens visíveis de \(current.children.count)").font(.caption).foregroundStyle(.secondary)
                    Spacer()
                    if model.focusedIDs != nil { Button("Ver todos os itens desta pasta") { model.focusedIDs = nil; model.selectedID = nil } }
                }
                Text("Cada bloco representa o tamanho lógico relativo aos itens visíveis. Clique para selecionar; dê dois cliques para entrar em uma pasta. Itens pequenos são agrupados no mapa e continuam disponíveis na tabela.")
                    .font(.caption).foregroundStyle(.secondary)
                fileTable(visible)
                if let selected = model.selectedID.flatMap({ snapshot.nodes[$0] }) { details(selected, parent: current) }
                HStack {
                    Button("Revisar arquivos desta pasta") { prepareReview([current.id], title: current.url.path) }.disabled(reviewTask != nil || current.fileCount == 0)
                    if reviewTask != nil { ProgressView().controlSize(.small); Text("Preparando revisão…").font(.caption) }
                }
                Text("Lido em " + snapshot.analysis.observedAt.formatted(date: .abbreviated, time: .standard) + ". Tamanhos de arquivos, sem contabilizar metadados de diretórios. Hard links, clones, compressão e snapshots podem fazer o uso físico diferir do mapa.")
                    .font(.caption).foregroundStyle(.secondary)
            } else if !model.loading {
                emptyState
            }
        }
        .fileImporter(isPresented: $choosing, allowedContentTypes: [.folder]) { result in
            switch result {
            case .success(let url): start(url)
            case .failure(let error): viewError = error.localizedDescription
            }
        }
        .sheet(isPresented: Binding(get: { review != nil }, set: { if !$0 { review = nil } })) {
            if let review {
                FileReviewView(root: review.root, initialResult: review, selectionTitle: reviewTitle, allowsRemoval: true, history: history, onRemoval: { report in if report.movedCount > 0 { model.stale = true } })
            }
        }
        .sheet(isPresented: Binding(get: { previewURL != nil }, set: { if !$0 { previewURL = nil } })) { if let previewURL { FilePreviewView(url: previewURL) } }
        .onAppear { volumes = (FileManager.default.mountedVolumeURLs(includingResourceValuesForKeys: [.volumeIsLocalKey, .volumeNameKey], options: [.skipHiddenVolumes]) ?? []).filter { (try? $0.resourceValues(forKeys: [.volumeIsLocalKey]).volumeIsLocal) == true } }
        .onChange(of: model.currentID) { _, _ in search = "" }
        .onChange(of: search) { _, _ in model.selectedID = nil }
        .onChange(of: showHidden) { _, _ in model.selectedID = nil }
        .onDisappear { model.cancel(); reviewTask?.cancel() }
    }

    private var heading: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Seu espaço, em perspectiva.").font(.system(size: 28, weight: .semibold, design: .rounded))
            Text("Explore o armazenamento local, entre em pastas e encontre o que realmente ocupa espaço.").foregroundStyle(.secondary)
        }
    }
    private var controls: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 10) { rootButtons; Spacer(); refreshButtons }
            VStack(alignment: .leading, spacing: 10) { HStack { rootButtons }; HStack { refreshButtons } }
        }
    }
    @ViewBuilder private var rootButtons: some View {
        Button { choosing = true } label: { Label("Escolher pasta", systemImage: "folder.badge.plus") }.buttonStyle(.borderedProminent).disabled(model.loading)
        Button("Downloads") { start(URL.downloadsDirectory) }.disabled(model.loading)
        Menu("Volumes locais") {
            ForEach(volumes, id: \.path) { url in Button((try? url.resourceValues(forKeys: [.volumeNameKey]).volumeName) ?? url.path) { start(url) } }
        }.fixedSize().disabled(model.loading || volumes.isEmpty)
    }
    @ViewBuilder private var refreshButtons: some View {
        if let root = model.root {
            Button { start(root) } label: { Label("Reanalisar", systemImage: "arrow.clockwise") }.disabled(model.loading)
            Button("Fechar análise") { model.reset() }.disabled(model.loading)
        }
    }
    private var emptyState: some View {
        VStack(spacing: 18) {
            Image(systemName: "square.grid.3x3.fill").font(.system(size: 54, weight: .light)).foregroundStyle(.teal)
            Text("Uma nova forma de enxergar seus arquivos.").font(.title3.weight(.semibold))
            Text("Escolha uma pasta ou um volume local. A Lupa mostra arquivos ocultos, pastas e pacotes de aplicativos, respeitando suas exclusões e as permissões do macOS.")
                .font(.callout).foregroundStyle(.secondary).multilineTextAlignment(.center).frame(maxWidth: 480)
        }.frame(maxWidth: .infinity).padding(.vertical, 70)
            .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 18))
    }
    private func breadcrumbs(_ snapshot: SpaceLensSnapshot) -> some View {
        HStack {
            Button { model.up() } label: { Image(systemName: "arrow.up") }.disabled(model.currentID.isEmpty && model.focusedIDs == nil).help("Subir um nível").accessibilityLabel("Subir um nível")
            ScrollView(.horizontal) {
                HStack(spacing: 8) {
                    ForEach(snapshot.breadcrumbs(to: model.currentID)) { node in
                        Button(node.name) { model.navigate(to: node.id) }.buttonStyle(.link)
                        Image(systemName: "chevron.right").font(.caption2).foregroundStyle(.secondary)
                    }
                    if model.focusedIDs != nil { Text("Itens menores").font(.caption) }
                }
            }.scrollIndicators(.hidden)
        }
    }
    private func summary(_ node: SpaceLensNode, snapshot: SpaceLensSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text(node.name).font(.title2.weight(.semibold)).lineLimit(1)
                Spacer()
                Text(size(node)).font(.system(size: 30, weight: .medium, design: .rounded)).monospacedDigit()
            }
            Text(node.url.path).font(.caption).textSelection(.enabled)
            Text("\(node.fileCount.formatted()) arquivos · \(node.children.count.formatted()) itens neste nível · \(node.unreadableCount) entradas não lidas").font(.caption).foregroundStyle(.secondary)
            Text("\(snapshot.analysis.excludedEntries) entradas excluídas · \(snapshot.analysis.skippedLinks) links não seguidos").font(.caption).foregroundStyle(.secondary)
            if node.unreadableCount > 0 { Label("Resultado parcial: os tamanhos incluem apenas os arquivos lidos.", systemImage: "exclamationmark.triangle").font(.caption).foregroundStyle(.orange) }
            if model.stale { Label("O mapa é anterior à limpeza. Reanalise para atualizar os tamanhos.", systemImage: "arrow.clockwise").font(.callout).foregroundStyle(.orange) }
        }.padding(20).background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 16))
    }
    private func fileTable(_ nodes: [SpaceLensNode]) -> some View {
        Table(nodes, selection: $model.selectedID) {
            TableColumn("Nome") { node in
                HStack {
                    Image(systemName: node.kind == .directory ? (node.isPackage == true ? "shippingbox" : "folder.fill") : node.kind == .file ? "doc" : "exclamationmark.triangle").foregroundStyle(node.kind == .directory ? Color.teal : .secondary)
                    Text(node.name).lineLimit(1)
                    if node.isHidden == true { Text("Oculto").font(.caption2).foregroundStyle(.secondary) }
                }
            }.width(min: 160, ideal: 310)
            TableColumn("Tamanho") { node in Text(size(node)) }.width(min: 100, ideal: 130)
            TableColumn("Arquivos") { node in Text(node.fileCount.formatted()).foregroundStyle(.secondary) }.width(80)
        }
        .frame(height: 240)
        .contextMenu(forSelectionType: String.self) { ids in
            if let id = ids.first, let node = model.snapshot?.nodes[id] {
                Button(node.kind == .directory ? "Entrar na pasta" : "Visualizar") { openNode(node) }
                Button("Mostrar no Finder") { NSWorkspace.shared.activateFileViewerSelecting([node.url]) }
                Button("Revisar arquivos") { prepareReview(Array(ids), title: node.url.path) }.disabled(reviewTask != nil)
            }
        } primaryAction: { ids in if let id = ids.first, let node = model.snapshot?.nodes[id] { openNode(node) } }
    }
    private func details(_ node: SpaceLensNode, parent: SpaceLensNode) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack { Text(node.name).font(.headline); Spacer(); Text(size(node)).monospacedDigit() }
            Text(node.url.path).font(.caption).textSelection(.enabled)
            if parent.bytes > 0 { Text((Double(node.bytes) / Double(parent.bytes)).formatted(.percent.precision(.fractionLength(1))) + " dos bytes conhecidos desta pasta").font(.caption).foregroundStyle(.secondary) }
            HStack {
                if node.kind == .directory { Button("Entrar nesta pasta") { model.navigate(to: node.id) } }
                if node.kind == .file { Button("Visualizar") { previewURL = node.url } }
                Button("Mostrar no Finder") { NSWorkspace.shared.activateFileViewerSelecting([node.url]) }
                Button("Revisar para limpeza…") { prepareReview([node.id], title: node.url.path) }.disabled(reviewTask != nil || node.fileCount == 0)
            }
        }.padding(20).background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 16))
    }
    private func size(_ node: SpaceLensNode) -> String {
        if node.bytes == 0 && node.unreadableCount > 0 { return "Não determinado" }
        return ByteCountFormatter.string(fromByteCount: node.bytes, countStyle: .file) + (node.unreadableCount > 0 ? "+" : "")
    }
    private func start(_ url: URL) { search = ""; viewError = nil; Task { await model.scan(url, history: history) } }
    private func selectTile(_ tile: SpaceMapTile) {
        switch tile.id {
        case .node(let id):
            guard model.snapshot?.nodes[id]?.parentID == model.currentID else { return }
            model.selectedID = id
        case .remainder: model.focusedIDs = Set(tile.nodeIDs); model.selectedID = nil
        }
    }
    private func openTile(_ tile: SpaceMapTile) {
        if case .node(let id) = tile.id, let node = model.snapshot?.nodes[id] { openNode(node) }
        else { selectTile(tile) }
    }
    private func openNode(_ node: SpaceLensNode) {
        if node.kind == .directory { model.navigate(to: node.id) }
        else if node.kind == .file { previewURL = node.url }
    }
    private func prepareReview(_ ids: [String], title: String) {
        guard reviewTask == nil, let snapshot = model.snapshot else { return }
        reviewTask = Task { @MainActor in
            defer { reviewTask = nil }
            let worker = Task.detached(priority: .utility) { try snapshot.review(nodeIDs: ids) }
            do {
                let value = try await withTaskCancellationHandler { try await worker.value } onCancel: { worker.cancel() }
                try Task.checkCancellation(); reviewTitle = title; review = value
            } catch is CancellationError {} catch { viewError = error.localizedDescription }
        }
    }
}
