import Foundation

public struct RealtimeEvent: Sendable, Equatable {
    /// Abonelik adı = koleksiyon: "tasks", "focus_state", "projects"…
    public let topic: String
    /// "create" | "update" | "delete"
    public let action: String
    public let recordID: String
}

/// PocketBase SSE protokolü (docs/api.md → Realtime): bağlan → `PB_CONNECT` ile
/// clientId al → abonelikleri POST et → olayları dinle.
///
/// Akış tek bir bağlantıyı temsil eder; bağlantı koparsa hata fırlatarak ya da
/// sessizce biter. Yeniden bağlanma çağıranın işidir.
public struct RealtimeClient: Sendable {
    private let api: APIClient
    private let session: URLSession

    public init(api: APIClient) {
        self.api = api
        let config = URLSessionConfiguration.default
        // Olay gelmeyen uzun aralıklarda istek zaman aşımına düşmesin.
        config.timeoutIntervalForRequest = 3600
        session = URLSession(configuration: config)
    }

    /// `onConnected`: abonelik kurulduktan sonra çağrılır — kaçan olayları
    /// telafi etmek için tam yenilemenin yapılacağı yer.
    public func events(topics: [String], onConnected: @escaping @Sendable () async -> Void = {}) -> AsyncThrowingStream<RealtimeEvent, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    var request = api.makeRequest("GET", "/api/realtime")
                    request.setValue("text/event-stream", forHTTPHeaderField: "Accept")
                    let (bytes, _) = try await session.bytes(for: request)

                    // `lines` boş satırları atlar; olay sınırı yerine "event:" ardından
                    // gelen "data:" satırı esas alınır (PocketBase hep bu sırayla yollar).
                    var eventName = ""
                    for try await line in bytes.lines {
                        if let value = Self.field("event", in: line) {
                            eventName = value
                        } else if let value = Self.field("data", in: line) {
                            if eventName == "PB_CONNECT" {
                                try await subscribe(clientID: try Self.decode(Connect.self, value).clientId, topics: topics)
                                await onConnected()
                            } else if let payload = try? Self.decode(Payload.self, value) {
                                continuation.yield(RealtimeEvent(topic: eventName, action: payload.action, recordID: payload.record.id))
                            }
                        }
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    private struct Connect: Decodable { let clientId: String }
    private struct Payload: Decodable {
        struct Record: Decodable { let id: String }
        let action: String
        let record: Record
    }
    private struct Subscription: Encodable { let clientId: String; let subscriptions: [String] }

    private func subscribe(clientID: String, topics: [String]) async throws {
        var request = api.makeRequest("POST", "/api/realtime")
        request.httpBody = try JSONEncoder().encode(Subscription(clientId: clientID, subscriptions: topics))
        let (_, response) = try await session.data(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard (200..<300).contains(status) else {
            throw status == 401 ? APIError.unauthorized : APIError.http(status: status, message: "Realtime aboneliği reddedildi.")
        }
    }

    private static func field(_ name: String, in line: String) -> String? {
        guard line.hasPrefix(name + ":") else { return nil }
        return String(line.dropFirst(name.count + 1)).trimmingCharacters(in: .whitespaces)
    }

    private static func decode<T: Decodable>(_ type: T.Type, _ json: String) throws -> T {
        try JSONDecoder().decode(type, from: Data(json.utf8))
    }
}
