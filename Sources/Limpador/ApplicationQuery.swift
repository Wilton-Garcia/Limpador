import Foundation

struct ApplicationQuery {
    enum Order: String, CaseIterable { case name = "Nome", largest = "Maior tamanho", smallest = "Menor tamanho" }
    var search = ""
    var order: Order = .name
    func apply(to apps: [InstalledApplication]) -> [InstalledApplication] {
        apps.filter { search.isEmpty || $0.name.localizedStandardContains(search) || $0.url.path.localizedStandardContains(search) }
            .sorted { left, right in
                if order != .name, left.size.bytes != right.size.bytes { return order == .largest ? left.size.bytes > right.size.bytes : left.size.bytes < right.size.bytes }
                let comparison = left.name.localizedStandardCompare(right.name)
                return comparison == .orderedSame ? left.id < right.id : comparison == .orderedAscending
            }
    }
}
