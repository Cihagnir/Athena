import SwiftUI

/// Task düzenleme katmanı: Odak, Hafta ve Kanban'da detay açıkken `E`.
/// `⇥` / `⇧⇥` alanlar arasında gezer, `↵` kaydeder (açıklamada `⇧↵` yeni satır), `esc` vazgeçer.
struct TaskEditorView: View {
    @Environment(AppState.self) private var app

    var body: some View {
        let model = app.taskEditor
        VStack(alignment: .leading, spacing: 0) {
            Text("TASK'I DÜZENLE").font(Theme.font(bold: true)).padding(.horizontal, 16).padding(.vertical, 12)
            Rectangle().fill(Theme.ink).frame(height: Theme.hairline)

            VStack(alignment: .leading, spacing: 10) {
                ForEach(TaskEditorModel.Field.allCases, id: \.self) { field in row(field, model) }
            }
            .padding(.horizontal, 16).padding(.vertical, 14)

            InkRule()
            InkHints(model.isSaving ? "kaydediliyor…" : "⇥ sonraki alan · ⇧⇥ önceki · ↵ kaydet · açıklamada ⇧↵ yeni satır · esc vazgeç")
                .padding(.horizontal, 16).padding(.vertical, 8)
        }
        .frame(width: 640)
        .background(Theme.paper)
        .overlay(Rectangle().strokeBorder(Theme.ink, lineWidth: Theme.focusLine))
    }

    private func row(_ field: TaskEditorModel.Field, _ model: TaskEditorModel) -> some View {
        let active = model.field == field
        let isDetails = field == .details
        let binding = Binding(get: { model.text(field) }, set: { model.setText(field, $0) })
        return HStack(alignment: .top, spacing: 12) {
            Text(field.label).foregroundStyle(active ? Theme.ink : Theme.ink2).frame(width: 72, alignment: .leading)
            VStack(alignment: .leading, spacing: 3) {
                ZStack(alignment: .topLeading) {
                    if model.text(field).isEmpty { Text(field.placeholder).foregroundStyle(Theme.ink3) }
                    InkTextView(text: binding, multiline: isDetails, focusTrigger: active ? model.focusTick : 0,
                                onFocus: { model.didFocus(field) }, onSubmit: model.save, onTab: { model.move(1) }, onBackTab: { model.move(-1) }, onCancel: model.cancel)
                        .frame(height: isDetails ? 100 : 20)
                }
                Rectangle().fill(active ? Theme.ink : Theme.ink3).frame(height: active ? Theme.focusLine : Theme.hairline)
                if let error = model.errors[field] {
                    Text("? " + error)
                } else if let resolution = model.resolution(field) {
                    Text(resolution).foregroundStyle(Theme.ink2)
                }
            }
        }
    }
}
