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
        #expect(Day.weekdayFirst("2026-09-20") == "Paz 20.09")
    }

    @Test func arithmetic() {
        #expect(Day.adding(3, to: "2026-09-29") == "2026-10-02")
        #expect(Day.adding(-1, to: "2027-01-01") == "2026-12-31")
        #expect(Day.adding(7, to: "2028-02-23") == "2028-03-01")
        #expect(Day.adding(1, to: "bozuk") == "bozuk")
    }
}

@Suite struct NoteTests {
    @Test func splitsEditorTextIntoTitleAndBody() {
        #expect(Note.split("Başlık\nsatır 1\n\nsatır 2\n") == ("Başlık", "satır 1\n\nsatır 2"))
        #expect(Note.split("\n  Tek satır  ") == ("Tek satır", ""))
        #expect(Note.split("  \n") == ("", ""))
    }
}

@Suite struct TimerTests {
    func state(_ startedAt: String, _ duration: Int) throws -> ActiveState {
        let json = "{\"state\":{\"current_task\":\"\",\"timer_started_at\":\"\(startedAt)\",\"timer_duration\":\(duration)},\"task\":null}"
        return try JSONDecoder().decode(ActiveState.self, from: Data(json.utf8))
    }

    @Test func parsesPocketBaseDates() {
        let date = PBDate.parse("2026-09-20 16:45:00.500Z")
        #expect(date?.timeIntervalSince1970 == 1_789_922_700.5)
        #expect(PBDate.parse("") == nil)
        #expect(PBDate.parse("bozuk") == nil)
    }

    @Test func fractionCountsDown() throws {
        let active = try state("2026-09-20 16:45:00.000Z", 600)
        let start = PBDate.parse("2026-09-20 16:45:00.000Z")!
        #expect(active.timerEnd == start.addingTimeInterval(600))
        #expect(active.timerFraction(at: start) == 1)
        #expect(active.timerFraction(at: start.addingTimeInterval(150)) == 0.75)
        #expect(active.timerFraction(at: start.addingTimeInterval(9999)) == 0)
    }

    @Test func noTimerMeansNil() throws {
        #expect(try state("", 0).timerEnd == nil)
        #expect(try state("", 0).timerFraction(at: .now) == nil)
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

    @Test func weekViewPlacesTasksOnTheirDay() async throws {
        let api = try await client()
        let id = try await api.quickAdd(text: "zz-swift hafta yarın").task.id

        var week = try await api.weekView()
        #expect(week.days.count == 7 && week.days[0].date == week.today)
        #expect(week.days[1].date == Day.adding(1, to: week.today))
        #expect(week.days[1].tasks.contains { $0.id == id })

        _ = try await api.updateTask(id, TaskPatch(scheduledDate: Day.adding(9, to: week.today)))
        week = try await api.weekView()
        #expect(week.days.allSatisfy { day in !day.tasks.contains { $0.id == id } })
        let next = try await api.weekView(start: Day.adding(7, to: week.today))
        #expect(next.days[2].tasks.contains { $0.id == id } && next.days[2].openCount >= 1)

        try await api.deleteTask(id)
    }

    @Test func openTasksIncludesUnscheduledButNotDone() async throws {
        let api = try await client()
        let project = try await api.createProject(name: "zz-swift-kanban", area: .personal)
        let id = try await api.quickAdd(text: "zz-swift plansız #zz-swift-kanban").task.id

        var open = try await api.openTasks()
        #expect(open.first { $0.id == id }?.scheduledDate == "")
        _ = try await api.updateTask(id, TaskPatch(status: .blocked))
        open = try await api.openTasks()
        #expect(open.first { $0.id == id }?.status == .blocked)
        _ = try await api.updateTask(id, TaskPatch(status: .done))
        #expect(try await api.openTasks().contains { $0.id == id } == false)

        try await api.deleteTask(id)
        try await api.deleteProject(project.id)
    }

    @Test func projectsAndNotesLifecycle() async throws {
        let api = try await client()
        var project = try await api.createProject(name: "zz-swift-notlar", area: .work)
        project = try await api.updateProject(project.id, ProjectPatch(details: "tanım\n2. satır", status: .onHold))
        #expect(project.details == "tanım\n2. satır" && project.status == .onHold && project.area == .work)
        project = try await api.updateProject(project.id, ProjectPatch(name: "zz-swift-notlar-2", status: .active))
        #expect(project.name == "zz-swift-notlar-2" && project.details == "tanım\n2. satır")

        let preview = try await api.quickNotePreview(text: "zz-swift fikir #zz-swift-not\ngövde")
        #expect(preview.title == "zz-swift fikir" && preview.project?.id == project.id && preview.tokens.count == 1)

        let quick = try await api.quickNote(text: "zz-swift fikir #zz-swift-not\ngövde")
        #expect(quick.note.project == project.id && quick.note.body == "gövde" && !quick.note.pinned)

        let manual = try await api.createNote(title: "zz-swift elle", body: "")
        let pinned = try await api.updateNote(manual.id, NotePatch(body: "yeni gövde", pinned: true))
        #expect(pinned.pinned && pinned.body == "yeni gövde" && pinned.title == "zz-swift elle")

        let all = try await api.notes()
        #expect(all.first?.pinned == true)
        #expect(all.contains { $0.id == quick.note.id })

        try await api.deleteNote(manual.id)
        try await api.deleteNote(quick.note.id)
        try await api.deleteProject(project.id)
    }

    @Test func triageWithDateAndNewProject() async throws {
        let api = try await client()
        let today = try await api.focusView().today

        #expect(try await api.resolveDate("bugün") == today)
        #expect(try await api.resolveDate("  yarın ") != nil)
        #expect(try await api.resolveDate("birgün") == nil)
        #expect(try await api.resolveDate("yarın !1") == nil)
        #expect(try await api.resolveDate("") == nil)

        let project = try await api.createProject(name: "zz-swift-proje", area: .work)
        #expect(try await api.projects().contains { $0.id == project.id })

        let id = try await api.quickAdd(text: "zz-swift triyaj").task.id
        try await api.triage(id, .date("2027-03-01"))
        #expect(try await api.focusView().tasks.contains { $0.id == id } == false)
        try await api.triage(id, .toProject(id: project.id, date: nil))
        let moved = try await api.updateTask(id, TaskPatch())
        #expect(moved.project == project.id && moved.area == .work && moved.scheduledDate.isEmpty)

        try await api.triage(id, .delete)
        try await api.deleteProject(project.id)
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
