import Foundation

public enum APIError: Error, Sendable, Equatable, LocalizedError {
    /// 401 — token yok, geçersiz ya da süresi dolmuş.
    case unauthorized
    case http(status: Int, message: String)
    /// Sunucuya ulaşılamadı (adres yanlış, sunucu kapalı, ağ yok).
    case unreachable(String)
    case decoding(String)

    public var errorDescription: String? {
        switch self {
        case .unauthorized: "Giriş gerekli."
        case .http(_, let message): message
        case .unreachable(let detail): "Sunucuya ulaşılamadı: \(detail)"
        case .decoding(let detail): "Yanıt çözülemedi: \(detail)"
        }
    }
}

/// docs/api.md'deki sözleşmenin ince istemcisi. Değer tipidir ve durum tutmaz:
/// adres ya da token değişince yenisi oluşturulur.
public struct APIClient: Sendable {
    public let baseURL: URL
    public let token: String?
    private let session: URLSession

    public init(baseURL: URL, token: String? = nil, session: URLSession = .shared) {
        self.baseURL = baseURL
        self.token = token
        self.session = session
    }

    public func with(token: String?) -> APIClient {
        APIClient(baseURL: baseURL, token: token, session: session)
    }

    // MARK: Kimlik

    public func login(email: String, password: String) async throws -> AuthSession {
        try await send("POST", "/api/collections/users/auth-with-password",
                       body: ["identity": email, "password": password])
    }

    /// Token'ı yeniler; süresi dolmuşsa `.unauthorized` fırlatır.
    public func refresh() async throws -> AuthSession {
        try await send("POST", "/api/collections/users/auth-refresh")
    }

    public func health() async throws {
        let _: Health = try await send("GET", "/api/health")
    }

    // MARK: Görünümler

    public func focusView(area: Area? = nil) async throws -> FocusView {
        try await send("GET", "/api/views/focus", query: area.map { ["area": $0.rawValue] } ?? [:])
    }

    /// `start` verilmezse sunucunun "bugün"ünden başlayan 7 gün.
    public func weekView(start: String? = nil) async throws -> WeekView {
        try await send("GET", "/api/views/week", query: start.map { ["start": $0] } ?? [:])
    }

    /// Bitmemiş bütün task'lar — tarihli ya da plansız (Kanban ve Projeler için).
    public func openTasks() async throws -> [TaskItem] {
        let page: Page<TaskItem> = try await send("GET", "/api/collections/tasks/records",
                                                  query: ["perPage": "500", "sort": "sort_order", "filter": "status != 'done'"])
        return page.items
    }

    public func projects() async throws -> [Project] {
        let page: Page<Project> = try await send("GET", "/api/collections/projects/records",
                                                 query: ["perPage": "500", "sort": "name"])
        return page.items
    }

    public func createProject(name: String, area: Area) async throws -> Project {
        try await send("POST", "/api/collections/projects/records",
                       body: ["name": name, "area": area.rawValue, "status": "active"])
    }

    public func updateProject(_ id: String, _ patch: ProjectPatch) async throws -> Project {
        try await send("PATCH", "/api/collections/projects/records/\(id)", body: patch)
    }

    // MARK: Notlar

    /// Sabitlenenler önce, sonra en son güncellenen.
    public func notes() async throws -> [Note] {
        let page: Page<Note> = try await send("GET", "/api/collections/notes/records",
                                              query: ["perPage": "500", "sort": "-pinned,-updated"])
        return page.items
    }

    public func createNote(title: String, body: String, project: String = "") async throws -> Note {
        try await send("POST", "/api/collections/notes/records",
                       body: NotePatch(title: title, body: body, project: project, pinned: false))
    }

    public func updateNote(_ id: String, _ patch: NotePatch) async throws -> Note {
        try await send("PATCH", "/api/collections/notes/records/\(id)", body: patch)
    }

    public func deleteNote(_ id: String) async throws {
        try await sendIgnoringBody("DELETE", "/api/collections/notes/records/\(id)")
    }

    public func quickNotePreview(text: String) async throws -> ParsedNote {
        try await send("POST", "/api/quicknote/preview", body: ["text": text])
    }

    public func quickNote(text: String) async throws -> QuickNoteResult {
        try await send("POST", "/api/quicknote", body: ["text": text])
    }

    public func deleteProject(_ id: String) async throws {
        try await sendIgnoringBody("DELETE", "/api/collections/projects/records/\(id)")
    }

    /// Serbest metni hızlı eklemenin tarih sözlüğüyle çözer ("cuma", "yarın", "25.09").
    /// Metnin tamamı tek bir tarih değilse `nil`.
    public func resolveDate(_ text: String) async throws -> String? {
        let word = text.trimmingCharacters(in: .whitespaces)
        guard !word.isEmpty, !word.contains(" ") else { return nil }
        let parsed = try await quickAddPreview(text: "x " + word)
        return parsed.title == "x" ? parsed.scheduledDate : nil
    }

    // MARK: Hızlı ekleme

    public func quickAddPreview(text: String) async throws -> ParsedInput {
        try await send("POST", "/api/quickadd/preview", body: ["text": text])
    }

    public func quickAdd(text: String, description: String = "") async throws -> QuickAddResult {
        try await send("POST", "/api/quickadd", body: ["text": text, "description": description])
    }

    // MARK: Task'lar

    public func updateTask(_ id: String, _ patch: TaskPatch) async throws -> TaskItem {
        try await send("PATCH", "/api/collections/tasks/records/\(id)", body: patch)
    }

    public func deleteTask(_ id: String) async throws {
        try await sendIgnoringBody("DELETE", "/api/collections/tasks/records/\(id)")
    }

    public func triage(_ id: String, _ action: TriageAction) async throws {
        var body: [String: String] = [:]
        switch action {
        case .tomorrow:
            body["action"] = "tomorrow"
        case .date(let date):
            body = ["action": "date", "date": date]
        case .toProject(let project, let date):
            body = ["action": "to_project", "project": project]
            if let date { body["date"] = date }
        case .delete:
            body["action"] = "delete"
        }
        try await sendIgnoringBody("POST", "/api/triage/\(id)", body: body)
    }

    // MARK: Aktif task + zamanlayıcı

    public func activeState() async throws -> ActiveState {
        try await send("GET", "/api/focus")
    }

    public func setActive(_ id: String) async throws -> ActiveState {
        try await send("POST", "/api/focus/\(id)")
    }

    public func clearActive() async throws -> ActiveState {
        try await send("POST", "/api/focus/clear")
    }

    public func startTimer(seconds: Int) async throws -> ActiveState {
        try await send("POST", "/api/focus/timer", body: TimerBody(action: "start", duration: seconds))
    }

    public func stopTimer() async throws -> ActiveState {
        try await send("POST", "/api/focus/timer", body: TimerBody(action: "stop", duration: nil))
    }

    // MARK: Taşıma

    private struct Health: Decodable {}
    private struct Page<T: Decodable>: Decodable { let items: [T] }
    private struct TimerBody: Encodable { let action: String; let duration: Int? }
    private struct ErrorBody: Decodable { let message: String }
    private struct NoBody: Encodable {}

    func makeRequest(_ method: String, _ path: String, query: [String: String] = [:]) -> URLRequest {
        var components = URLComponents(url: baseURL.appending(path: path), resolvingAgainstBaseURL: false)!
        if !query.isEmpty {
            components.queryItems = query.sorted { $0.key < $1.key }.map { URLQueryItem(name: $0.key, value: $0.value) }
        }
        var request = URLRequest(url: components.url!)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let token { request.setValue(token, forHTTPHeaderField: "Authorization") }
        return request
    }

    private func send<T: Decodable>(_ method: String, _ path: String, query: [String: String] = [:]) async throws -> T {
        try await send(method, path, query: query, body: NoBody?.none)
    }

    private func send<T: Decodable, B: Encodable>(_ method: String, _ path: String, query: [String: String] = [:],
                                                  body: B?) async throws -> T {
        let data = try await perform(method, path, query: query, body: body)
        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            throw APIError.decoding("\(method) \(path): \(error)")
        }
    }

    private func sendIgnoringBody(_ method: String, _ path: String) async throws {
        _ = try await perform(method, path, query: [:], body: NoBody?.none)
    }

    private func sendIgnoringBody<B: Encodable>(_ method: String, _ path: String, body: B) async throws {
        _ = try await perform(method, path, query: [:], body: body)
    }

    private func perform<B: Encodable>(_ method: String, _ path: String, query: [String: String], body: B?) async throws -> Data {
        var request = makeRequest(method, path, query: query)
        if let body { request.httpBody = try JSONEncoder().encode(body) }

        let data: Data, response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch let error as URLError where error.code == .cancelled {
            throw CancellationError()
        } catch {
            throw APIError.unreachable(error.localizedDescription)
        }

        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard (200..<300).contains(status) else {
            if status == 401 { throw APIError.unauthorized }
            let message = (try? JSONDecoder().decode(ErrorBody.self, from: data))?.message ?? "HTTP \(status)"
            throw APIError.http(status: status, message: message)
        }
        return data
    }
}
