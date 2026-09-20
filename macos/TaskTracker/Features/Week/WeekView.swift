import SwiftUI
import TaskTrackerCore

/// Hafta görünümü: üstte 7 günün yük şeridi, altında gün gün ajanda.
/// Yan yana 7 sütun yerine ajanda seçildi — monospace'te dar pencerede de okunur.
struct WeekScreen: View {
    @Environment(AppState.self) private var app

    var body: some View {
        let store = app.week
        VStack(spacing: 0) {
            header(store)
            Rectangle().fill(Theme.ink).frame(height: Theme.hairline)
            agenda(store)
            InkRule()
            InkHints("↑↓ gezin · ← → günü taşı · B bugüne al · D tamamla · E detay · ↵ aktif · , . hafta · 0 bu hafta")
                .padding(.horizontal, 32).padding(.vertical, 8)
        }
        .keyboardFocus(unless: app.overlay != nil)
        .onKeyPress(phases: .down) { app.registry.handle($0, in: .week) }
        .task { await store.reload() }
    }

    private func header(_ store: WeekStore) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text(title(store)).font(Theme.font(Theme.Size.title, bold: true))
                Spacer()
                if !store.isCurrentWeek { Text("0 bu haftaya dön").foregroundStyle(Theme.ink2) }
            }
            if let week = store.week {
                // Yük şeridi: haftaya tek bakış. Çubuk uzunluğu haftanın en yoğun gününe göre.
                HStack(alignment: .top, spacing: 0) {
                    ForEach(week.days) { day in
                        VStack(alignment: .leading, spacing: 2) {
                            if day.date == week.today { InkTag(Day.weekdayFirst(day.date)) } else { Text(Day.weekdayFirst(day.date)) }
                            HStack(spacing: 6) {
                                InkBar(fraction: Double(day.openCount) / Double(store.peakLoad), cells: 6)
                                Text("\(day.openCount)").foregroundStyle(day.openCount == 0 ? Theme.ink3 : Theme.ink)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .font(Theme.font(Theme.Size.small))
            }
        }
        .padding(.horizontal, 32).padding(.top, 44).padding(.bottom, 12)
    }

    private func title(_ store: WeekStore) -> String {
        guard let week = store.week else { return "HAFTA" }
        return "HAFTA · \(Day.short(week.start)) – \(Day.short(week.end))"
    }

    private func agenda(_ store: WeekStore) -> some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if let week = store.week {
                        if !week.overdue.isEmpty {
                            section(label: "GECİKEN · \(week.overdue.count)", isToday: false, tasks: week.overdue, store)
                        }
                        ForEach(week.days) { day in
                            section(label: dayLabel(day, today: week.today), isToday: day.date == week.today, tasks: day.tasks, store)
                        }
                    }
                }
                .padding(.vertical, 16)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .onChange(of: store.selectedID) { _, id in if let id { proxy.scrollTo(id) } }
        }
    }

    private func dayLabel(_ day: WeekView.DayColumn, today: String) -> String {
        var label = Day.weekdayFirst(day.date).uppercased(with: Locale(identifier: "tr"))
        if day.date == today { label += " · BUGÜN" }
        if day.openCount > 0 { label += " · \(day.openCount)" }
        if day.doneCount > 0 { label += " · \(day.doneCount) bitti" }
        return label
    }

    private func section(label: String, isToday: Bool, tasks: [TaskItem], _ store: WeekStore) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(label).font(Theme.font(Theme.Size.small, bold: isToday))
                .foregroundStyle(isToday ? Theme.ink : Theme.ink2)
                .padding(.horizontal, 32).padding(.bottom, 4)
            if tasks.isEmpty {
                Text("—").foregroundStyle(Theme.ink3).padding(.horizontal, 32)
            }
            ForEach(tasks) { task in
                TaskRow(task: task, today: store.today, projectName: app.projects.name(for: task.project),
                        isSelected: task.id == store.selectedID, isActive: task.id == app.active.taskID)
                    .id(task.id)
                    .onTapGesture(count: 2) { store.selectedID = task.id; store.toggleDetails() }
                    .onTapGesture { store.selectedID = task.id }
                if store.showsDetails && task.id == store.selectedID {
                    TaskDetails(task: task, today: store.today, projectName: app.projects.name(for: task.project))
                }
            }
        }
    }
}
