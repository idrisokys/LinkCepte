import SwiftUI
import AppKit

struct AddBar: View {
    @EnvironmentObject var m: Model

    var body: some View {
        let canAdd = !m.linkText.trimmed.isEmpty
        VStack(alignment: .leading, spacing: 6) {
            ZStack(alignment: .topLeading) {
                TextEditor(text: $m.linkText)
                    .font(.system(size: m.fontSize))
                    .scrollContentBackground(.hidden)
                    .padding(4)
                    .onChange(of: m.linkText) { new in
                        // Enter gönderir (Shift+Enter yeni satır). Yapıştırma birden fazla karakter ekler, etkilenmez.
                        if new.hasSuffix("\n"), new.count == m.prevLinkCount + 1, !NSEvent.modifierFlags.contains(.shift) {
                            m.linkText = String(new.dropLast())
                            m.addFromText()
                        }
                        m.prevLinkCount = m.linkText.count
                    }
                if m.linkText.isEmpty {
                    Text(L("Link veya metin yapıştır (Enter: kaydet)", "Paste a link or text (Enter: save)"))
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

            HStack(spacing: 10) {
                Text("\(m.linkText.count)/\(m.addMax)")
                    .font(.caption)
                    .foregroundStyle(m.linkText.count > m.addMax ? Color.red : Color.secondary)
                Spacer()
                Image(systemName: "plus")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 30, height: 30)
                    .background(Circle().fill(Color.accentColor.opacity(canAdd ? 0.95 : 0.3)))
                    .contentShape(Circle())
                    .help(L("Ekle (uzun basın veya ⌥ ile tıklayın: .txt)", "Add (long-press or ⌥-click: .txt)"))
                    .onTapGesture {
                        guard canAdd else { return }
                        if NSEvent.modifierFlags.contains(.option) { m.addTxt() } else { m.addFromText() }
                    }
                    .onLongPressGesture(minimumDuration: 0.5) {
                        if canAdd { m.addTxt() }
                    }
                Button { m.startSearch() } label: { Image(systemName: "magnifyingglass") }
                    .disabled(!canAdd)
                    .help(L("Ara", "Search"))
                Button { m.paste() } label: { Image(systemName: "doc.on.clipboard") }
                    .help(L("Yapıştır", "Paste"))
                FontSizeButtons()
            }
        }
        .padding(8)
        .background(.bar)
    }
}
