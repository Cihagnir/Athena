import SwiftUI

struct LoginView: View {
    @Environment(AppState.self) private var app

    @State private var server = ""
    @State private var apiKey = ""
    @State private var email = ""
    @State private var password = ""
    @State private var message: String?
    @State private var isBusy = false

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("task_tracker").font(Theme.font(Theme.Size.title, bold: true))
            InkField(label: "SUNUCU", text: $server, onSubmit: submit)
            InkField(label: "API ANAHTARI · yalnızca internete açık sunucuda", text: $apiKey, secure: true, onSubmit: submit)
            InkField(label: "E-POSTA", text: $email, onSubmit: submit)
            InkField(label: "PAROLA", text: $password, secure: true, onSubmit: submit)
            HStack(spacing: 12) {
                Button(isBusy ? "bağlanıyor…" : "giriş yap", action: submit)
                    .buttonStyle(InkButtonStyle())
                    .disabled(isBusy)
                Text("↵").font(Theme.font(Theme.Size.small)).foregroundStyle(Theme.ink2)
            }
            if let message = message ?? app.backend.lastError {
                Text("? " + message).fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(width: 360)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            server = app.settings.serverAddress
            apiKey = app.settings.apiKey
            email = app.settings.email
        }
    }

    private func submit() {
        guard !isBusy else { return }
        isBusy = true
        Task {
            message = await app.login(server: server, apiKey: apiKey, email: email, password: password)
            isBusy = false
            if message == nil { password = "" }
        }
    }
}
