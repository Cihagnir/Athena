import KeyboardShortcuts
import SwiftUI

/// Ayarlar: sunucu adresi, oturum, görünüm ve kısayol listesi.
/// Kısayol tablosu `ActionRegistry`'den üretilir; elle liste tutulmaz.
struct SettingsView: View {
    @Environment(AppState.self) private var app

    @State private var server = ""
    @State private var serverMessage: String?
    @State private var isChecking = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 32) {
                Text("AYARLAR").font(Theme.font(Theme.Size.title, bold: true))
                serverSection
                appearanceSection
                shortcutsSection
            }
            .padding(.horizontal, 32).padding(.top, 44).padding(.bottom, 32)
            .frame(maxWidth: 720, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .onAppear { server = app.settings.serverAddress }
    }

    // MARK: Sunucu

    private var serverSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            InkSectionLabel("SUNUCU")
            InkRule()
            InkField(label: "ADRES", text: $server, onSubmit: connect)
            HStack(spacing: 12) {
                Button(isChecking ? "deneniyor…" : "bağlan", action: connect)
                    .buttonStyle(InkButtonStyle())
                    .disabled(isChecking || server == app.settings.serverAddress)
                Text("adres değişince yeniden giriş gerekir").font(Theme.font(Theme.Size.small)).foregroundStyle(Theme.ink2)
            }
            if let serverMessage { Text("? " + serverMessage).fixedSize(horizontal: false, vertical: true) }
            HStack(spacing: 12) {
                Text("oturum").foregroundStyle(Theme.ink2)
                Text(app.settings.email)
                Button("çıkış yap") { app.logout() }.buttonStyle(InkButtonStyle())
            }
            .padding(.top, 4)
        }
    }

    private func connect() {
        guard !isChecking, server != app.settings.serverAddress else { return }
        isChecking = true
        Task {
            serverMessage = await app.changeServer(to: server)
            isChecking = false
        }
    }

    // MARK: Görünüm

    private var appearanceSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            InkSectionLabel("GÖRÜNÜM")
            InkRule()
            HStack(spacing: 8) {
                ForEach(Appearance.allCases, id: \.self) { option in
                    Button(option.title) { app.settings.appearance = option }
                        .buttonStyle(InkButtonStyle(selected: app.settings.appearance == option))
                }
            }
        }
    }

    // MARK: Kısayollar

    private var shortcutsSection: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 4) {
                InkSectionLabel("KISAYOLLAR")
                InkRule()
                Text("Sağdaki kutuya tıklayıp tuşa basarak herhangi bir aksiyona global kısayol atanır.")
                    .font(Theme.font(Theme.Size.small)).foregroundStyle(Theme.ink2)
            }
            ForEach(ActionContext.allCases, id: \.self) { context in
                VStack(alignment: .leading, spacing: 0) {
                    Text(context.title).font(Theme.font(bold: true)).padding(.bottom, 6)
                    ForEach(app.registry.actions(in: context)) { action in
                        HStack(spacing: 12) {
                            Text(action.keysDisplay).frame(width: 72, alignment: .leading)
                            Text(action.title).foregroundStyle(Theme.ink2)
                            Spacer()
                            if action.isBindable { KeyboardShortcuts.Recorder(for: action.globalName) }
                        }
                        .frame(minHeight: 28)
                        InkRule()
                    }
                }
            }
        }
    }
}
