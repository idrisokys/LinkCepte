import SwiftUI
import AppKit

struct RenameBar: View {
    @EnvironmentObject var m: Model

    var body: some View {
        VStack(spacing: 6) {
            // Ekleme alanıyla aynı boyutta: satır seçilince alt çubuk küçülmez
            ZStack(alignment: .topLeading) {
                TextEditor(text: $m.renameText)
                    .font(.system(size: m.fontSize))
                    .scrollContentBackground(.hidden)
                    .padding(4)
                if m.renameText.isEmpty {
                    Text(m.renaming?.isDir == true ? L("Klasör adı", "Folder name") : L("Ad", "Name"))
                        .font(.system(size: m.fontSize))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 12)
                        .allowsHitTesting(false)
                }
            }
            .frame(minHeight: 56, maxHeight: 140)
            .background(RoundedRectangle(cornerRadius: 8).fill(Color(nsColor: .textBackgroundColor)))
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.secondary.opacity(0.35)))
            .onChange(of: m.renameText) { v in
                // Ad tek satırdır: satır sonları boşluğa çevrilir, uzunluk sınırlanır
                var t = v.replacingOccurrences(of: "\n", with: " ")
                if t.count > m.maxChars { t = String(t.prefix(m.maxChars)) }
                if t != v { m.renameText = t }
            }
            HStack(spacing: 10) {
                Text("\(m.renameText.count)/\(m.maxChars)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Button { m.pasteIntoRename() } label: { Image(systemName: "doc.on.clipboard") }
                    .help(L("Yapıştır", "Paste"))
                Button { m.saveRename() } label: { Image(systemName: "square.and.arrow.down") }
                    .keyboardShortcut("s", modifiers: .command)
                    .disabled(m.renameText.trimmed.isEmpty)
                    .help(L("Kaydet (⌘S)", "Save (⌘S)"))
                FontSizeButtons()
            }
            .frame(height: 30)   // ekleme çubuğundaki düğme satırıyla aynı yükseklik
        }
        .padding(8)
        .background(.bar)
    }
}
