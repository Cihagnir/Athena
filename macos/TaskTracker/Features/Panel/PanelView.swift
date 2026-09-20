import SwiftUI
import TaskTrackerCore

/// Yüzen panelin içeriği. Tasarım: tuvaldeki "Mini panel: 6 hal" ve "Liste paneli".
struct PanelView: View {
    @Environment(AppState.self) private var app
    @FocusState private var focused: Bool

    var body: some View {
        let panel = app.panel
        let shape = RoundedRectangle(cornerRadius: Theme.panelRadius, style: .continuous)
        Group {
            switch panel.mode {
            case .mini: MiniPanelContent()
            case .list: ListPanelContent()
            }
        }
        .frame(width: PanelController.width)
        .background(Theme.paper)
        .clipShape(shape)
        .overlay(shape.strokeBorder(Theme.ink, lineWidth: panel.isListening ? Theme.focusLine : Theme.hairline))
        // Dinlerken tam opak; pasifken saydamlaşır. Geçiş anlıktır (animasyon yok).
        .opacity(panel.isListening ? 1 : Theme.panelPassiveOpacity)
        .onGeometryChange(for: CGFloat.self, of: \.size.height) { panel.contentHeight = $0 }
        .frame(maxHeight: .infinity, alignment: panel.anchorsTop ? .top : .bottom)
        .font(Theme.font())
        .foregroundStyle(Theme.ink)
        .focusable()
        .focusEffectDisabled()
        .focused($focused)
        .onAppear { focused = true }
        .onChange(of: panel.isListening) { _, listening in if listening { focused = true } }
        .onKeyPress(phases: .down) { press in
            if panel.handleTimerInput(press) { return .handled }
            let context: ActionContext = panel.mode == .mini ? .miniPanel : .listPanel
            if app.registry.handle(press, in: context) == .handled { return .handled }
            // Liste paneli, Odak listesinin aksiyonlarını (D, Y, 1–4, ⇥, ↑↓) aynen kullanır.
            return panel.mode == .list ? app.registry.handle(press, in: .todayList) : .ignored
        }
    }
}

private struct MiniPanelContent: View {
    @Environment(AppState.self) private var app

    /// 13 pt monospace'te panelin iç genişliğine sığan hücre sayısı.
    private static let barCells = 37

    var body: some View {
        let panel = app.panel
        VStack(alignment: .leading, spacing: 6) {
            if let task = app.active.current?.task {
                title(task.title)
                timerBar
                if let input = panel.timerInput { timerInput(input) }
                if panel.isExpanded { details(task) }
                if panel.isListening && panel.timerInput == nil {
                    InkHints(panel.isExpanded ? "D tamamla · T süre · esc daralt" : "E detay · T süre · D tamamla · ␣ seç · H gizle")
                }
            } else {
                Text("sıradaki ne?").font(Theme.font(Theme.Size.title)).foregroundStyle(Theme.ink3)
                if panel.isListening { InkHints("␣ task seç · H gizle · esc bırak") }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12).padding(.vertical, 10)
    }

    /// Tek satıra sığıyorsa 17 bold; sığmıyorsa 13 bold, en çok iki satır.
    private func title(_ text: String) -> some View {
        ViewThatFits(in: .horizontal) {
            Text(text).font(Theme.font(Theme.Size.title, bold: true)).lineLimit(1).fixedSize()
            Text(text).font(Theme.font(bold: true)).lineLimit(app.panel.isExpanded ? nil : 2)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    /// Rakam yok; çubuk hücre hücre (kademeli) azalır.
    @ViewBuilder private var timerBar: some View {
        if app.active.current?.timerEnd != nil {
            TimelineView(.periodic(from: .now, by: 1)) { context in
                InkBar(fraction: app.active.current?.timerFraction(at: context.date) ?? 0, cells: Self.barCells)
            }
        }
    }

    private func timerInput(_ input: String) -> some View {
        HStack(spacing: 8) {
            Text("süre").foregroundStyle(Theme.ink2)
            Text(input + "█").frame(minWidth: 48, alignment: .leading)
                .overlay(alignment: .bottom) { Rectangle().fill(Theme.ink).frame(height: Theme.hairline) }
            Text("dk · ↵ başlat").foregroundStyle(Theme.ink2)
        }
    }

    private func details(_ task: TaskItem) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                if task.priority < 4 { Text("!\(task.priority)").font(Theme.font(bold: task.priority == 1)).foregroundStyle(Theme.ink) }
                if let name = app.projects.name(for: task.project) { Text("#" + name) }
                if let area = task.area { Text(area == .work ? "iş" : "kş") }
                if !task.dueDate.isEmpty { Text("son " + Day.short(task.dueDate)) }
            }
            .foregroundStyle(Theme.ink2)
            .lineLimit(1)
            InkRule()
            if task.hasDetails {
                Text(task.details).fixedSize(horizontal: false, vertical: true)
            } else {
                Text("açıklama yok").foregroundStyle(Theme.ink3)
            }
        }
    }
}

private struct ListPanelContent: View {
    @Environment(AppState.self) private var app

    var body: some View {
        let store = app.today
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(store.today.isEmpty ? "BUGÜN" : "BUGÜN · " + Day.label(store.today)).font(Theme.font(bold: true))
                    Spacer()
                    Text(areaLabel(store.areaFilter) + "  \(store.done.count)/\(store.done.count + store.open.count)")
                        .foregroundStyle(Theme.ink2)
                }
                InkBar(fraction: store.progress, cells: 37)
            }
            .padding(.horizontal, 12).padding(.top, 8).padding(.bottom, 8)
            Rectangle().fill(Theme.ink).frame(height: Theme.hairline)

            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        if store.ordered.isEmpty { Text("bugün için task yok").foregroundStyle(Theme.ink3).padding(.horizontal, 12) }
                        ForEach(store.ordered) { task in
                            TaskRow(task: task, today: store.today, projectName: app.projects.name(for: task.project),
                                    isSelected: task.id == store.selectedID, isActive: task.id == app.active.taskID, compact: true)
                                .id(task.id)
                                .onTapGesture { store.selectedID = task.id }
                        }
                    }
                    .padding(.vertical, 6)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(maxHeight: 320)
                .fixedSize(horizontal: false, vertical: true)
                .onChange(of: store.selectedID) { _, id in if let id { proxy.scrollTo(id) } }
            }

            InkRule()
            Text(app.panel.isPinned ? "sabit · P bırak · esc mini panel" : "↑↓ gezin · ↵ aktif · D tamamla · Y yarına\n1–4 öncelik · ⇥ alan · P sabitle · esc")
                .font(Theme.font(Theme.Size.small)).foregroundStyle(Theme.ink2)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 12).padding(.vertical, 6)
        }
    }

    private func areaLabel(_ area: Area?) -> String {
        switch area {
        case nil: "hepsi"
        case .work: "iş"
        case .personal: "kş"
        }
    }
}
