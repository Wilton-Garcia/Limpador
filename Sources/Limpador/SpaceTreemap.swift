import SwiftUI

struct SpaceMapTile: Identifiable, Sendable {
    enum ID: Hashable, Sendable { case node(String), remainder }
    let id: ID
    let title: String
    let bytes: Int64
    let nodeIDs: [String]
    static func make(_ nodes: [SpaceLensNode], limit: Int = 64) -> [Self] {
        let nonempty = nodes.filter { $0.bytes > 0 }.sorted { $0.bytes == $1.bytes ? $0.id < $1.id : $0.bytes > $1.bytes }
        let directCount = nonempty.count > max(2, limit) ? max(2, limit) - 1 : nonempty.count
        var result = nonempty.prefix(directCount).map { Self(id: .node($0.id), title: $0.name, bytes: $0.bytes, nodeIDs: [$0.id]) }
        let remainder = Array(nonempty.dropFirst(directCount))
        if !remainder.isEmpty {
            result.append(Self(id: .remainder, title: "Outros \(remainder.count) itens", bytes: remainder.reduce(0) { $0 + $1.bytes }, nodeIDs: remainder.map(\.id)))
        }
        return result
    }
}

struct TreemapPlacement: Identifiable {
    let tile: SpaceMapTile
    let rect: CGRect
    var id: SpaceMapTile.ID { tile.id }
}

enum SpaceTreemapLayout {
    static func layout(_ tiles: [SpaceMapTile], in rect: CGRect) -> [TreemapPlacement] {
        guard rect.width > 0, rect.height > 0, rect.width.isFinite, rect.height.isFinite else { return [] }
        let positive = tiles.filter { $0.bytes > 0 }
        var output: [TreemapPlacement] = []
        func split(_ items: ArraySlice<SpaceMapTile>, _ bounds: CGRect) {
            guard !items.isEmpty else { return }
            if items.count == 1 { output.append(TreemapPlacement(tile: items.first!, rect: bounds)); return }
            let total = items.reduce(0.0) { $0 + Double($1.bytes) }
            var cumulative = 0.0, bestDistance = Double.infinity
            var pivot = items.index(after: items.startIndex), leftWeight = Double(items.first!.bytes)
            for index in items.indices.dropLast() {
                cumulative += Double(items[index].bytes)
                let distance = abs(total / 2 - cumulative)
                if distance < bestDistance { bestDistance = distance; pivot = items.index(after: index); leftWeight = cumulative }
            }
            let fraction = leftWeight / total
            if bounds.width >= bounds.height {
                let width = bounds.width * fraction
                split(items[..<pivot], CGRect(x: bounds.minX, y: bounds.minY, width: width, height: bounds.height))
                split(items[pivot...], CGRect(x: bounds.minX + width, y: bounds.minY, width: bounds.width - width, height: bounds.height))
            } else {
                let height = bounds.height * fraction
                split(items[..<pivot], CGRect(x: bounds.minX, y: bounds.minY, width: bounds.width, height: height))
                split(items[pivot...], CGRect(x: bounds.minX, y: bounds.minY + height, width: bounds.width, height: bounds.height - height))
            }
        }
        split(positive[...], rect)
        return output
    }
}

struct SpaceTreemap: View {
    let tiles: [SpaceMapTile]
    let selected: String?
    let select: (SpaceMapTile) -> Void
    let open: (SpaceMapTile) -> Void
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .topLeading) {
                Color(nsColor: .underPageBackgroundColor)
                ForEach(SpaceTreemapLayout.layout(tiles, in: CGRect(origin: .zero, size: geometry.size))) { placement in
                    let rect = placement.rect.insetBy(dx: min(1.5, placement.rect.width / 4), dy: min(1.5, placement.rect.height / 4))
                    Button { select(placement.tile) } label: {
                        ZStack(alignment: .topLeading) {
                            RoundedRectangle(cornerRadius: 6).fill(color(for: placement.tile))
                            if rect.width > 70 && rect.height > 40 {
                                VStack(alignment: .leading, spacing: 5) {
                                    Text(placement.tile.title).font(.system(size: rect.width > 170 ? 14 : 11, weight: .semibold)).lineLimit(2)
                                    if rect.height > 65 { Text(ByteCountFormatter.string(fromByteCount: placement.tile.bytes, countStyle: .file)).font(.system(size: 11)).opacity(0.85) }
                                }.padding(10).foregroundStyle(.white)
                            }
                        }.frame(width: max(0, rect.width), height: max(0, rect.height)).clipped()
                            .overlay { if case .node(let id) = placement.tile.id, id == selected { RoundedRectangle(cornerRadius: 6).stroke(.white, lineWidth: 3).padding(2) } }
                    }
                    .buttonStyle(.plain)
                    .simultaneousGesture(TapGesture(count: 2).onEnded { open(placement.tile) })
                    .help(placement.tile.title + " · " + ByteCountFormatter.string(fromByteCount: placement.tile.bytes, countStyle: .file))
                    .accessibilityLabel(placement.tile.title + ", " + ByteCountFormatter.string(fromByteCount: placement.tile.bytes, countStyle: .file))
                    .position(x: rect.midX, y: rect.midY)
                }
            }.clipShape(RoundedRectangle(cornerRadius: 12))
        }.frame(height: 390)
    }
    private func color(for tile: SpaceMapTile) -> Color {
        if case .remainder = tile.id { return Color(red: 0.35, green: 0.39, blue: 0.43) }
        let seed = tile.title.utf8.reduce(UInt64(5381)) { ($0 &* 33) &+ UInt64($1) }
        let hues: [Double] = [0.45, 0.53, 0.60, 0.68, 0.35, 0.08, 0.82]
        return Color(hue: hues[Int(seed % UInt64(hues.count))], saturation: 0.55, brightness: 0.58)
    }
}
