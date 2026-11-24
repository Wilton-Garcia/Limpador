import SwiftUI

struct SystemMonitorView: View {
    @State private var model = SystemMonitor()
    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            Text("Seu Mac, agora.").font(.title.bold())
            Text("Leituras locais a cada 2 segundos enquanto esta tela está aberta.").foregroundStyle(.secondary)
            if let sample = model.sample {
                cpuCard
                if let memory = sample.memory { memoryCard(memory) }
                if let disk = sample.disk { diskCard(disk) }
                if let batteries = sample.batteries { batteryCard(batteries) }
                processCard(sample.processes)
                ForEach(sample.issues, id: \.self) { Text($0).font(.caption).foregroundStyle(.orange) }
                Text("Amostra: " + sample.date.formatted(date: .omitted, time: .standard)).font(.caption).foregroundStyle(.secondary)
            } else { ProgressView("Lendo métricas do sistema…") }
        }
        .task {
            while !Task.isCancelled {
                await model.refresh()
                do { try await Task.sleep(for: .seconds(2)) } catch { break }
            }
        }
    }

    private var cpuCard: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("CPU").font(.headline)
            Text(model.cpuFraction.map { $0.formatted(.percent.precision(.fractionLength(1))) } ?? "Aguardando a próxima amostra…").font(.largeTitle.monospacedDigit())
            if let fraction = model.cpuFraction { ProgressView(value: fraction) }
            Text("Uso agregado de todos os núcleos, calculado entre duas amostras.").font(.caption).foregroundStyle(.secondary)
        }.monitorCard()
    }

    private func memoryCard(_ memory: MemoryMetrics) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Memória física").font(.headline)
            LabeledContent("Instalada", value: bytes(memory.physical))
            LabeledContent("Ativa", value: bytes(memory.active))
            LabeledContent("Com fio (wired)", value: bytes(memory.wired))
            LabeledContent("Ocupada pelo compressor", value: bytes(memory.compressed))
            Text("Categorias informadas pelo kernel. Não representam uma estimativa de memória liberável.").font(.caption).foregroundStyle(.secondary)
        }.monitorCard()
    }

    private func diskCard(_ disk: DiskSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Armazenamento · " + disk.name).font(.headline)
            LabeledContent("Usado", value: bytes(UInt64(disk.used)))
            LabeledContent("Disponível", value: bytes(UInt64(disk.available)))
            ProgressView(value: Double(disk.used), total: Double(disk.total))
        }.monitorCard()
    }

    private func batteryCard(_ batteries: [BatteryMetric]) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Bateria").font(.headline)
            if batteries.isEmpty { Text("Nenhuma bateria interna anunciada pelo sistema.").font(.caption) }
            ForEach(batteries) { battery in
                LabeledContent(battery.name, value: battery.fraction.map { $0.formatted(.percent.precision(.fractionLength(0))) } ?? "Carga indisponível")
                LabeledContent("Carregando", value: battery.charging.map { $0 ? "Sim" : "Não" } ?? "Não informado")
                LabeledContent("Fonte", value: battery.source ?? "Não informada")
                LabeledContent("Condição reportada", value: battery.health ?? "Não informada")
                if let minutes = battery.minutesRemaining { Text("Autonomia estimada pelo sistema: \(minutes) min").font(.caption) }
            }
        }.monitorCard()
    }

    private func processCard(_ processes: [ProcessResource]) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Aplicativos em execução").font(.headline)
            Text("Processos principais anunciados pelo NSWorkspace. Não inclui todos os serviços nem soma processos auxiliares. CPU por núcleo: pode ultrapassar 100%. I/O é cumulativo desde o início do processo.").font(.caption).foregroundStyle(.secondary)
            ForEach(processes.sorted { ($0.residentBytes ?? 0) > ($1.residentBytes ?? 0) }) { process in
                processRow(process)
                Divider()
            }
        }.monitorCard()
    }

    private func processRow(_ process: ProcessResource) -> some View {
        let cpu = model.processCPU[process.id].map { $0.formatted(.percent.precision(.fractionLength(1))) } ?? "CPU —"
        let memory = process.residentBytes.map(bytes) ?? "Memória —"
        let read = process.readBytes.map(bytes) ?? "—"
        let written = process.writtenBytes.map(bytes) ?? "—"
        return VStack(alignment: .leading, spacing: 5) {
            HStack {
                Text(process.name)
                Text("PID \(process.pid)").font(.caption).foregroundStyle(.secondary)
                Spacer()
                Text(cpu)
                Text(memory)
            }
            if let issue = process.issue { Text(issue).font(.caption).foregroundStyle(.orange) }
            else { Text("Leitura: " + read + " · Escrita: " + written).font(.caption).foregroundStyle(.secondary) }
        }
    }

    private func bytes(_ value: UInt64) -> String { ByteCountFormatter.string(fromByteCount: Int64(value), countStyle: .memory) }
}

private extension View {
    func monitorCard() -> some View {
        padding(22).background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 16))
    }
}
