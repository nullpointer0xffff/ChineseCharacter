import Foundation

@MainActor
final class APIKeyStore: ObservableObject {
    @Published var apiKey: String {
        didSet {
            UserDefaults.standard.set(apiKey, forKey: storageKey)
        }
    }

    private let storageKey = "openai_api_key"

    init() {
        apiKey = UserDefaults.standard.string(forKey: storageKey) ?? ""
    }
}
