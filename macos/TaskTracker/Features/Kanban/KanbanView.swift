import SwiftUI
import TaskTrackerCore

/// Kanban: durum başına bir sütun. Klavye: oklar gezinir, ⇧← / ⇧→ kartı taşır;
/// fareyle sürükle-bırak da çalışır.
struct KanbanView: View {
    @Environment(AppState.self) private var app

    var body: some View {
        let store = app.kanban
        VStack(spacing: 0) {
            HStack(alignment: .firstTextBaseline) {
                Text("KANBAN").font(Theme.font(Theme.Size.title, bold: true))
                Spacer()
                Text("açık task'ların tümü · bitenlerden yalnızca bugünküler").foregroundStyle(Theme.ink2)
            }
            .padding(.horizontal, 32).padding(.top, 44).padding(.bottom, 12)
            Rectangle().fill(Theme.ink).frame(height: Theme.hairline)

            HStack(alignment: .top, spacing: 0) {
                ForEach(Array(KanbanStore.columns.enumerated()), id: \.element) { index, status in
                    if index > 0 { Rectangle().fill(Theme.ink3).frame(width: Theme.hairline) }
                    column(status, store)
                }
            }
            .frame(maxHeight: .infinity)

            InkRule()
            InkHints("↑↓ ← → gezin · ⇧← ⇧→ durumu taşı · D tamamla · E detay / düzenle · ↵ aktif · sürükle-bırak")
                .padding(.horizontal, 32).padding(.vertical, 8)
        }
        .keyboardFocus(unless: app.overlay != nil)
        .onKeyPress(phases: .down) { app.registry.handle($0, in: .kanban) }
        .task { await store.reload() }
    }

    private func column(_ status: TaskStatus, _ store: KanbanStore) -> some View {
        let tasks = store.tasks(in: status)
        return VStack(alignment: .leading, spacing: 0) {
            Text("\(Self.title(status)) · \(tasks.count)").font(Theme.font(bold: true))
                .padding(.horizontal, 16).padding(.vertical, 10)
            InkRule()
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(spacing: 0) {
                        ForEach(tasks) { task in
                            card(task, store).id(task.id)
                            InkRule()
                        }
                    }
                }
                .onChange(of: store.selectedID) { _, id in if let id { proxy.scrollTo(id) } }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .contentShape(Rectangle())
        .dropDestination(for: String.self) { ids, _ in
            guard let id = ids.first else { return false }
            store.setStatus(status, for: id)
            return true
        }
    }

    private func card(_ task: TaskItem, _ store: KanbanStore) -> some View {
        let selected = task.id == store.selectedID
        let secondary = selected ? Theme.paper : task.isDone ? Theme.ink3 : Theme.ink2
        return VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                if task.id == app.active.taskID { Text("▸") }
                if task.priority < 4 { Text("!\(task.priority)").font(Theme.font(bold: task.priority == 1)) }
                Text(task.title).strikethrough(task.isDone).lineLimit(2).fixedSize(horizontal: false, vertical: true)
            }
            HStack(spacing: 8) {
                if let name = app.projects.name(for: task.project) { Text("#" + name).lineLimit(1) }
                if !task.isDone && !task.scheduledDate.isEmpty {
                    if task.scheduledDate < store.today {
                        Text(Day.short(task.scheduledDate)).padding(.horizontal, 4)
                            .foregroundStyle(selected ? Theme.ink : Theme.paper).background(selected ? Theme.paper : Theme.ink)
                    } else {
                        Text(task.scheduledDate == store.today ? "bugün" : Day.short(task.scheduledDate))
                    }
                }
                if !task.isDone && !task.dueDate.isEmpty { Text("son " + Day.short(task.dueDate)) }
                if task.hasDetails { Text("≡") }
            }
            .font(Theme.font(Theme.Size.small))
            .foregroundStyle(secondary)

            if store.showsDetails && selected && task.hasDetails {
                Text(task.details).font(Theme.font(Theme.Size.small)).fixedSize(horizontal: false, vertical: true).padding(.top, 4)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 16).padding(.vertical, 8)
        .foregroundStyle(selected ? Theme.paper : task.isDone ? Theme.ink3 : Theme.ink)
        .background(selected ? Theme.ink : Theme.paper)
        .contentShape(Rectangle())
        .onTapGesture(count: 2) { store.selectedID = task.id; store.toggleDetails() }
        .onTapGesture { store.selectedID = task.id }
        .draggable(task.id)
    }

    private static func title(_ status: TaskStatus) -> String {
        switch status {
        case .todo: "[ ] YAPILACAK"
        case .doing: "[~] YAPILIYOR"
        case .blocked: "[!] ENGELLİ"
        case .done: "[x] BİTTİ"
        }
    }
}
