import SwiftUI
import AppKit

/// .txt dosyasını tüm pencerede gösterir. Sağ üstteki kalemle düzenlenir, kaydet simgesiyle kaydedilip okumaya dönülür.
struct TxtView: View {
    @EnvironmentObject var m: Model
    @FocusState private var focused: Bool

    var body: some View {
        Group {
            if m.txtEditing {
                TextEditor(text: $m.txtDraft)
                    .font(.system(size: m.fontSize))
                    .scrollContentBackground(.hidden)
                    .padding(12)
                    .focused($focused)
                    .onAppear { DispatchQueue.main.async { focused = true } }
            } else {
                ScrollView {
                    Text(m.txtSaved)
                        .font(.system(size: m.fontSize))
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(16)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(nsColor: .textBackgroundColor))
        .navigationTitle(m.txt?.title ?? "")
        .toolbar {
            ToolbarItemGroup(placement: .navigation) {
                Button { m.txtBack() } label: { Image(systemName: "chevron.left") }
                    .help(L("Geri", "Back"))
            }
            ToolbarItemGroup(placement: .primaryAction) {
                if m.txtEditing {
                    Button { m.txtSave() } label: { Image(systemName: "square.and.arrow.down") }
                        .keyboardShortcut("s", modifiers: .command)
                        .disabled(m.txtSaving)
                        .help(L("Kaydet (⌘S)", "Save (⌘S)"))
                } else {
                    Button {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(m.txtSaved, forType: .string)
                        HUD.show(L("Kopyalandı", "Copied"))
                    } label: { Image(systemName: "doc.on.doc") }
                        .help(L("Kopyala", "Copy"))
                    Button { m.txtStartEdit() } label: { Image(systemName: "pencil") }
                        .help(L("Düzenle (⌘E)", "Edit (⌘E)"))
                }
            }
        }
        .alert(L("Kaydedilmemiş değişiklikler var", "Unsaved changes"), isPresented: $m.txtAskDiscard) {
            Button(L("Kaydet", "Save")) { m.txtSave() }
            Button(L("Kaydetme", "Discard"), role: .destructive) { m.txtDiscard() }
            Button(L("İptal", "Cancel"), role: .cancel) { }
        } message: {
            Text(L("Değişiklikleri kaydetmek ister misiniz?", "Do you want to save your changes?"))
        }
    }
}
