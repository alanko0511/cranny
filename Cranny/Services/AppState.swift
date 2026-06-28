import Foundation
import Observation

/// App-wide UI state. Tracks API-key presence (the secret itself stays in Keychain).
@MainActor
@Observable
final class AppState {
    private(set) var hasAPIKey: Bool = false

    init() {
        refreshAPIKeyStatus()
    }

    func refreshAPIKeyStatus() {
        let key = (try? Keychain.read()).flatMap { $0 }
        hasAPIKey = !(key ?? "").isEmpty
    }

    func currentAPIKey() -> String? {
        (try? Keychain.read()).flatMap { $0 }
    }

    func setAPIKey(_ key: String) throws {
        try Keychain.save(key)
        refreshAPIKeyStatus()
    }

    func clearAPIKey() throws {
        try Keychain.delete()
        refreshAPIKeyStatus()
    }
}
