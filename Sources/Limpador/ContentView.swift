import SwiftUI

private enum Palette {
    static let ink = Color(red: 0.13, green: 0.20, blue: 0.23)
    static let muted = Color(red: 0.44, green: 0.49, blue: 0.50)
    static let canvas = Color(red: 0.97, green: 0.97, blue: 0.95)
    static let teal = Color(red: 0.08, green: 0.43, blue: 0.38)
    static let line = Color.black.opacity(0.07)
}

private enum Destination: String, CaseIterable, Identifiable {
    case overview = "Visão geral"
    case cleanup = "Limpeza"
    case storage = "Armazenamento"
    case apps = "Aplicativos"
    case history = "Histórico"
    case settings = "Preferências"
    var id: String { rawValue }
    var symbol: String {
        switch self {
        case .overview: "square.grid.2x2"
        case .cleanup: "sparkles"
        case .storage: "internaldrive"
        case .apps: "square.stack.3d.up"
        case .history: "clock.arrow.circlepath"
        case .settings: "slider.horizontal.3"
        }
    }
}

private struct CleanupCategory: Identifiable {
    let id: String
    let title: String
    let subtitle: String
    let size: String
    let symbol: String
    let color: Color
}

private let categories = [
    CleanupCategory(id: "cache", title: "Caches de aplicativos", subtitle: "Arquivos temporários usados pelos aplicativos", size: "6,2 GB", symbol: "shippingbox", color: .orange),
    CleanupCategory(id: "logs", title: "Registros do sistema", subtitle: "Relatórios e registros de atividades anteriores", size: "1,8 GB", symbol: "doc.text", color: .blue),
    CleanupCategory(id: "downloads", title: "Downloads antigos", subtitle: "Arquivos para você revisar antes de remover", size: "4,4 GB", symbol: "arrow.down.circle", color: Palette.teal)
]

struct ContentView: View {
    @State private var mac = MacDataModel()
    @State private var destination: Destination = .overview
    @State private var progress = 0.0
    @State private var scanTask: Task<Void, Never>?
    @State private var hasResults = false
    @State private var selected: Set<String> = ["cache", "logs"]
    @State private var search = ""
    @State private var inspectedApplication: InstalledApplication?
    @State private var showRemovalNotice = false
    @AppStorage("compactNumbers") private var compactNumbers = true
    @AppStorage("scanOnLaunch") private var scanOnLaunch = true
    private var isScanning: Bool { scanTask != nil }

    var body: some View {
        HStack(spacing: 0) {
            sidebar
            Rectangle().fill(Palette.line).frame(width: 1)
            VStack(spacing: 0) {
                topbar
                ScrollView {
                    VStack(alignment: .leading, spacing: 26) {
                        switch destination {
                        case .overview: overview
                        case .cleanup: cleanup
                        case .storage: storage
                        case .apps: applications
                        case .history: history
                        case .settings: settings
                        }
                        demoFooter
                    }
                    .padding(32)
                    .frame(maxWidth: 1120)
                    .frame(maxWidth: .infinity)
                }
            }
            .background(Palette.canvas)
        }
        .foregroundStyle(Palette.ink)
        .tint(Palette.teal)
        .alert("Interface em demonstração", isPresented: $showRemovalNotice) {
            Button("Entendi", role: .cancel) {}
        } message: {
            Text("Os resultados são exemplos. Nenhum arquivo foi acessado ou removido. A limpeza real estará disponível quando o motor de análise for implementado.")
        }
        .sheet(item: $inspectedApplication) { app in FileReviewView(root: app.url) }
        .task { if scanOnLaunch { await mac.refresh() } }
        .onDisappear { cancelScan(); mac.cancel() }
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 10) {
                Image(systemName: "sparkles").font(.system(size: 23, weight: .medium))
                    .foregroundStyle(.white).frame(width: 42, height: 42)
                    .background(Palette.teal, in: RoundedRectangle(cornerRadius: 13))
                VStack(alignment: .leading, spacing: 1) {
                    Text("Limpador").font(.system(size: 20, weight: .bold, design: .rounded))
                    Text("Um Mac mais leve.").font(.system(size: 11)).foregroundStyle(Palette.muted)
                }
            }
            .padding(.bottom, 38)
            Text("SEU ESPAÇO").font(.system(size: 10, weight: .semibold)).tracking(1.8)
                .foregroundStyle(Palette.muted).padding(.leading, 12).padding(.bottom, 13)
            ForEach(Destination.allCases.filter { $0 != .settings }) { item in
                navigationButton(item)
            }
            Spacer()
            VStack(alignment: .leading, spacing: 12) {
                Label("Feito para o seu Mac", systemImage: "leaf").font(.system(size: 12, weight: .semibold))
                Text("Mais espaço para o que\nimporta para você.")
                    .font(.system(size: 12)).foregroundStyle(Palette.muted).lineSpacing(4)
                HStack(spacing: 5) {
                    Circle().fill(Palette.teal).frame(width: 5, height: 5)
                    Text("Dados locais do Mac").font(.system(size: 10, weight: .medium))
                }
            }
            .padding(16).frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.white.opacity(0.65), in: RoundedRectangle(cornerRadius: 16))
            .padding(.bottom, 18)
            navigationButton(.settings)
            Text("LIMPADOR  /  0.1").font(.system(size: 9, weight: .medium, design: .monospaced))
                .foregroundStyle(Palette.muted).padding(.leading, 12).padding(.top, 20)
        }
        .padding(.horizontal, 18).padding(.top, 48).padding(.bottom, 24)
        .frame(width: 225)
        .background(Color(red: 0.93, green: 0.94, blue: 0.91))
    }

    private func navigationButton(_ item: Destination) -> some View {
        Button { destination = item } label: {
            HStack(spacing: 12) {
                Image(systemName: item.symbol).font(.system(size: 15)).frame(width: 20)
                Text(item.rawValue).font(.system(size: 13, weight: destination == item ? .semibold : .medium))
                Spacer()
                if destination == item {
                    Circle().fill(Palette.teal).frame(width: 5, height: 5)
                }
            }
            .foregroundStyle(destination == item ? Palette.teal : Palette.muted)
            .padding(.horizontal, 12).padding(.vertical, 13)
            .background(destination == item ? Color.white : Color.clear, in: RoundedRectangle(cornerRadius: 10))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain).padding(.bottom, 4)
        .accessibilityAddTraits(destination == item ? .isSelected : [])
    }

    private var topbar: some View {
        HStack {
            Text(destination.rawValue).font(.system(size: 13, weight: .semibold))
            Spacer()
            HStack(spacing: 6) {
                Circle().fill(Color.orange).frame(width: 6, height: 6)
                Text(destination == .cleanup ? "Limpeza demonstrativa" : "Leitura local").font(.system(size: 11, weight: .medium))
            }
            .foregroundStyle(Palette.muted)
            .padding(.horizontal, 12).padding(.vertical, 7)
            .background(.white, in: Capsule())
        }
        .padding(.horizontal, 32).frame(height: 68)
        .overlay(alignment: .bottom) { Rectangle().fill(Palette.line).frame(height: 1) }
    }

    private var overview: some View {
        Group {
            heading("Menos excesso. Mais possibilidades.", subtitle: "Cuide do seu Mac e abra espaço para suas próximas ideias.")
            hero
            HStack(spacing: 16) {
                metric("Espaço recuperável", value: hasResults ? "12,4 GB" : "—", caption: hasResults ? "Em 3 categorias de exemplo" : "Faça uma análise de demonstração", symbol: "sparkles", color: Palette.teal)
                metric("Armazenamento disponível", value: mac.disk.map { bytes($0.available) } ?? "—", caption: mac.disk.map { "de " + bytes($0.total) } ?? "Consulte Armazenamento", symbol: "internaldrive", color: .blue, example: false)
                metric("Aplicativos", value: mac.inventory.map { String($0.apps.count) } ?? "—", caption: mac.loading ? "Lendo aplicativos…" : "Nas pastas de aplicativos", symbol: "square.stack.3d.up", color: .orange, example: false)
            }
            HStack(alignment: .center) {
                Text("Um lugar para cada cuidado").font(.system(size: 18, weight: .semibold))
                Spacer()
                Text("NO SEU RITMO").font(.system(size: 9, weight: .semibold)).tracking(1.5).foregroundStyle(Palette.muted)
            }
            HStack(spacing: 16) {
                feature("Uma limpeza com critério", detail: "Revise caches e arquivos temporários antes de decidir.", symbol: "sparkles", color: Palette.teal, target: .cleanup)
                feature("Seu espaço, à vista", detail: "Entenda o que ocupa o disco e encontre o que pode sair.", symbol: "chart.pie", color: .blue, target: .storage)
                feature("Cada app no seu lugar", detail: "Veja os aplicativos e organize o que você usa.", symbol: "square.stack.3d.up", color: .orange, target: .apps)
            }
        }
    }

    private var hero: some View {
        HStack(spacing: 24) {
            VStack(alignment: .leading, spacing: 14) {
                Text("UM NOVO RESPIRO PARA O SEU MAC").font(.system(size: 9, weight: .semibold)).tracking(1.8).foregroundStyle(Color.white.opacity(0.65))
                Text(isScanning ? "Encontrando espaço\npara o que vem aí." : hasResults ? "Um pouco de cuidado.\nMuito mais espaço." : "Seu próximo começo\ncabe aqui.")
                    .font(.system(size: 31, weight: .medium, design: .rounded)).tracking(-0.8).lineSpacing(1)
                    .fixedSize(horizontal: false, vertical: true)
                Text(isScanning ? "Simulando uma análise. Seus arquivos não são acessados." : "Uma visão simples do que pode deixar seu Mac mais leve.")
                    .font(.system(size: 12)).foregroundStyle(Color.white.opacity(0.7)).lineSpacing(3)
                HStack(spacing: 12) {
                    Button {
                        if isScanning { cancelScan() }
                        else if hasResults { destination = .cleanup }
                        else { startScan() }
                    } label: {
                        Label(isScanning ? "Cancelar" : hasResults ? "Revisar exemplos" : "Experimentar análise", systemImage: isScanning ? "xmark" : "arrow.right")
                            .font(.system(size: 12, weight: .semibold))
                            .padding(.horizontal, 18).padding(.vertical, 12)
                            .foregroundStyle(Palette.ink)
                            .background(Color(red: 0.83, green: 0.94, blue: 0.68), in: Capsule())
                    }.buttonStyle(.plain)
                    if isScanning { Text("\(Int(progress * 100))%").font(.system(size: 12, design: .monospaced)) }
                }.padding(.top, 7)
            }
            Spacer(minLength: 0)
            ZStack {
                Circle().stroke(.white.opacity(0.06), lineWidth: 1).frame(width: 236, height: 236)
                Circle().stroke(.white.opacity(0.08), lineWidth: 1).frame(width: 198, height: 198)
                Circle().trim(from: 0.08, to: isScanning ? max(0.09, progress) : 0.80)
                    .stroke(AngularGradient(colors: [.clear, Color(red: 0.62, green: 0.86, blue: 0.64), .white.opacity(0.9)], center: .center), style: StrokeStyle(lineWidth: 19, lineCap: .round))
                    .frame(width: 155, height: 155).rotationEffect(.degrees(-90))
                VStack(spacing: 8) {
                    Image(systemName: hasResults ? "checkmark" : "sparkles").font(.system(size: 29, weight: .light)).foregroundStyle(Color(red: 0.83, green: 0.94, blue: 0.68))
                    Text(isScanning ? "Analisando" : hasResults ? "Tudo à vista" : "Mais leve")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                }
            }.frame(width: 240, height: 240).accessibilityHidden(true)
        }
        .foregroundStyle(.white).padding(30)
        .frame(maxWidth: .infinity, minHeight: 290)
        .background(LinearGradient(colors: [Color(red: 0.10, green: 0.24, blue: 0.22), Color(red: 0.15, green: 0.34, blue: 0.28)], startPoint: .leading, endPoint: .bottomTrailing), in: RoundedRectangle(cornerRadius: 22))
    }

    private var cleanup: some View {
        Group {
            heading("Cada arquivo, uma escolha.", subtitle: "Revise as categorias e escolha o que faz sentido para você.")
            if !hasResults {
                hero
            } else {
                VStack(alignment: .leading, spacing: 0) {
                    HStack {
                        Text("Resultados de demonstração").font(.system(size: 17, weight: .semibold))
                        Spacer()
                        Button("Selecionar tudo") { selected = Set(categories.map(\.id)) }
                    }.padding(22)
                    ForEach(categories) { category in
                        Divider().overlay(Palette.line)
                        Toggle(isOn: Binding(get: { selected.contains(category.id) }, set: { value in
                            if value { selected.insert(category.id) } else { selected.remove(category.id) }
                        })) {
                            HStack(spacing: 15) {
                                icon(category.symbol, color: category.color)
                                VStack(alignment: .leading, spacing: 5) {
                                    Text(category.title).font(.system(size: 14, weight: .semibold))
                                    Text(category.subtitle).font(.system(size: 12)).foregroundStyle(Palette.muted)
                                }
                                Spacer()
                                Text(category.size).font(.system(size: 15, weight: .semibold, design: .rounded))
                            }
                        }.toggleStyle(.checkbox).padding(22)
                    }
                    Divider()
                    HStack {
                        Text("\(selected.count) categorias selecionadas").font(.system(size: 12)).foregroundStyle(Palette.muted)
                        Spacer()
                        Button("Simular limpeza") { showRemovalNotice = true }
                            .buttonStyle(.borderedProminent).disabled(selected.isEmpty)
                    }.padding(22)
                }.card()
                Button("Refazer demonstração") { startScan() }.buttonStyle(.link)
                if isScanning { ProgressView(value: progress).accessibilityLabel("Progresso da demonstração") }
            }
        }
    }

    private var storage: some View {
        Group {
            heading("Espaço para enxergar melhor.", subtitle: "Capacidade do volume que contém sua pasta pessoal, informada pelo macOS.")
            refreshBar
            if let disk = mac.disk {
                VStack(alignment: .leading, spacing: 24) {
                    HStack(alignment: .firstTextBaseline) {
                        Text(disk.name).font(.system(size: 20, weight: .semibold))
                        Spacer()
                        Text(bytes(disk.used)).font(.system(size: 27, weight: .medium, design: .rounded))
                        Text("usados de " + bytes(disk.total)).foregroundStyle(Palette.muted)
                    }
                    ProgressView(value: Double(disk.used), total: Double(disk.total))
                        .accessibilityLabel("Armazenamento usado")
                    HStack(spacing: 30) {
                        Label("Usado: " + bytes(disk.used), systemImage: "circle.fill").foregroundStyle(Palette.teal)
                        Label("Disponível: " + bytes(disk.available), systemImage: "circle")
                    }.font(.system(size: 13))
                    Text("O espaço disponível pode mudar. Volumes APFS compartilham capacidade; estes valores não representam uma classificação por tipo de arquivo nem uma estimativa de espaço recuperável.")
                        .font(.system(size: 12)).foregroundStyle(Palette.muted).lineSpacing(4)
                    Text("Lido em " + disk.observedAt.formatted(date: .abbreviated, time: .standard))
                        .font(.system(size: 11)).foregroundStyle(Palette.muted)
                }.padding(26).card()
            } else if let error = mac.diskError {
                notice("Armazenamento indisponível", detail: error)
            }
        }
    }

    private var applications: some View {
        Group {
            heading("Só o que faz parte do seu dia.", subtitle: "Aplicativos encontrados nas pastas do sistema e do usuário, incluindo subpastas como Utilitários.")
            refreshBar
            TextField("Buscar por nome ou caminho", text: $search)
                .textFieldStyle(.roundedBorder).frame(maxWidth: 360)
            if let inventory = mac.inventory {
                let filtered = inventory.apps.filter {
                    search.isEmpty || $0.name.localizedStandardContains(search) || $0.url.path.localizedStandardContains(search)
                }
                Text("\(filtered.count) de \(inventory.apps.count) aplicativos · " + inventory.observedAt.formatted(date: .omitted, time: .standard))
                    .font(.system(size: 12)).foregroundStyle(Palette.muted)
                if !inventory.issues.isEmpty {
                    notice("Inventário parcial", detail: inventory.issues.joined(separator: "\n"))
                }
                Text("Tamanhos lógicos dos arquivos do pacote. Não incluem dados externos do app e não indicam quanto espaço seria liberado; arquivos compartilhados podem ser contados mais de uma vez. Links simbólicos e arquivos ocultos na descoberta são ignorados. Apps fora das pastas pesquisadas não estão incluídos.")
                    .font(.system(size: 11)).foregroundStyle(Palette.muted).lineSpacing(3)
                if filtered.isEmpty {
                    if search.isEmpty {
                        ContentUnavailableView("Nenhum aplicativo encontrado", systemImage: "app.dashed", description: Text("Verifique os avisos de leitura e tente atualizar."))
                    } else { ContentUnavailableView.search(text: search) }
                } else {
                    LazyVStack(spacing: 0) {
                        ForEach(filtered) { app in
                            ApplicationRow(app: app, compact: compactNumbers) { inspectedApplication = app }
                            if app.id != filtered.last?.id { Divider() }
                        }
                    }.card()
                }
            } else if let error = mac.inventoryError {
                notice("Aplicativos indisponíveis", detail: error)
            }
        }
    }

    private var refreshBar: some View {
        HStack(spacing: 12) {
            if mac.loading {
                ProgressView().controlSize(.small)
                Text(mac.cancelling ? "Cancelando…" : mac.progress.map { $0.stage == .discovering ? "Localizando aplicativos…" : "Medindo \($0.currentName) · \($0.completed)/\($0.total)" } ?? "Lendo dados do Mac…")
                    .font(.system(size: 12)).foregroundStyle(Palette.muted).lineLimit(1)
            }
            if let progress = mac.progress, progress.stage == .measuring, progress.total > 0 {
                ProgressView(value: Double(progress.completed), total: Double(progress.total)).frame(width: 100)
                    .accessibilityLabel("Aplicativos medidos")
            }
            Spacer()
            if mac.loading { Button("Cancelar") { mac.cancel() }.disabled(mac.cancelling) }
            Button { Task { await mac.refresh() } } label: { Label("Atualizar", systemImage: "arrow.clockwise") }
                .disabled(mac.loading)
        }
    }

    private func notice(_ title: String, detail: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(title, systemImage: "exclamationmark.triangle").font(.system(size: 14, weight: .semibold))
            Text(detail).font(.system(size: 12)).textSelection(.enabled)
        }.foregroundStyle(Palette.muted).padding(20).frame(maxWidth: .infinity, alignment: .leading).card()
    }

    private func bytes(_ count: Int64) -> String {
        compactNumbers ? ByteCountFormatter.string(fromByteCount: count, countStyle: .file) : count.formatted() + " bytes"
    }

    private var history: some View {
        Group {
            heading("Cada cuidado fica registrado.", subtitle: "Histórico local de análises. Limpezas aparecerão aqui quando forem implementadas.")
            if let error = mac.history.error { notice("Histórico", detail: error) }
            if mac.history.records.isEmpty {
                ContentUnavailableView("Nenhuma análise registrada", systemImage: "clock", description: Text("Atualize os dados do Mac para registrar uma análise."))
            } else {
                LazyVStack(spacing: 0) {
                    ForEach(mac.history.records) { record in
                        HStack {
                            VStack(alignment: .leading, spacing: 6) {
                                Text(record.scope).font(.headline)
                                Text(record.date.formatted(date: .abbreviated, time: .standard)).font(.caption).foregroundStyle(Palette.muted)
                            }
                            Spacer()
                            VStack(alignment: .trailing, spacing: 6) {
                                Text(record.outcome)
                                if let count = record.itemCount { Text("\(count) itens").font(.caption).foregroundStyle(Palette.muted) }
                            }
                        }.padding(20)
                        Divider()
                    }
                }.card()
            }
        }
    }

    private var settings: some View {
        Group {
            heading("Do seu jeito.", subtitle: "Os primeiros ajustes do seu Limpador.")
            VStack(alignment: .leading, spacing: 22) {
                Label("Sobre esta versão", systemImage: "info.circle").font(.system(size: 17, weight: .semibold))
                Text("Limpador 0.1 · Swift + SwiftUI").font(.system(size: 13))
                Text("Armazenamento e aplicativos usam leituras reais do Mac. A limpeza de caches continua em demonstração, sem remover arquivos.").font(.system(size: 13)).foregroundStyle(Palette.muted).lineSpacing(5)
                Divider()
                Toggle("Mostrar tamanhos compactos", isOn: $compactNumbers)
                Toggle("Ler aplicativos ao abrir o Limpador", isOn: $scanOnLaunch)
                Text("Suas preferências são salvas neste Mac e restauradas ao abrir o aplicativo.")
                    .font(.system(size: 12, design: .monospaced)).foregroundStyle(Palette.muted)
            }.padding(26).card()
        }
    }

    private func heading(_ title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            Text(title).font(.system(size: 27, weight: .semibold, design: .rounded)).tracking(-0.8)
            Text(subtitle).font(.system(size: 13)).foregroundStyle(Palette.muted).lineSpacing(3)
        }
    }

    private func metric(_ title: String, value: String, caption: String, symbol: String, color: Color, example: Bool = true) -> some View {
        VStack(alignment: .leading, spacing: 13) {
            HStack {
                Image(systemName: symbol).foregroundStyle(color)
                Spacer()
                Text(example ? "EXEMPLO" : "LOCAL").font(.system(size: 8, weight: .medium)).tracking(0.8).foregroundStyle(Palette.muted)
            }
            Text(value).font(.system(size: 27, weight: .semibold, design: .rounded)).monospacedDigit()
            VStack(alignment: .leading, spacing: 5) {
                Text(title).font(.system(size: 12, weight: .semibold))
                Text(caption).font(.system(size: 10)).foregroundStyle(Palette.muted)
            }
        }.padding(20).frame(maxWidth: .infinity, alignment: .leading).card()
    }

    private func feature(_ title: String, detail: String, symbol: String, color: Color, target: Destination) -> some View {
        Button { destination = target } label: {
            VStack(alignment: .leading, spacing: 16) {
                HStack { icon(symbol, color: color); Spacer(); Image(systemName: "arrow.up.right").foregroundStyle(Palette.muted) }
                Text(title).font(.system(size: 13, weight: .semibold))
                Text(detail).font(.system(size: 11)).foregroundStyle(Palette.muted).lineSpacing(4).fixedSize(horizontal: false, vertical: true)
            }.padding(20).frame(maxWidth: .infinity, minHeight: 175, alignment: .topLeading).card().contentShape(Rectangle())
        }.buttonStyle(.plain)
    }

    private func icon(_ symbol: String, color: Color) -> some View {
        Image(systemName: symbol).font(.system(size: 19, weight: .medium))
            .foregroundStyle(color).frame(width: 42, height: 42)
            .background(color.opacity(0.09), in: RoundedRectangle(cornerRadius: 12))
    }

    private var demoFooter: some View {
        HStack(spacing: 6) {
            Image(systemName: "info.circle")
            Text("Armazenamento e aplicativos: dados locais · Limpeza: demonstração · Nenhum arquivo é removido")
        }.font(.system(size: 10)).foregroundStyle(Palette.muted).padding(.top, 2)
    }

    private func startScan() {
        guard scanTask == nil else { return }
        progress = 0
        hasResults = false
        scanTask = Task { @MainActor in
            for step in 1...30 {
                do { try await Task.sleep(for: .milliseconds(100)) }
                catch { return }
                guard !Task.isCancelled else { return }
                withAnimation(.easeInOut(duration: 0.15)) { progress = Double(step) / 30 }
            }
            hasResults = true
            scanTask = nil
        }
    }

    private func cancelScan() {
        scanTask?.cancel()
        scanTask = nil
        progress = 0
    }
}

private extension View {
    func card() -> some View {
        background(.white, in: RoundedRectangle(cornerRadius: 16))
            .overlay { RoundedRectangle(cornerRadius: 16).stroke(Palette.line, lineWidth: 1) }
    }
}
