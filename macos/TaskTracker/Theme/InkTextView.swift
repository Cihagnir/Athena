import AppKit
import SwiftUI
import TaskTrackerCore

/// Hızlı eklemenin metin alanı. SwiftUI `TextField` aralık bazında biçim
/// veremediği için `NSTextView` sarılır: API'den gelen token aralıkları (UTF-16
/// ofsetleri = `NSRange`) doğrudan alt çizgiye dönüşür.
///
/// Tuşlar burada yakalanır: ↵ gönder · ⇧↵ yeni satır (çok satırlıda) · ⇥ alan
/// değiştir · esc kapat. Hızlı ekleme, hızlı not, palet, triyaj, proje ve not
/// editörleri aynı bileşeni kullanır.
struct InkTextView: NSViewRepresentable {
    @Binding var text: String
    var fontSize = Theme.Size.body
    var multiline = false
    /// `false`: ↵ yeni satır açar (uzun metin editörleri); `true`: ↵ gönderir, ⇧↵ yeni satır.
    var submitsOnReturn = true
    var tokens: [ParsedInput.Token] = []
    /// Değeri her değiştiğinde alan klavye odağını alır; `0` = odak isteme
    /// (aynı ekranda birden çok alan varken yalnızca etkin olan odaklansın diye).
    var focusTrigger = 0
    /// Alan odağı aldığında (ör. fareyle tıklanınca) çağrılır.
    var onFocus: (() -> Void)?
    var onSubmit: () -> Void = {}
    var onTab: () -> Void = {}
    /// `⇧⇥`; verilmezse `onTab` çağrılır.
    var onBackTab: (() -> Void)?
    var onCancel: () -> Void = {}
    /// Verilirse ↑/↓ imleci oynatmak yerine bunları çağırır (komut paleti listesi için).
    var onMoveUp: (() -> Void)?
    var onMoveDown: (() -> Void)?

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeNSView(context: Context) -> NSScrollView {
        let textView = FocusReportingTextView()
        textView.onFocus = { [weak coordinator = context.coordinator] in coordinator?.parent.onFocus?() }
        textView.delegate = context.coordinator
        textView.isRichText = false
        textView.allowsUndo = true
        textView.drawsBackground = false
        textView.textContainerInset = .zero
        textView.textContainer?.lineFragmentPadding = 0
        textView.insertionPointColor = Theme.inkNS
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.isAutomaticSpellingCorrectionEnabled = false
        textView.isContinuousSpellCheckingEnabled = false
        textView.autoresizingMask = [.width]
        textView.isVerticallyResizable = true

        if !multiline {
            // Tek satır: sarmak yerine yatayda kayar.
            textView.isHorizontallyResizable = true
            textView.textContainer?.widthTracksTextView = false
            textView.textContainer?.containerSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
            textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        }

        let scroll = NSScrollView()
        scroll.documentView = textView
        scroll.drawsBackground = false
        scroll.hasVerticalScroller = false
        scroll.hasHorizontalScroller = false
        scroll.borderType = .noBorder
        context.coordinator.textView = textView
        return scroll
    }

    func updateNSView(_ scroll: NSScrollView, context: Context) {
        let coordinator = context.coordinator
        coordinator.parent = self
        guard let textView = coordinator.textView else { return }

        if textView.string != text { textView.string = text }
        applyStyle(to: textView)

        if coordinator.lastFocusTrigger != focusTrigger {
            coordinator.lastFocusTrigger = focusTrigger
            if focusTrigger != 0 { DispatchQueue.main.async { textView.window?.makeFirstResponder(textView) } }
        }
    }

    private func applyStyle(to textView: NSTextView) {
        guard let storage = textView.textStorage else { return }
        let base: [NSAttributedString.Key: Any] = [.font: Theme.nsFont(fontSize), .foregroundColor: Theme.inkNS]
        textView.typingAttributes = base

        storage.beginEditing()
        storage.setAttributes(base, range: NSRange(location: 0, length: storage.length))
        for token in tokens where token.range.upperBound <= storage.length {
            switch token.kind {
            case .description:
                storage.addAttribute(.foregroundColor, value: Theme.ink2NS, range: token.range)
            case .project where !token.resolved:
                let dotted = NSUnderlineStyle.single.rawValue | NSUnderlineStyle.patternDot.rawValue
                storage.addAttribute(.underlineStyle, value: dotted, range: token.range)
            default:
                storage.addAttribute(.underlineStyle, value: NSUnderlineStyle.single.rawValue, range: token.range)
            }
        }
        storage.endEditing()
    }

    private final class FocusReportingTextView: NSTextView {
        var onFocus: (() -> Void)?

        override func becomeFirstResponder() -> Bool {
            let became = super.becomeFirstResponder()
            if became { onFocus?() }
            return became
        }
    }

    final class Coordinator: NSObject, NSTextViewDelegate {
        var parent: InkTextView
        weak var textView: NSTextView?
        var lastFocusTrigger = -1

        init(_ parent: InkTextView) { self.parent = parent }

        func textDidChange(_ notification: Notification) {
            guard let textView else { return }
            parent.text = textView.string
        }

        func textView(_ textView: NSTextView, doCommandBy selector: Selector) -> Bool {
            switch selector {
            case #selector(NSResponder.insertNewline(_:)):
                let shift = NSApp.currentEvent?.modifierFlags.contains(.shift) ?? false
                if parent.multiline && (shift || !parent.submitsOnReturn) {
                    textView.insertNewlineIgnoringFieldEditor(nil)
                } else {
                    parent.onSubmit()
                }
                return true
            case #selector(NSResponder.insertTab(_:)):
                parent.onTab()
                return true
            case #selector(NSResponder.insertBacktab(_:)):
                (parent.onBackTab ?? parent.onTab)()
                return true
            case #selector(NSResponder.cancelOperation(_:)):
                parent.onCancel()
                return true
            case #selector(NSResponder.moveUp(_:)):
                guard let move = parent.onMoveUp else { return false }
                move()
                return true
            case #selector(NSResponder.moveDown(_:)):
                guard let move = parent.onMoveDown else { return false }
                move()
                return true
            default:
                return false
            }
        }
    }
}
