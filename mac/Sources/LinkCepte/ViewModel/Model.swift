import SwiftUI
import AppKit

@MainActor
final class Model: ObservableObject {
    static let shared = Model()

    @Published var root: URL? = Store.root
    @Published var stack: [Entry] = []
    @Published var loaded: [Entry]? = nil
    @Published var editMode = false { didSet { syncRename() } }
    @Published var selected: Set<String> = [] { didSet { syncRename() } }
    @Published var linkText = ""
    @Published var searchQuery: String? = nil
    @Published var hits: [Hit]? = nil
    @Published var sheet: Sheet? = nil
    @Published var noteText = ""
    @Published var moving: [Entry] = []
    @Published var renaming: Entry? = nil      // düzenleme modunda tek öğe seçiliyse o öğe (adı altta değiştirilir)
    @Published var renameText = ""
    // Tam pencerede açık .txt dosyası
    @Published var txt: Entry? = nil
    @Published var txtSaved = ""               // dosyadaki son hâl
    @Published var txtDraft = ""               // düzenlenen metin
    @Published var txtEditing = false
    @Published var txtAskDiscard = false
    @Published var txtSaving = false
    var txtDirty: Bool { txtEditing && txtDraft != txtSaved }

    // Yazı boyutu (punto): liste, arama sonuçları, alt alanlar ve .txt görünümü bunu kullanır; kalıcıdır.
    static let minFont = 10.0, maxFont = 32.0, defaultFont = 13.0
    @Published var fontSize: Double = Model.loadFontSize() {
        didSet { UserDefaults.standard.set(fontSize, forKey: "fontSize") }
    }
    private static func loadFontSize() -> Double {
        let v = UserDefaults.standard.double(forKey: "fontSize")
        return v == 0 ? defaultFont : min(max(v, minFont), maxFont)
    }
    func bumpFont(_ delta: Double) { fontSize = min(max(fontSize + delta, Model.minFont), Model.maxFont) }

    let maxChars = 220   // ad değiştirme sınırı
    let addMax = 220     // alttaki ekleme alanı sınırı
    var prevLinkCount = 0   // Enter ile gönderimi algılamak için önceki uzunluk

    /// Tüm dosya işlemleri sıralı yapılır.
    private let queue = DispatchQueue(label: "linkcepte.io")

    // Arama / sıra değiştirme
    private(set) lazy var reorderInput = ReorderInput(model: self)
    var searchFlag: CancelFlag?
    /// Son taşınan satır: liste bu satırı görünür tutmak için kaydırılır.
    @Published var revealKey: String? = nil
    @Published var revealTick = 0

    var current: URL? { stack.last?.url ?? root }
    var list: [Entry] { loaded ?? [] }

    var title: String {
        if let q = searchQuery { return "“\(q)”" + (hits.map { " · \($0.count) \(L("sonuç", "results"))" } ?? "") }
        if editMode && !selected.isEmpty { return "\(selected.count) \(L("seçili", "selected"))" }
        return stack.last?.name ?? "Link Cepte"
    }

    func io<T>(_ block: @escaping () -> T) async -> T {
        await withCheckedContinuation { c in
            queue.async { c.resume(returning: block()) }
        }
    }

    func toast(_ s: String) { HUD.show(s) }

    /// Düzenleme modunda tam bir öğe seçiliyse adı alttaki alanda değiştirilir.
    private func syncRename() {
        let e: Entry? = (editMode && selected.count == 1) ? list.first(where: { selected.contains($0.key) }) : nil
        if e?.key != renaming?.key {
            renaming = e
            renameText = e?.title ?? ""
        }
    }
}
