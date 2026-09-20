import SwiftUI

/// ⌘K komut paleti: kayıttaki her aksiyon adıyla aranır ve çalıştırılır → fareye
/// ya da kısayol ezberine gerek kalmadan %100 klavye kapsaması.
struct PaletteView: View {
    @Environment(AppState.self) private var app

    @State private var query = ""
    @State private var selection = 0

    private var results: [AppAction] { app.registry.search(query) }

    var body: some View {
        let results = results
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 12) {
                Text("⌘K").foregroundStyle(Theme.ink2)
                InkTextView(text: $query, focusTrigger: 1,
                            onSubmit: { run(results) }, onTab: {}, onCancel: close,
                            onMoveUp: { move(-1, in: results) }, onMoveDown: { move(1, in: results) })
                    .frame(height: 20)
            }
            .padding(.horizontal, 16).padding(.vertical, 12)
            Rectangle().fill(Theme.ink).frame(height: Theme.focusLine)

            ScrollViewReader { proxy in
                ScrollView {
                    VStack(spacing: 0) {
                        if results.isEmpty {
                            Text("eşleşen komut yok").foregroundStyle(Theme.ink3)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, 16).padding(.vertical, 8)
                        }
                        ForEach(Array(results.enumerated()), id: \.element.id) { index, action in
                            row(action, selected: index == selection)
                                .id(index)
                                .onTapGesture { selection = index; run(results) }
                        }
                    }
                    .padding(.vertical, 6)
                }
                .frame(maxHeight: 360)
                .onChange(of: selection) { _, index in proxy.scrollTo(index) }
            }

            InkRule()
            InkHints("↑↓ seç · ↵ çalıştır · esc kapat")
                .padding(.horizontal, 16).padding(.vertical, 8)
        }
        .frame(width: 560)
        .background(Theme.paper)
        .overlay(Rectangle().strokeBorder(Theme.ink, lineWidth: Theme.focusLine))
        .onChange(of: query) { selection = 0 }
    }

    private func row(_ action: AppAction, selected: Bool) -> some View {
        HStack(spacing: 12) {
            Text(action.title).lineLimit(1)
            Spacer(minLength: 12)
            Text(action.allKeysDisplay).foregroundStyle(selected ? Theme.paper : Theme.ink2)
        }
        .padding(.horizontal, 16).padding(.vertical, 3)
        .foregroundStyle(selected ? Theme.paper : Theme.ink)
        .background(selected ? Theme.ink : Theme.paper)
        .contentShape(Rectangle())
    }

    private func move(_ delta: Int, in results: [AppAction]) {
        guard !results.isEmpty else { return }
        selection = min(max(selection + delta, 0), results.count - 1)
    }

    private func run(_ results: [AppAction]) {
        guard results.indices.contains(selection) else { return }
        let action = results[selection]
        close()
        action.perform()
    }

    private func close() { app.overlay = nil }
}
