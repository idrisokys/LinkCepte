import SwiftUI
import AppKit

extension Model {
    // MARK: - Metin dosyası (.txt) tam pencere görünümü

    func openTxt(_ e: Entry, _ text: String) {
        txt = e
        txtSaved = text
        txtDraft = text
        txtEditing = false
        txtAskDiscard = false
        txtSaving = false
    }

    func txtStartEdit() {
        guard txt != nil, !txtEditing else { return }
        txtDraft = txtSaved
        txtEditing = true
    }

    /// Kaydeder ve okuma görünümüne döner.
    func txtSave() {
        guard let e = txt, !txtSaving else { return }
        let t = txtDraft
        txtSaving = true
        Task {
            let ok = await self.io { Store.writePlain(e.url, t) }
            self.txtSaving = false
            if ok {
                if self.txt?.key == e.key { self.txtSaved = t; self.txtEditing = false; self.txtAskDiscard = false }
            } else {
                self.toast(L("Kaydedilemedi", "Couldn't save"))
            }
        }
    }

    func txtDiscard() {
        txtDraft = txtSaved
        txtEditing = false
        txtAskDiscard = false
    }

    /// Geri: kaydedilmemiş değişiklik varsa sorar; düzenliyorsa okumaya döner; değilse listeye çıkar.
    func txtBack() {
        if txtDirty { txtAskDiscard = true }
        else if txtEditing { txtEditing = false }
        else { txt = nil }
    }
}
