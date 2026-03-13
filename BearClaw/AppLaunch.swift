import Foundation

enum AppLaunch {
    static let pairingPayloadKey = "BEARCLAW_UI_TEST_PAIRING_PAYLOAD"
    static let userDefaultsSuiteKey = "BEARCLAW_UI_TEST_USER_DEFAULTS_SUITE"
    static let inMemoryTokenStoreKey = "BEARCLAW_UI_TEST_IN_MEMORY_TOKEN_STORE"
    static let resetStateKey = "BEARCLAW_UI_TEST_RESET_STATE"

    static func makeSettingsStore(environment: [String: String] = ProcessInfo.processInfo.environment) -> AppSettingsStore {
        let defaults: UserDefaults
        if let suiteName = environment[userDefaultsSuiteKey], !suiteName.isEmpty,
           let suiteDefaults = UserDefaults(suiteName: suiteName) {
            defaults = suiteDefaults
        } else {
            defaults = .standard
        }

        let tokenStore: AuthTokenStore
        if environment[inMemoryTokenStoreKey] == "1" {
            tokenStore = InMemoryAuthTokenStore()
        } else {
            tokenStore = KeychainAuthTokenStore()
        }

        let settings = AppSettingsStore(defaults: defaults, tokenStore: tokenStore)

        if environment[resetStateKey] == "1" {
            settings.reset()
        }

        if let pairingPayload = environment[pairingPayloadKey], !pairingPayload.isEmpty {
            try? settings.applyPairingPayload(pairingPayload)
        }

        return settings
    }
}
