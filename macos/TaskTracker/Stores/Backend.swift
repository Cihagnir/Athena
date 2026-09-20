import Foundation
import Observation
import TaskTrackerCore

/// Store'ların sunucuya açılan tek kapısı: güncel `APIClient`'ı tutar ve hataları
/// tek yerde ele alır (401 → oturumu kapat, diğerleri → durum satırında göster).
@Observable
final class Backend {
    private(set) var api: APIClient
    /// Pencerenin altındaki durum satırında gösterilen son hata.
    var lastError: String?
    var onUnauthorized: () -> Void = {}

    init(url: URL, token: String?, apiKey: String) {
        api = APIClient(baseURL: url, token: token, apiKey: apiKey)
    }

    func configure(url: URL, token: String?, apiKey: String) {
        api = APIClient(baseURL: url, token: token, apiKey: apiKey)
    }

    /// İsteği çalıştırır; hata olursa `nil` döner ve hatayı raporlar.
    @discardableResult
    func run<T: Sendable>(_ work: (APIClient) async throws -> T) async -> T? {
        do {
            let result = try await work(api)
            lastError = nil
            return result
        } catch is CancellationError {
            return nil
        } catch APIError.unauthorized {
            onUnauthorized()
            return nil
        } catch {
            lastError = error.localizedDescription
            return nil
        }
    }
}
