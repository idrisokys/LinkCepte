import SwiftUI
import AppKit

struct NoteSheet: View {
    @EnvironmentObject var m: Model

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            ScrollView {
                Text(m.noteText)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(minHeight: 80, idealHeight: 240, maxHeight: 360)
            HStack {
                Button(L("Kopyala", "Copy")) {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(m.noteText, forType: .string)
                    HUD.show(L("Kopyalandı", "Copied"))
                }
                Spacer()
                Button(L("Kapat", "Close")) { m.sheet = nil }
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .frame(width: 460)
    }
}
