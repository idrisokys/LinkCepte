import Foundation

/// Arama sonucu: bulunan öğe, bulunduğu klasör zinciri ve gösterilecek özet.
struct Hit: Identifiable {
    let entry: Entry
    let path: [Entry]
    let detail: String
    let isNote: Bool
    let titleMatch: Bool
    var id: String { entry.key }
}
