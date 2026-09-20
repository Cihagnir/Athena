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

public struct Project: Identifiable, Sendable, Equatable, Decodable {
    public let id: String
    public var name: String
    public var area: Area
    public var status: String
}

/// `GET /api/views/focus`
public struct FocusView: Sendable, Decodable {
    public let today: String
    public let tasks: [TaskItem]
    public let done: [TaskItem]
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

    public init(title: String? = nil, details: String? = nil, status: TaskStatus? = nil, priority: Int? = nil,
                scheduledDate: String? = nil, dueDate: String? = nil, sortOrder: Double? = nil) {
        self.title = title
        self.details = details
        self.status = status
        self.priority = priority
        self.scheduledDate = scheduledDate
        self.dueDate = dueDate
        self.sortOrder = sortOrder
    }

    enum CodingKeys: String, CodingKey {
        case title, status, priority
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
