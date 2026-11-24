import Foundation

struct FileQuery {
    enum Order: String, CaseIterable { case name = "Nome", largest = "Maior tamanho", newest = "Mais recentes", oldest = "Mais antigos" }
    var search = ""
    var category = "Todas"
    var order: Order = .name
    var minimumBytes: Int64 = 0

    func apply(to files: [AnalyzedFile]) -> [AnalyzedFile] {
        files.filter {
            $0.bytes >= minimumBytes && (search.isEmpty || $0.path.localizedStandardContains(search)) && (category == "Todas" || $0.category == category)
        }.sorted { left, right in
            switch order {
            case .largest where left.bytes != right.bytes: return left.bytes > right.bytes
            case .newest, .oldest:
                if left.modifiedAt != right.modifiedAt {
                    guard let leftDate = left.modifiedAt else { return false }
                    guard let rightDate = right.modifiedAt else { return true }
                    return order == .newest ? leftDate > rightDate : leftDate < rightDate
                }
            default: break
            }
            return left.path.localizedStandardCompare(right.path) == .orderedAscending
        }
    }
}
