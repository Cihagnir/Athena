import SwiftUI
import TaskTrackerCore

/// Projeler: solda liste, sağda seçili projenin tanımı. Tasarım: tuvaldeki "Projeler" panoları.
/// Şimdilik yalnızca proje + tanım; projeye task bağlama ekranı yok (hızlı eklemede `#ad` çalışır).
struct ProjectsView: View {
    @Environment(AppState.self) private var app

    var body: some View {
        let store = app.projectsScreen
        VStack(spacing: 0) {
            HStack(alignment: .firstTextBaseline) {
                Text("PROJELER").font(Theme.font(Theme.Size.title, bold: true))
                Spacer()
                Text("\(store.count(.active)) aktif · \(store.count(.onHold)) beklemede · \(store.count(.done)) bitti")
                    .foregroundStyle(Theme.ink2)
            }
            .padding(.horizontal, 32).padding(.top, 44).padding(.bottom, 12)
            Rectangle().fill(Theme.ink).frame(height: Theme.hairline)

            HStack(spacing: 0) {
                list(store).frame(width: 380)
                Rectangle().fill(Theme.ink3).frame(width: Theme.hairline)
                detail(store).frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
            .frame(maxHeight: .infinity)

            InkRule()
            InkHints(hints(store.mode)).padding(.horizontal, 32).padding(.vertical, 8)
        }
        .keyboardFocus(unless: app.overlay != nil || store.isTyping)
        .onKeyPress(phases: .down) { app.registry.handle($0, in: .projects) }
        .task { await store.load() }
    }

    private func list(_ store: ProjectsScreenStore) -> some View {
        @Bindable var store = store
        return VStack(alignment: .leading, spacing: 0) {
            if store.mode == .creating {
                nameField($store.nameInput, prefix: "+", hint: "↵ oluştur", store)
            } else {
                HStack(spacing: 12) { Text("+"); Text("yeni proje…"); Spacer(); Text("N").font(Theme.font(Theme.Size.small)) }
                    .foregroundStyle(Theme.ink3).padding(.horizontal, 24).padding(.vertical, 5).padding(.bottom, 4)
                    .contentShape(Rectangle()).onTapGesture { store.beginCreating() }
            }
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(spacing: 0) {
                        if store.ordered.isEmpty && store.mode != .creating {
                            Text("henüz proje yok").foregroundStyle(Theme.ink3)
                                .frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal, 24)
                        }
                        ForEach(store.ordered) { project in
                            if store.mode == .renaming && project.id == store.selectedID {
                                nameField($store.nameInput, prefix: "#", hint: "↵ kaydet", store)
                            } else {
                                row(project, selected: project.id == store.selectedID)
                                    .id(project.id)
                                    .onTapGesture { if !store.isTyping { store.selectedID = project.id } }
                            }
                        }
                    }
                }
                .onChange(of: store.selectedID) { _, id in if let id { proxy.scrollTo(id) } }
            }
        }
        .padding(.vertical, 12)
    }

    private func nameField(_ text: Binding<String>, prefix: String, hint: String, _ store: ProjectsScreenStore) -> some View {
        VStack(spacing: 4) {
            HStack(spacing: 12) {
                Text(prefix)
                InkTextView(text: text, focusTrigger: 1, onSubmit: store.confirmName, onCancel: store.cancel).frame(height: 20)
                Text(hint).font(Theme.font(Theme.Size.small)).foregroundStyle(Theme.ink2)
            }
            Rectangle().fill(Theme.ink).frame(height: Theme.focusLine)
        }
        .padding(.horizontal, 24).padding(.vertical, 5)
    }

    private func row(_ project: Project, selected: Bool) -> some View {
        let dim = project.status == .done
        return HStack(spacing: 12) {
            Text("#" + project.name).font(Theme.font(bold: selected)).lineLimit(1)
            Spacer(minLength: 8)
            Text(project.area == .work ? "iş" : "kş")
            Text(Self.statusText(project.status)).lineLimit(1).frame(width: 88, alignment: .leading)
        }
        .foregroundStyle(selected ? Theme.paper : dim ? Theme.ink3 : Theme.ink)
        .padding(.horizontal, 24).padding(.vertical, 5)
        .background(selected ? Theme.ink : Theme.paper)
        .contentShape(Rectangle())
    }

    @ViewBuilder private func detail(_ store: ProjectsScreenStore) -> some View {
        @Bindable var store = store
        if let project = store.selected {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("#" + project.name).font(Theme.font(Theme.Size.title, bold: true))
                    HStack(spacing: 12) {
                        Text(project.area == .work ? "iş" : "kişisel")
                        Text(Self.statusText(project.status))
                        if let date = project.created.split(separator: " ").first { Text("oluşturuldu " + Day.short(String(date))) }
                    }
                    .foregroundStyle(Theme.ink2)
                }
                InkRule()
                if store.mode == .confirmDelete {
                    Text("Proje silinsin mi?  ↵ evet · esc hayır")
                    Text("Task'lar ve notlar silinmez; yalnızca bu projeyle bağları kalkar.").foregroundStyle(Theme.ink2)
                } else if store.mode == .editing {
                    InkSectionLabel("TANIM · düzenleniyor")
                    InkTextView(text: $store.detailsInput, multiline: true, submitsOnReturn: false, focusTrigger: 1, onCancel: store.cancel)
                        .padding(12)
                        .overlay(Rectangle().strokeBorder(Theme.ink, lineWidth: Theme.focusLine))
                } else {
                    InkSectionLabel("TANIM")
                    ScrollView {
                        Group {
                            if project.details.isEmpty {
                                Text("tanım yok — E ile yaz: ne yapmak istiyoruz, nasıl yapacağız").foregroundStyle(Theme.ink3)
                            } else {
                                Text(project.details).textSelection(.enabled)
                            }
                        }
                        .frame(maxWidth: 560, alignment: .leading)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
            .padding(.horizontal, 32).padding(.vertical, 24)
        }
    }

    private static func statusText(_ status: ProjectStatus) -> String {
        switch status {
        case .active: "aktif"
        case .onHold: "beklemede"
        case .done: "bitti"
        }
    }

    private func hints(_ mode: ProjectsScreenStore.Mode) -> String {
        switch mode {
        case .browse: "↑↓ gezin · N yeni proje · E tanımı düzenle · R yeniden adlandır · S durum · A alan · ⌫ sil"
        case .creating, .renaming: "↵ onayla · esc vazgeç"
        case .editing: "yazarken kendiliğinden kaydedilir · esc düzenlemeden çık"
        case .confirmDelete: "↵ sil · esc vazgeç"
        }
    }
}
