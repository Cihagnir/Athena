import SwiftUI

// Ekranların paylaştığı küçük yapı taşları. Yeni bir görsel öğe gerektiğinde önce
// buraya bak; yoksa buraya ekle — ekranlar kendi renk/çizgi kararını vermez.

/// Ters çevrilmiş etiket: gecikmiş tarih, bitişi gelmiş task, seçili filtre.
struct InkTag: View {
    let text: String

    init(_ text: String) { self.text = text }

    var body: some View {
        Text(text)
            .padding(.horizontal, 4)
            .foregroundStyle(Theme.paper)
            .background(Theme.ink)
    }
}

/// Blok karakterli ilerleme / zamanlayıcı çubuğu: ████░░░░
struct InkBar: View {
    let fraction: Double
    var cells = 40

    var body: some View {
        let filled = Int((Double(cells) * min(max(fraction, 0), 1)).rounded())
        Text(String(repeating: "█", count: filled) + String(repeating: "░", count: cells - filled))
            .lineLimit(1)
            .fixedSize()
    }
}

struct InkRule: View {
    var color = Theme.ink3

    var body: some View {
        Rectangle().fill(color).frame(height: Theme.hairline)
    }
}

/// Ekran altındaki tek satırlık kısayol ipuçları.
struct InkHints: View {
    let text: String

    init(_ text: String) { self.text = text }

    var body: some View {
        Text(text)
            .font(Theme.font(Theme.Size.small))
            .foregroundStyle(Theme.ink2)
            .lineLimit(1)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// Bölüm başlığı: GECİKEN · 2
struct InkSectionLabel: View {
    let text: String

    init(_ text: String) { self.text = text }

    var body: some View {
        Text(text)
            .font(Theme.font(Theme.Size.small))
            .foregroundStyle(Theme.ink2)
    }
}

/// Metin buton: çerçeveli, basılıyken ters çevrilir.
struct InkButtonStyle: ButtonStyle {
    var selected = false

    func makeBody(configuration: Configuration) -> some View {
        let inverted = selected || configuration.isPressed
        configuration.label
            .font(Theme.font())
            .padding(.horizontal, 6)
            .foregroundStyle(inverted ? Theme.paper : Theme.ink)
            .background(inverted ? Theme.ink : Theme.paper)
            .overlay(Rectangle().strokeBorder(Theme.ink, lineWidth: Theme.hairline))
            .contentShape(Rectangle())
    }
}

/// Çerçevesiz giriş alanı: altında tek çizgi; odaktayken çizgi kalınlaşır.
struct InkField: View {
    let label: String
    @Binding var text: String
    var secure = false
    var onSubmit: () -> Void = {}

    @FocusState private var focused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            InkSectionLabel(label)
            Group {
                if secure {
                    SecureField("", text: $text)
                } else {
                    TextField("", text: $text)
                }
            }
            .textFieldStyle(.plain)
            .font(Theme.font())
            .foregroundStyle(Theme.ink)
            .focused($focused)
            .onSubmit(onSubmit)
            Rectangle()
                .fill(Theme.ink)
                .frame(height: focused ? Theme.focusLine : Theme.hairline)
                .padding(.bottom, focused ? 0 : Theme.focusLine - Theme.hairline)
        }
    }
}
