import SwiftUI

/// `?` — o anki ekrana özel kısayol listesi. İçerik `ActionRegistry`'den gelir:
/// önce görünümün kendi bağlamı, sonra her yerde geçerli olanlar.
struct HelpView: View {
    @Environment(AppState.self) private var app
    @FocusState private var focused: Bool

    private var contexts: [ActionContext] {
        [app.route.context, .anyView, .mainWindow, .global].compactMap { $0 }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("KISAYOLLAR · \(app.route.title)").font(Theme.font(bold: true))
                .padding(.horizontal, 16).padding(.vertical, 12)
            Rectangle().fill(Theme.ink).frame(height: Theme.hairline)

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    ForEach(contexts, id: \.self) { context in
                        VStack(alignment: .leading, spacing: 2) {
                            InkSectionLabel(context.title).padding(.bottom, 2)
                            ForEach(app.registry.actions(in: context)) { action in
                                HStack(spacing: 12) {
                                    Text(action.allKeysDisplay).frame(width: 150, alignment: .leading)
                                    Text(action.title).foregroundStyle(Theme.ink2).lineLimit(1)
                                }
                            }
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 16).padding(.vertical, 12)
            }
            .frame(maxHeight: 460)

            InkRule()
            InkHints("? ya da esc kapat · ⌘K ile hepsini ara · ⌘, ile kısayol ata")
                .padding(.horizontal, 16).padding(.vertical, 8)
        }
        .frame(width: 560)
        .background(Theme.paper)
        .overlay(Rectangle().strokeBorder(Theme.ink, lineWidth: Theme.focusLine))
        // Açıkken klavyeyi devralır: alttaki liste tuşlara tepki vermez.
        .focusable()
        .focusEffectDisabled()
        .focused($focused)
        .onAppear { focused = true }
        .onKeyPress(phases: .down) { press in
            if press.key == .escape || press.key.character == "?" { app.overlay = nil }
            return .handled
        }
    }
}
