import SwiftUI
import AppKit

extension Model {
    // MARK: - Arama

    func startSearch() {
        let q = linkText.trimmed
        guard !q.isEmpty else { return }
        NSApp.keyWindow?.makeFirstResponder(nil)
        editMode = false
        selected = []
        runSearch(q)
    }

    func runSearch(_ q: String) {
        guard let rootURL = root else { return }
        searchFlag?.cancel()
        let flag = CancelFlag()
        searchFlag = flag
        searchQuery = q
        hits = nil
        Task { [weak self] in
            // Ağır tarama arka planda; sonuç ana aktörde (Model @MainActor) yazılır.
            let r = await Task.detached(priority: .userInitiated) {
                Store.search(root: rootURL, query: q, alive: { !flag.isCancelled })
            }.value
            if !flag.isCancelled { self?.hits = r }
        }
    }

    func exitSearch(_ clearText: Bool) {
        searchFlag?.cancel()
        if clearText && linkText.trimmed == searchQuery { linkText = "" }
        searchQuery = nil
        hits = nil
    }
}
