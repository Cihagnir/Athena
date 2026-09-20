import Foundation

// docs/api.md ve docs/data-model.md'deki kayıtların Swift karşılıkları.
// PocketBase boş alanları "" olarak döndürür; opsiyonel enum'lar buna göre çözülür.

public enum Area: String, Codable, Sendable, CaseIterable {
    case work, personal
}

public enum TaskStatus: String, Codable, Sendable, CaseIterable {
    case todo, doing, blocked, done
}

public struct TaskItem: Identifiable, Sendable, Equatable, Decodable {
    public let id: String
    public var title: String
    /// `tasks.description` — Swift'in `description` alışkanlığıyla karışmasın diye `details`.
    public var details: String
    public var area: Area?
    /// Proje id'si; boş = projesiz.
    public var project: String
    public var status: TaskStatus
    public var priority: Int
    /// "YYYY-MM-DD" ya da "".
    public var scheduledDate: String
    public var dueDate: String
    public var sortOrder: Double
    public var completedAt: String

    enum CodingKeys: String, CodingKey {
        case id, title, area, project, status, priority
        case details = "description"
        case scheduledDate = "scheduled_date"
        case dueDate = "due_date"
        case sortOrder = "sort_order"
        case completedAt = "completed_at"
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        title = try c.decode(String.self, forKey: .title)
        details = try c.decodeIfPresent(String.self, forKey: .details) ?? ""
        area = Area(rawValue: try c.decodeIfPresent(String.self, forKey: .area) ?? "")
        project = try c.decodeIfPresent(String.self, forKey: .project) ?? ""
        status = try c.decode(TaskStatus.self, forKey: .status)
        priority = try c.decode(Int.self, forKey: .priority)
        scheduledDate = try c.decodeIfPresent(String.self, forKey: .scheduledDate) ?? ""
        dueDate = try c.decodeIfPresent(String.self, forKey: .dueDate) ?? ""
        sortOrder = try c.decodeIfPresent(Double.self, forKey: .sortOrder) ?? 0
        completedAt = try c.decodeIfPresent(String.self, forKey: .completedAt) ?? ""
    }

    public var isDone: Bool { status == .done }
    public var hasDetails: Bool { !details.isEmpty }
}

public enum ProjectStatus: String, Codable, Sendable, CaseIterable {
    case active, onHold = "on_hold", done
}

public struct Project: Identifiable, Sendable, Equatable, Decodable {
    public let id: String
    public var name: String
    public var area: Area
    public var status: ProjectStatus
    /// `projects.description` — projenin tanımı (serbest metin / markdown).
    public var details: String
    public var created: String

    enum CodingKeys: String, CodingKey {
        case id, name, area, status, created
        case details = "description"
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        name = try c.decode(String.self, forKey: .name)
        area = try c.decode(Area.self, forKey: .area)
        status = try c.decode(ProjectStatus.self, forKey: .status)
        details = try c.decodeIfPresent(String.self, forKey: .details) ?? ""
        created = try c.decodeIfPresent(String.self, forKey: .created) ?? ""
    }
}

public struct ProjectPatch: Sendable, Encodable {
    public var name: String?
    public var details: String?
    public var area: Area?
    public var status: ProjectStatus?

    public init(name: String? = nil, details: String? = nil, area: Area? = nil, status: ProjectStatus? = nil) {
        self.name = name
        self.details = details
        self.area = area
        self.status = status
    }

    enum CodingKeys: String, CodingKey {
        case name, area, status
        case details = "description"
    }
}

public struct Note: Identifiable, Sendable, Equatable, Decodable {
    public let id: String
    public var title: String
    public var body: String
    /// Proje id'si; boş = projesiz.
    public var project: String
    public var pinned: Bool
    public var created: String
    public var updated: String

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        title = try c.decode(String.self, forKey: .title)
        body = try c.decodeIfPresent(String.self, forKey: .body) ?? ""
        project = try c.decodeIfPresent(String.self, forKey: .project) ?? ""
        pinned = try c.decodeIfPresent(Bool.self, forKey: .pinned) ?? false
        created = try c.decodeIfPresent(String.self, forKey: .created) ?? ""
        updated = try c.decodeIfPresent(String.self, forKey: .updated) ?? ""
    }

    enum CodingKeys: String, CodingKey { case id, title, body, project, pinned, created, updated }

    /// Editördeki tek metin: ilk satır başlık, kalanı gövde.
    public var text: String { body.isEmpty ? title : title + "\n" + body }

    /// Editör metnini başlık + gövdeye böler (ilk dolu satır başlıktır).
    public static func split(_ text: String) -> (title: String, body: String) {
        let lines = text.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        guard let first = lines.firstIndex(where: { !$0.trimmingCharacters(in: .whitespaces).isEmpty }) else { return ("", "") }
        let body = lines[(first + 1)...].joined(separator: "\n")
        return (lines[first].trimmingCharacters(in: .whitespaces), body.trimmingCharacters(in: .whitespacesAndNewlines))
    }
}

public struct NotePatch: Sendable, Encodable {
    public var title: String?
    public var body: String?
    public var project: String?
    public var pinned: Bool?

    public init(title: String? = nil, body: String? = nil, project: String? = nil, pinned: Bool? = nil) {
        self.title = title
        self.body = body
        self.project = project
        self.pinned = pinned
    }
}

/// `/api/quicknote` ve `/api/quicknote/preview`
public struct ParsedNote: Sendable, Decodable {
    public let valid: Bool
    public let title: String
    public let body: String
    public let project: ParsedInput.ProjectRef?
    public let tokens: [ParsedInput.Token]
    public let warnings: [String]
}

public struct QuickNoteResult: Sendable, Decodable {
    public let note: Note
    public let parsed: ParsedNote
}

/// `GET /api/views/focus`
public struct FocusView: Sendable, Decodable {
    public let today: String
    public let tasks: [TaskItem]
    public let done: [TaskItem]
}

/// `GET /api/views/week`
public struct WeekView: Sendable, Decodable {
    public struct DayColumn: Sendable, Decodable, Identifiable {
        public let date: String
        public let openCount: Int
        public let doneCount: Int
        /// O günün tüm task'ları (bitenler dahil), `sort_order` sıralı.
        public let tasks: [TaskItem]
        public var id: String { date }

        enum CodingKeys: String, CodingKey {
            case date, tasks
            case openCount = "open_count"
            case doneCount = "done_count"
        }
    }

    public let today: String
    public let start: String
    public let end: String
    public let days: [DayColumn]
    /// Bugünden önceye planlı, bitmemiş task'lar (`start`'tan bağımsız).
    public let overdue: [TaskItem]
}

/// `/api/focus*` yanıtları: aktif task + zamanlayıcı.
public struct ActiveState: Sendable, Decodable {
    public struct State: Sendable, Decodable {
        public let currentTask: String
        public let timerStartedAt: String
        public let timerDuration: Int

        enum CodingKeys: String, CodingKey {
            case currentTask = "current_task"
            case timerStartedAt = "timer_started_at"
            case timerDuration = "timer_duration"
        }
    }

    public let state: State
    public let task: TaskItem?

    /// Zamanlayıcının biteceği an; zamanlayıcı yoksa `nil`. Server tıklamaz —
    /// kalan süre istemcide `timer_started_at + timer_duration`'dan hesaplanır.
    public var timerEnd: Date? {
        guard state.timerDuration > 0, let start = PBDate.parse(state.timerStartedAt) else { return nil }
        return start.addingTimeInterval(TimeInterval(state.timerDuration))
    }

    /// Kalan sürenin oranı (1 → 0); zamanlayıcı yoksa `nil`.
    public func timerFraction(at now: Date) -> Double? {
        guard let end = timerEnd else { return nil }
        return min(max(end.timeIntervalSince(now) / Double(state.timerDuration), 0), 1)
    }
}

/// PocketBase datetime metni: "2026-09-20 16:45:00.000Z" (UTC).
public enum PBDate {
    public static func parse(_ text: String) -> Date? {
        guard !text.isEmpty else { return nil }
        let iso = text.replacingOccurrences(of: " ", with: "T")
        return try? Date(iso, strategy: .iso8601.year().month().day().time(includingFractionalSeconds: true).timeZone(separator: .omitted))
    }
}

/// Hızlı ekleme parse sonucu (`/api/quickadd/preview` ve `/api/quickadd` → `parsed`).
public struct ParsedInput: Sendable, Decodable {
    public struct Token: Sendable, Decodable {
        public enum Kind: String, Sendable {
            case date, due, priority, project, area, description, unknown
        }

        public let kind: Kind
        /// Özgün metindeki UTF-16 ofsetleri → doğrudan `NSRange`.
        public let start: Int
        public let end: Int
        /// Yalnızca proje token'ında anlamlı: eşleşme bulunamadıysa `false`.
        public let resolved: Bool

        enum CodingKeys: String, CodingKey { case type, start, end, value }

        public init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            kind = Kind(rawValue: try c.decode(String.self, forKey: .type)) ?? .unknown
            start = try c.decode(Int.self, forKey: .start)
            end = try c.decode(Int.self, forKey: .end)
            resolved = !(try c.decodeNil(forKey: .value))
        }

        public var range: NSRange { NSRange(location: start, length: end - start) }
    }

    public struct ProjectRef: Sendable, Decodable {
        public let id: String
        public let name: String
    }

    public let literal: Bool
    public let valid: Bool
    public let title: String
    public let scheduledDate: String?
    public let dueDate: String?
    public let priority: Int?
    public let project: ProjectRef?
    public let area: Area?
    public let description: String?
    public let tokens: [Token]
    public let warnings: [String]

    enum CodingKeys: String, CodingKey {
        case literal, valid, title, priority, project, area, description, tokens, warnings
        case scheduledDate = "scheduled_date"
        case dueDate = "due_date"
    }
}

public struct QuickAddResult: Sendable, Decodable {
    public let task: TaskItem
    public let parsed: ParsedInput
}

public struct AuthSession: Sendable, Decodable {
    public struct User: Sendable, Decodable {
        public let id: String
        public let email: String
    }

    public let token: String
    public let record: User
}

/// `PATCH /api/collections/tasks/records/{id}` — yalnızca verilen alanlar gönderilir.
public struct TaskPatch: Sendable, Encodable {
    public var title: String?
    public var details: String?
    public var status: TaskStatus?
    public var priority: Int?
    public var scheduledDate: String?
    public var dueDate: String?
    public var sortOrder: Double?
    /// Proje id'si; `""` bağı kaldırır.
    public var project: String?
    /// `"work"` | `"personal"`; `""` alanı boşaltır (bu yüzden `Area?` değil metin).
    public var area: String?

    public init(title: String? = nil, details: String? = nil, status: TaskStatus? = nil, priority: Int? = nil,
                scheduledDate: String? = nil, dueDate: String? = nil, sortOrder: Double? = nil,
                project: String? = nil, area: String? = nil) {
        self.project = project
        self.area = area
        self.title = title
        self.details = details
        self.status = status
        self.priority = priority
        self.scheduledDate = scheduledDate
        self.dueDate = dueDate
        self.sortOrder = sortOrder
    }

    enum CodingKeys: String, CodingKey {
        case title, status, priority, project, area
        case details = "description"
        case scheduledDate = "scheduled_date"
        case dueDate = "due_date"
        case sortOrder = "sort_order"
    }
}

public enum TriageAction: Sendable {
    case tomorrow
    case date(String)
    case toProject(id: String, date: String?)
    case delete
}
