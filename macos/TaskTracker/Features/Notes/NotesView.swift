import SwiftUI
import TaskTrackerCore

/// Notlar: sticky düzeninde kart ızgarası + tam alan editör. Tasarım: tuvaldeki "Notlar" panoları.
struct NotesView: View {
    @Environment(AppState.self) private var app

    private static let cardWidth: CGFloat = 270
    private static let spacing: CGFloat = 16

    var body: some View {
        let store = app.notes
        VStack(spacing: 0) {
            if store.mode == .editing { editor(store) } else { grid(store) }
            InkRule()
            InkHints(hints(store.mode)).padding(.horizontal, 32).padding(.vertical, 8)
        }
        .keyboardFocus(unless: app.overlay != nil || store.isTyping)
        // Yazma modunda tuşlar metin alanına bırakılır: aksiyon iş yapmasa da `handle` "işlendi"
        // dönerdi ve kısayola bağlı harfler (N, E, P…) metne yazılmazdı. esc'i alan kendisi (`onCancel`) kapatır.
        .onKeyPress(phases: .down) { store.isTyping ? .ignored : app.registry.handle($0, in: .notes) }
        .task { await store.reload() }
    }

    // MARK: Izgara

    private func grid(_ store: NotesStore) -> some View {
        @Bindable var store = store
        return VStack(spacing: 0) {
            HStack(alignment: .firstTextBaseline) {
                Text("NOTLAR").font(Theme.font(Theme.Size.title, bold: true))
                Spacer()
                HStack(spacing: 12) {
                    ForEach(Array(store.filters.enumerated()), id: \.offset) { _, filter in
                        if filter == store.filter { InkTag(label(filter)) } else { Text(label(filter)).foregroundStyle(Theme.ink2) }
                    }
                }
                .lineLimit(1)
            }
            .padding(.horizontal, 32).padding(.top, 44).padding(.bottom, 12)
            Rectangle().fill(Theme.ink).frame(height: Theme.hairline)

            if store.mode == .searching || !store.query.isEmpty {
                HStack(spacing: 12) {
                    Text("/")
                    if store.mode == .searching {
                        InkTextView(text: $store.query, focusTrigger: 1, onSubmit: { store.endSearch(clear: false) }, onCancel: { store.endSearch(clear: true) })
                            .frame(height: 20)
                    } else {
                        Text(store.query); Spacer(); Text("/ düzenle · esc temizle").font(Theme.font(Theme.Size.small)).foregroundStyle(Theme.ink2)
                    }
                }
                .padding(.horizontal, 32).padding(.vertical, 12)
            } else {
                HStack(spacing: 12) {
                    Text("+"); Text("yeni not… ilk satır başlık olur"); Spacer()
                    Text("N · her yerden ⌃⌥N").font(Theme.font(Theme.Size.small))
                }
                .foregroundStyle(Theme.ink3).padding(.horizontal, 32).padding(.vertical, 12)
                .contentShape(Rectangle()).onTapGesture { store.beginNew() }
            }
            InkRule()

            GeometryReader { geometry in
                let columns = max(Int((geometry.size.width - 64 + Self.spacing) / (Self.cardWidth + Self.spacing)), 1)
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: Self.spacing), count: columns), spacing: Self.spacing) {
                            ForEach(store.visible) { note in
                                card(note, store).id(note.id)
                                    .onTapGesture(count: 2) { store.selectedID = note.id; store.openSelected() }
                                    .onTapGesture { store.selectedID = note.id }
                            }
                        }
                        .padding(.horizontal, 32).padding(.vertical, 20)
                        if store.hasLoaded && store.visible.isEmpty {
                            Text(store.notes.isEmpty ? "henüz not yok" : "eşleşen not yok").foregroundStyle(Theme.ink3)
                                .frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal, 32)
                        }
                    }
                    .onChange(of: store.selectedID) { _, id in if let id { proxy.scrollTo(id) } }
                }
                .onChange(of: columns, initial: true) { _, value in store.columns = value }
            }
        }
    }

    private func card(_ note: Note, _ store: NotesStore) -> some View {
        let selected = note.id == store.selectedID
        let confirming = selected && store.mode == .confirmDelete
        let secondary = selected ? Theme.paper : Theme.ink2
        return VStack(alignment: .leading, spacing: 6) {
            Text(note.title).font(Theme.font(bold: true)).lineLimit(1)
            Text(confirming ? "Silinsin mi?\n↵ evet · esc hayır" : note.body)
                .foregroundStyle(confirming ? (selected ? Theme.paper : Theme.ink) : secondary)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            HStack {
                Text([Self.date(note.updated), app.projects.name(for: note.project).map { "#" + $0 }].compactMap { $0 }.joined(separator: " · ")).lineLimit(1)
                Spacer()
                if note.pinned { Text("▪ sabit") }
            }
            .font(Theme.font(Theme.Size.small)).foregroundStyle(secondary)
        }
        .padding(12)
        .frame(height: 176)
        .foregroundStyle(selected ? Theme.paper : Theme.ink)
        .background(selected ? Theme.ink : Theme.paper)
        // Renk yok: sabitlenen not kalın çerçeveyle ayrışır.
        .overlay(Rectangle().strokeBorder(Theme.ink, lineWidth: note.pinned ? Theme.focusLine : Theme.hairline))
        .contentShape(Rectangle())
    }

    // MARK: Editör

    private func editor(_ store: NotesStore) -> some View {
        @Bindable var store = store
        return VStack(spacing: 0) {
            HStack(alignment: .firstTextBaseline) {
                Text(store.editingID == nil ? "NOTLAR · yeni not" : "NOTLAR · düzenleniyor").font(Theme.font(Theme.Size.title, bold: true))
                Spacer()
                if let note = store.notes.first(where: { $0.id == store.editingID }) {
                    Text([Self.date(note.updated), app.projects.name(for: note.project).map { "#" + $0 }].compactMap { $0 }.joined(separator: " · "))
                        .foregroundStyle(Theme.ink2)
                }
            }
            .padding(.horizontal, 32).padding(.top, 44).padding(.bottom, 12)
            Rectangle().fill(Theme.ink).frame(height: Theme.hairline)
            InkTextView(text: $store.editorText, multiline: true, submitsOnReturn: false, focusTrigger: 1, onCancel: store.closeEditor)
                .frame(maxWidth: 720, maxHeight: .infinity, alignment: .topLeading)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 32).padding(.vertical, 24)
        }
    }

    // MARK: Yardımcılar

    private func label(_ filter: NotesStore.Filter) -> String {
        switch filter {
        case .all: "hepsi"
        case .unassigned: "projesiz"
        case .project(let id): "#" + (app.projects.name(for: id) ?? "?")
        }
    }

    /// "2026-09-20 16:45:00.000Z" → "20.09"
    private static func date(_ stamp: String) -> String? {
        stamp.split(separator: " ").first.map { Day.short(String($0)) }
    }

    private func hints(_ mode: NotesStore.Mode) -> String {
        switch mode {
        case .browse: "↑↓ ← → gezin · ↵ aç / düzenle · N yeni not · P sabitle · ⇥ proje filtresi · / ara · ⌫ sil"
        case .editing: "ilk satır başlık · yazarken kendiliğinden kaydedilir · esc nota dön"
        case .searching: "↵ aramayı uygula · esc temizle"
        case .confirmDelete: "↵ sil · esc vazgeç"
        }
    }
}
