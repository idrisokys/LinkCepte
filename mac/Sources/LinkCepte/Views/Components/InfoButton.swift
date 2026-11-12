import SwiftUI
import AppKit

/// Araç çubuğunun en sağındaki bilgi (i) ikonu: gemi resmi, e-posta ve GitHub adresini gösteren küçük menü açar.
struct InfoButton: View {
    @State private var shown = false

    var body: some View {
        Button { shown.toggle() } label: { Image(systemName: "info.circle") }
            .help(L("Bilgi", "Info"))
            .popover(isPresented: $shown, arrowEdge: .bottom) {
                VStack(spacing: 4) {
                    if let img = NSImage(named: "releases_icon") {
                        Image(nsImage: img).resizable().scaledToFill()
                            .frame(width: 36, height: 36).clipShape(Circle())
                    }
                    Text(AppInfo.contactEmail).textSelection(.enabled)
                    Link(AppInfo.githubURL.absoluteString, destination: AppInfo.githubURL)
                }
                .font(.system(size: 11))
                .padding(8)
            }
    }
}
