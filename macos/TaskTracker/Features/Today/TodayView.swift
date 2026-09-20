import SwiftUI
import TaskTrackerCore

/// Odak ekranı. Tasarım: tuvaldeki "Ana pencere: Odak" panosu.
/// Klavye: tuşlar `ActionRegistry`'nin `.todayList` bağlamından çözülür.
struct TodayView: View {
    @Environment(AppState.self) private var app
    @FocusState private var listFocused: Bool

    var body: some View {
        let store = app.today
        VStack(spacing: 0) {
            header(store)
            Rectangle().fill(Theme.ink).frame(height: Theme.hairline)
            newTaskHint
            InkRule()
            list(store)
            InkRule()
            InkHints("↑↓ gezin · ↵ aktif yap · D tamamla · Y yarına · 1–4 öncelik · ⇥ alan")
                .padding(.horizontal, 32).padding(.vertical, 8)
        }
        .focusable()
        .focusEffectDisabled()
        .focused($listFocused)
        .onKeyPress(phases: .down) { app.registry.handle($0, in: .todayList) }
        .onAppear { listFocused = true }
    }

    private func header(_ store: TodayStore) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                Text(store.today.isEmpty ? "BUGÜN" : "BUGÜN · " + Day.label(store.today))
                    .font(Theme.font(Theme.Size.title, bold: true))
                Spacer()
                HStack(spacing: 12) {
                    filterLabel("hepsi", selected: store.areaFilter == nil)
                    filterLabel("iş", selected: store.areaFilter == .work)
                    filterLabel("kş", selected: store.areaFilter == .personal)
                }
            }
            HStack(spacing: 12) {
                InkBar(fraction: store.progress)
                Text("\(store.done.count)/\(store.done.count + store.open.count)").foregroundStyle(Theme.ink2)
            }
        }
        .padding(.horizontal, 32).padding(.top, 44).padding(.bottom, 12)
    }

    @ViewBuilder private func filterLabel(_ text: String, selected: Bool) -> some View {
        if selected { InkTag(text) } else { Text(text).foregroundStyle(Theme.ink2) }
    }

    private var newTaskHint: some View {
        Button { app.quickAdd.show() } label: {
            HStack(spacing: 12) {
                Text("+")
                Text("yeni task… yarın son:cuma !1 #proje @iş // açıklama")
                Spacer()
                Text("⌘N").font(Theme.font(Theme.Size.small))
            }
            .foregroundStyle(Theme.ink3)
            .padding(.horizontal, 32).padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .focusable(false)
    }

    private func list(_ store: TodayStore) -> some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if store.hasLoaded && store.ordered.isEmpty {
                        Text("bugün için task yok").foregroundStyle(Theme.ink3).padding(.horizontal, 32)
                    }
                    section("GECİKEN", store.overdue, store)
                    section("BUGÜN", store.current, store)
                    section("BİTEN", store.done, store)
                }
                .padding(.vertical, 16)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .onChange(of: store.selectedID) { _, id in
                if let id { proxy.scrollTo(id) }
            }
        }
    }

    @ViewBuilder private func section(_ title: String, _ tasks: [TaskItem], _ store: TodayStore) -> some View {
        if !tasks.isEmpty {
            VStack(alignment: .leading, spacing: 0) {
                InkSectionLabel("\(title) · \(tasks.count)").padding(.horizontal, 32).padding(.bottom, 4)
                ForEach(tasks) { task in
                    TaskRow(task: task, today: store.today,
                            projectName: app.projects.name(for: task.project),
                            isSelected: task.id == store.selectedID,
                            isActive: task.id == app.active.taskID)
                        .id(task.id)
                        .onTapGesture { store.selectedID = task.id }
                }
            }
        }
    }
}

/// Tek task satırı — anlam sözlüğü (docs/DESIGN.md) burada uygulanır.
struct TaskRow: View {
    let task: TaskItem
    let today: String
    let projectName: String?
    let isSelected: Bool
    let isActive: Bool

    private var statusGlyph: String {
        switch task.status {
        case .todo: "[ ]"
        case .doing: "[~]"
        case .blocked: "[!]"
        case .done: "[x]"
        }
    }

    /// Seçili satır tümüyle ters çevrilir; alt öğeler kendi tonlarını bırakır.
    private func tone(_ normal: Color) -> Color {
        if isSelected { return Theme.paper }
        return task.isDone ? Theme.ink3 : normal
    }

    var body: some View {
        HStack(spacing: 12) {
            Text(isActive ? "▸" : " ")
            Text(statusGlyph)
            Text(task.priority < 4 ? "!\(task.priority)" : "  ")
                .font(Theme.font(bold: task.priority == 1))
                .foregroundStyle(tone(task.priority == 3 ? Theme.ink2 : Theme.ink))
            HStack(spacing: 8) {
                Text(task.title).strikethrough(task.isDone).lineLimit(1)
                if task.hasDetails { Text("≡").foregroundStyle(tone(Theme.ink2)) }
            }
            Spacer(minLength: 12)
            if !task.isDone {
                if !task.dueDate.isEmpty { dateLabel("son " + Day.short(task.dueDate), inverted: task.dueDate <= today) }
                if let projectName { Text("#" + projectName).foregroundStyle(tone(Theme.ink2)).lineLimit(1) }
                if let area = task.area { Text(area == .work ? "iş" : "kş").foregroundStyle(tone(Theme.ink2)) }
                if task.scheduledDate < today { dateLabel(Day.short(task.scheduledDate), inverted: true) }
            }
        }
        .foregroundStyle(tone(Theme.ink))
        .padding(.horizontal, 32)
        .padding(.vertical, 4)
        .background(isSelected ? Theme.ink : Theme.paper)
        .contentShape(Rectangle())
    }

    /// Ters etiket; satır zaten ters çevrilmişse (seçili) etiket kâğıt rengine döner.
    @ViewBuilder private func dateLabel(_ text: String, inverted: Bool) -> some View {
        if inverted {
            Text(text).padding(.horizontal, 4)
                .foregroundStyle(isSelected ? Theme.ink : Theme.paper)
                .background(isSelected ? Theme.paper : Theme.ink)
        } else {
            Text(text).foregroundStyle(tone(Theme.ink2))
        }
    }
}
