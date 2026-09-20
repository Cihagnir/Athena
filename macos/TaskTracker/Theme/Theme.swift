import AppKit
import SwiftUI

/// docs/DESIGN.md'nin koddaki tek karşılığı. Ekranlar renk, yazı tipi ve çizgi
/// kalınlığını yalnızca buradan alır; ton/ölçü ayarı bu dosyada yapılır.
enum Theme {
    // MARK: Palet — her modda 4 ton, başka renk yok

    static let paperNS = dynamic(light: 0xF2F0EA, dark: 0x0F0F0E)
    static let inkNS = dynamic(light: 0x111111, dark: 0xE6E3DB)
    static let ink2NS = dynamic(light: 0x5A5852, dark: 0x9A978E)
    static let ink3NS = dynamic(light: 0x8F8C84, dark: 0x6E6B64)

    static let paper = Color(nsColor: paperNS)
    static let ink = Color(nsColor: inkNS)
    static let ink2 = Color(nsColor: ink2NS)
    static let ink3 = Color(nsColor: ink3NS)

    // MARK: Tipografi — tek aile (sistem monospace), üç boyut, iki ağırlık

    enum Size {
        static let small: CGFloat = 11
        static let body: CGFloat = 13
        static let title: CGFloat = 17
    }

    static func font(_ size: CGFloat = Size.body, bold: Bool = false) -> Font {
        .system(size: size, weight: bold ? .bold : .regular, design: .monospaced)
    }

    static func nsFont(_ size: CGFloat = Size.body, bold: Bool = false) -> NSFont {
        .monospacedSystemFont(ofSize: size, weight: bold ? .bold : .regular)
    }

    // MARK: Çizgi

    static let hairline: CGFloat = 1
    /// "Klavyeyi dinliyor" / odak çerçevesi.
    static let focusLine: CGFloat = 2

    // MARK: Yüzen panel — temanın bilinçli istisnası (docs/DESIGN.md → Yüzen panel)

    /// Köşede sürekli duran panel yumuşak görünsün diye köşeleri yuvarlaktır.
    static let panelRadius: CGFloat = 10
    /// Pasifken (klavyeyi dinlemiyorken) arkasındaki içeriği hafifçe gösterir.
    static let panelPassiveOpacity = 0.7

    private static func dynamic(light: Int, dark: Int) -> NSColor {
        NSColor(name: nil) { appearance in
            let isDark = appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
            return NSColor(hex: isDark ? dark : light)
        }
    }
}

private extension NSColor {
    convenience init(hex: Int) {
        self.init(srgbRed: CGFloat((hex >> 16) & 0xFF) / 255,
                  green: CGFloat((hex >> 8) & 0xFF) / 255,
                  blue: CGFloat(hex & 0xFF) / 255,
                  alpha: 1)
    }
}

enum Appearance: String, CaseIterable {
    case system, light, dark

    var title: String {
        switch self {
        case .system: "sistem"
        case .light: "açık"
        case .dark: "koyu"
        }
    }

    func apply() {
        switch self {
        case .system: NSApp.appearance = nil
        case .light: NSApp.appearance = NSAppearance(named: .aqua)
        case .dark: NSApp.appearance = NSAppearance(named: .darkAqua)
        }
    }
}
