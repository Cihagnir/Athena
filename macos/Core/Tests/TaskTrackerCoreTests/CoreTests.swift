import Foundation
import Testing
@testable import TaskTrackerCore

@Suite struct DayTests {
    @Test func labels() {
        #expect(Day.short("2026-09-20") == "20.09")
        #expect(Day.label("2026-09-20") == "20.09 Paz")
        #expect(Day.label("2026-09-23") == "23.09 Çar")
        #expect(Day.label("2027-01-01") == "01.01 Cum")
        #expect(Day.label("bozuk") == "bozuk")
    }
}

@Suite struct DecodingTests {
    @Test func taskWithEmptyOptionalFields() throws {
        let json = """
        {"id":"abc","title":"Süt al","description":"","area":"","project":"","status":"todo","priority":4,
         "scheduled_date":"2026-09-20","due_date":"","sort_order":1790000000000,"completed_at":"","note":"",
         "collectionId":"x","collectionName":"tasks","created":"","updated":""}
        """
        let task = try JSONDecoder().decode(TaskItem.self, from: Data(json.utf8))
        #expect(task.area == nil)
        #expect(task.project.isEmpty)
        #expect(!task.hasDetails)
        #expect(task.scheduledDate == "2026-09-20")
    }

    @Test func parsedInputTokens() throws {
        let json = """
        {"literal":false,"valid":true,"title":"Rapor #yok","scheduled_date":"2026-09-22","due_date":null,
         "priority":null,"project":null,"area":null,"description":"not","warnings":["project_not_found"],
         "tokens":[{"type":"date","raw":"salı","start":6,"end":10,"value":"2026-09-22"},
                   {"type":"project","raw":"#yok","start":11,"end":15,"value":null},
                   {"type":"yeni-tür","raw":"x","start":0,"end":1,"value":1},
                   {"type":"description","raw":"// not","start":16,"end":22,"value":"not"}]}
        """
        let parsed = try JSONDecoder().decode(ParsedInput.self, from: Data(json.utf8))
        #expect(parsed.tokens.map(\.kind) == [.date, .project, .unknown, .description])
        #expect(parsed.tokens[0].resolved)
        #expect(!parsed.tokens[1].resolved)
        #expect(parsed.tokens[0].range == NSRange(location: 6, length: 4))
        #expect(parsed.dueDate == nil)
    }

    @Test func patchSendsOnlyGivenFields() throws {
        let data = try JSONEncoder().encode(TaskPatch(status: .done, scheduledDate: ""))
        let object = try JSONSerialization.jsonObject(with: data) as? [String: String]
        #expect(object == ["status": "done", "scheduled_date": ""])
    }
}

/// Çalışan backend'e karşı sözleşme testi. Ortam değişkenleri yoksa atlanır:
///   TT_URL=http://127.0.0.1:8090 TT_EMAIL=… TT_PASSWORD=… swift test
@Suite(.enabled(if: ProcessInfo.processInfo.environment["TT_URL"] != nil), .serialized)
struct LiveAPITests {
    let env = ProcessInfo.processInfo.environment

    func client() async throws -> APIClient {
        let anonymous = APIClient(baseURL: URL(string: env["TT_URL"]!)!)
        let auth = try await anonymous.login(email: env["TT_EMAIL"]!, password: env["TT_PASSWORD"]!)
        return anonymous.with(token: auth.token)
    }

    @Test func rejectsAnonymousAndBadPassword() async throws {
        let anonymous = APIClient(baseURL: URL(string: env["TT_URL"]!)!)
        try await anonymous.health()
        await #expect(throws: APIError.unauthorized) { _ = try await anonymous.focusView() }
        await #expect(throws: APIError.self) { _ = try await anonymous.login(email: env["TT_EMAIL"]!, password: "yanlış-parola") }
    }

    @Test func unreachableServerIsReported() async throws {
        let dead = APIClient(baseURL: URL(string: "http://127.0.0.1:9")!)
        do {
            try await dead.health()
            Issue.record("hata bekleniyordu")
        } catch let error as APIError {
            guard case .unreachable = error else { Issue.record("beklenmeyen: \(error)"); return }
        }
    }

    @Test func quickAddLifecycle() async throws {
        let api = try await client()
        _ = try await api.refresh()

        let preview = try await api.quickAddPreview(text: "zz-swift deneme yarın son:yarın !2 // kısa not")
        #expect(preview.title == "zz-swift deneme")
        #expect(preview.tokens.map(\.kind) == [.date, .due, .priority, .description])

        let added = try await api.quickAdd(text: "zz-swift deneme !2 // kısa not", description: "uzun not")
        let id = added.task.id
        #expect(added.task.details == "kısa not\n\nuzun not")
        #expect(added.task.priority == 2)

        var view = try await api.focusView()
        #expect(view.tasks.contains { $0.id == id })
        #expect(added.task.scheduledDate == view.today)

        let active = try await api.setActive(id)
        #expect(active.task?.id == id)
        #expect(try await api.startTimer(seconds: 60).state.timerDuration == 60)

        let done = try await api.updateTask(id, TaskPatch(status: .done))
        #expect(done.isDone && !done.completedAt.isEmpty)
        view = try await api.focusView()
        #expect(view.done.contains { $0.id == id })
        #expect(try await api.activeState().task == nil)

        _ = try await api.updateTask(id, TaskPatch(status: .todo))
        try await api.triage(id, .tomorrow)
        #expect(try await api.focusView().tasks.contains { $0.id == id } == false)
        try await api.deleteTask(id)
    }

    @Test func realtimeDeliversTaskEvents() async throws {
        let api = try await client()
        let (connected, signal) = AsyncStream<Void>.makeStream()
        let stream = RealtimeClient(api: api).events(topics: ["tasks"]) { signal.yield() }

        let listener = Task { () -> RealtimeEvent? in
            for try await event in stream where event.action == "create" { return event }
            return nil
        }
        for await _ in connected { break }

        let added = try await api.quickAdd(text: "zz-swift canlı")
        let event = try await withTimeout(seconds: 5) { try await listener.value }
        #expect(event == RealtimeEvent(topic: "tasks", action: "create", recordID: added.task.id))
        try await api.deleteTask(added.task.id)
    }
}

struct TimeoutError: Error {}

func withTimeout<T: Sendable>(seconds: Double, _ work: @escaping @Sendable () async throws -> T) async throws -> T {
    try await withThrowingTaskGroup(of: T.self) { group in
        group.addTask { try await work() }
        group.addTask { try await Task.sleep(for: .seconds(seconds)); throw TimeoutError() }
        let result = try await group.next()!
        group.cancelAll()
        return result
    }
}
