import SwiftUI
import TaskTrackerCore

/// Gün sonu triyajı. Tasarım: tuvaldeki "Ana pencere: Triyaj" panosu.
/// Tamamen klavyeyle: `1`–`4` karar · `D` tamamlandı · `␣` atla · `esc` çık.
struct TriageView: View {
    @Environment(AppState.self) private var app

    var body: some View {
        let store = app.triage
        VStack(spacing: 0) {
            header(store)
            Rectangle().fill(Theme.ink).frame(height: Theme.hairline)
            Group {
                if let task = store.current {
                    card(task, store)
                } else if store.hasLoaded {
                    finished(store)
                }
            }
            .frame(maxWidth: 640, alignment: .leading)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            InkRule()
            InkHints(hints(store.mode)).padding(.horizontal, 32).padding(.vertical, 8)
        }
        // Metin yazılırken klavye alanın kendisindedir; aksi halde bu görünümde.
        .keyboardFocus(unless: app.overlay != nil || store.isTyping)
        .onKeyPress(phases: .down) { app.registry.handle($0, in: .triage) }
        .task { await store.start() }
    }

    private func header(_ store: TriageStore) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text("TRİYAJ · gün sonu").font(Theme.font(Theme.Size.title, bold: true))
            Spacer()
            if store.total > 0 {
                InkBar(fraction: Double(store.handled) / Double(store.total), cells: min(store.total, 20))
                Text("\(store.handled)/\(store.total)").foregroundStyle(Theme.ink2)
            }
        }
        .padding(.horizontal, 32).padding(.top, 44).padding(.bottom, 12)
    }

    private func card(_ task: TaskItem, _ store: TriageStore) -> some View {
        VStack(alignment: .leading, spacing: 28) {
            VStack(alignment: .leading, spacing: 8) {
                Text(task.title).font(Theme.font(Theme.Size.title, bold: true)).fixedSize(horizontal: false, vertical: true)
                HStack(spacing: 12) {
                    if task.priority < 4 { Text("!\(task.priority)").foregroundStyle(Theme.ink) }
                    if let area = task.area { Text(area == .work ? "iş" : "kş") }
                    Text(app.projects.name(for: task.project).map { "#" + $0 } ?? "projesiz")
                    if task.scheduledDate < store.today {
                        InkTag(Day.short(task.scheduledDate))
                        Text(overdueText(task.scheduledDate, store.today))
                    } else {
                        Text("bugün")
                    }
                    if !task.dueDate.isEmpty { Text("son " + Day.short(task.dueDate)) }
                }
                .foregroundStyle(Theme.ink2)
                if task.hasDetails {
                    Text(task.details).lineLimit(4).foregroundStyle(Theme.ink2).fixedSize(horizontal: false, vertical: true)
                }
            }

            switch store.mode {
            case .choose: options(store)
            case .date: dateEntry(store)
            case .project: projectEntry(store)
            case .confirmDelete:
                Text("Silinsin mi?  ↵ evet · esc hayır").padding(.vertical, 8)
            }

            if !store.upcoming.isEmpty {
                VStack(alignment: .leading, spacing: 2) {
                    InkSectionLabel("SIRADA")
                    ForEach(store.upcoming) { Text("[ ] " + $0.title).lineLimit(1) }
                }
                .foregroundStyle(Theme.ink3)
            }
        }
        .padding(.horizontal, 32)
    }

    private func options(_ store: TriageStore) -> some View {
        VStack(spacing: 0) {
            InkRule()
            option("1", "yarına at", "")
            option("2", "tarih seç", "cuma · 25.09 · …")
            option("3", "projeye taşı", "günlük akıştan çıkar")
            option("4", "sil", "")
        }
    }

    private func option(_ key: String, _ title: String, _ note: String) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: 16) {
                Text(key).padding(.horizontal, 6).overlay(Rectangle().strokeBorder(Theme.ink, lineWidth: Theme.hairline))
                Text(title)
                Spacer()
                Text(note).foregroundStyle(Theme.ink2)
            }
            .padding(.vertical, 8)
            InkRule()
        }
    }

    private func dateEntry(_ store: TriageStore) -> some View {
        @Bindable var store = store
        return VStack(alignment: .leading, spacing: 8) {
            InkSectionLabel("TARİH — yarın · cuma · pzt · 25.09 · 25.09.2027")
            InkTextView(text: $store.dateInput, focusTrigger: 1, onSubmit: store.confirmDate, onCancel: store.cancel)
                .frame(height: 20)
            Rectangle().fill(Theme.ink).frame(height: Theme.focusLine)
            if let date = store.resolvedDate {
                Text("→ " + Day.label(date))
            } else if !store.dateInput.isEmpty {
                Text("? tarih anlaşılmadı").foregroundStyle(Theme.ink2)
            }
        }
    }

    private func projectEntry(_ store: TriageStore) -> some View {
        @Bindable var store = store
        let choices = store.projectChoices
        return VStack(alignment: .leading, spacing: 8) {
            InkSectionLabel("PROJE — yazarak süz; listede yoksa yenisi oluşturulur")
            InkTextView(text: $store.projectQuery, focusTrigger: 1, onSubmit: store.confirmProject, onCancel: store.cancel,
                        onMoveUp: { store.moveProjectSelection(-1) }, onMoveDown: { store.moveProjectSelection(1) })
                .frame(height: 20)
            Rectangle().fill(Theme.ink).frame(height: Theme.focusLine)
            VStack(spacing: 0) {
                if choices.isEmpty { Text("henüz proje yok — bir ad yaz").foregroundStyle(Theme.ink3).frame(maxWidth: .infinity, alignment: .leading) }
                ForEach(Array(choices.prefix(8).enumerated()), id: \.element.id) { index, choice in
                    let selected = index == store.projectSelection
                    HStack {
                        Text(choice.project == nil ? "+ yeni proje: " + choice.name : "#" + choice.name)
                        Spacer()
                        if let area = choice.project?.area { Text(area == .work ? "iş" : "kş") }
                    }
                    .padding(.horizontal, 8).padding(.vertical, 3)
                    .foregroundStyle(selected ? Theme.paper : Theme.ink)
                    .background(selected ? Theme.ink : Theme.paper)
                }
            }
        }
    }

    private func finished(_ store: TriageStore) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(store.total == 0 ? "triyaj edilecek task yok" : "triyaj bitti").font(Theme.font(Theme.Size.title, bold: true))
            if store.total > 0 {
                Text("\(store.handled) karar · \(store.skipped) atlandı").foregroundStyle(Theme.ink2)
            }
        }
        .padding(.horizontal, 32)
    }

    private func overdueText(_ date: String, _ today: String) -> String {
        let format = Date.ISO8601FormatStyle().year().month().day()
        guard let from = try? Date(date, strategy: format), let to = try? Date(today, strategy: format) else { return "gecikti" }
        return "\(Int(to.timeIntervalSince(from) / 86400)) gün gecikti"
    }

    private func hints(_ mode: TriageStore.Mode) -> String {
        switch mode {
        case .choose: "1–4 karar ver · D tamamlandı say · ␣ atla · esc çık"
        case .date: "↵ onayla · esc vazgeç"
        case .project: "↑↓ seç · ↵ taşı · esc vazgeç"
        case .confirmDelete: "↵ sil · esc vazgeç"
        }
    }
}
