import SwiftUI
import TaskTrackerCore

/// Tasarım: docs/DESIGN.md + tuvaldeki "Hızlı ekleme" panosu.
struct QuickAddView: View {
    @Bindable var model: QuickAddController

    var body: some View {
        VStack(spacing: 0) {
            if let flash = model.flashTitle {
                Text("[ ] \(flash)")
                    .font(Theme.font(Theme.Size.title))
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                    .foregroundStyle(Theme.paper)
                    .background(Theme.ink)
            } else {
                content
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                    .background(Theme.paper)
            }
        }
        .overlay(Rectangle().strokeBorder(Theme.ink, lineWidth: Theme.focusLine))
        .frame(width: QuickAddController.width)
        .frame(maxHeight: .infinity, alignment: .top)
        .font(Theme.font())
        .foregroundStyle(Theme.ink)
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: 8) {
            InkTextView(text: $model.text, fontSize: Theme.Size.title, tokens: model.preview?.tokens ?? [],
                        focusTrigger: model.titleFocus,
                        onSubmit: model.submit, onTab: model.switchField, onCancel: model.hide)
                .frame(height: 24)
            Rectangle().fill(model.field == .title ? Theme.ink : Theme.ink3)
                .frame(height: model.field == .title ? Theme.focusLine : Theme.hairline)

            if model.showsDetails {
                HStack(alignment: .top, spacing: 12) {
                    Text("≡").foregroundStyle(Theme.ink2)
                    InkTextView(text: $model.details, multiline: true, focusTrigger: model.detailsFocus,
                                onSubmit: model.submit, onTab: model.switchField, onCancel: model.hide)
                        .frame(height: 72)
                }
                Rectangle().fill(model.field == .details ? Theme.ink : Theme.ink3)
                    .frame(height: model.field == .details ? Theme.focusLine : Theme.hairline)
            }

            if let preview = model.preview { PreviewLines(preview: preview) }
            if let error = model.error { Text("? \(error)") }

            InkRule()
            HStack {
                InkHints(model.field == .title
                    ? "↵ ekle, kutu açık kalır · ⇥ açıklama alanı"
                    : "↵ ekle · ⇧↵ yeni satır · ⇥ başlığa dön")
                Text("esc kapat").font(Theme.font(Theme.Size.small)).foregroundStyle(Theme.ink2)
            }
        }
    }
}

private struct PreviewLines: View {
    let preview: ParsedInput

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 12) {
                Text("→").foregroundStyle(Theme.ink2)
                Text(preview.title.isEmpty ? "başlık yok" : preview.title)
                    .foregroundStyle(preview.valid ? Theme.ink : Theme.ink3)
                    .lineLimit(1)
                if preview.description != nil { Text("≡").foregroundStyle(Theme.ink2) }
            }
            HStack(spacing: 12) {
                Text(" ")
                Text("başla " + startLabel)
                if let due = preview.dueDate { Text("son " + Day.label(due)) }
                if let priority = preview.priority {
                    Text("!\(priority)").font(Theme.font(bold: priority == 1)).foregroundStyle(Theme.ink)
                }
                if let project = preview.project { Text("#" + project.name) }
                if let area = preview.area { Text(area == .work ? "iş" : "kş") }
            }
            .foregroundStyle(Theme.ink2)
            .lineLimit(1)

            ForEach(preview.warnings, id: \.self) { warning in
                Text("   ? " + Self.message(for: warning))
            }
        }
    }

    /// Sunucunun varsayılan kuralı (docs/api.md): tarihsiz + projesiz → bugün.
    private var startLabel: String {
        if let date = preview.scheduledDate { return Day.label(date) }
        return preview.project == nil ? "bugün" : "plansız"
    }

    private static func message(for warning: String) -> String {
        switch warning {
        case "project_not_found": "proje bulunamadı, başlıkta kalacak"
        case "due_before_scheduled": "bitiş, başlamadan önce"
        default: warning
        }
    }
}
