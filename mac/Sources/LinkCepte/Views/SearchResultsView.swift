import SwiftUI
import AppKit

struct SearchResultsView: View {
    @EnvironmentObject var m: Model

    var body: some View {
        if let hits = m.hits {
            if hits.isEmpty {
                Text(L("Sonuç bulunamadı.", "No results found."))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(hits) { h in hitRow(h) }
                    .listStyle(.inset)
            }
        } else {
            ProgressView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    @ViewBuilder
    private func hitRow(_ h: Hit) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: (h.isNote || h.entry.isTxt) ? "doc.text" : "link")
                .frame(width: 24)
                .padding(.top, 2)
            VStack(alignment: .leading, spacing: 2) {
                Text(h.path.isEmpty ? L("Ana liste", "Main list") : h.path.map { $0.name }.joined(separator: " › "))
                    .font(.system(size: max(m.fontSize - 2, 9)))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                Text(h.entry.title).font(.system(size: m.fontSize)).lineLimit(4)
                if !h.detail.isEmpty {
                    Text(h.detail)
                        .font(.system(size: max(m.fontSize - 1, 9)))
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }
            Spacer(minLength: 8)
            Button {
                m.exitSearch(true)
                m.setStack(h.path)
            } label: { Image(systemName: "folder") }
                .buttonStyle(.borderless)
                .help(L("Klasöre git", "Show in folder"))
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .onTapGesture { m.open(h.entry) }
    }
}
