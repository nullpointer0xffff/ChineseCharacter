import Foundation

@MainActor
final class BackendSettingsStore: ObservableObject {
    @Published var baseURL: String {
        didSet {
            UserDefaults.standard.set(baseURL, forKey: storageKey)
        }
    }

    private let storageKey = "backend_base_url"

    init() {
        baseURL = UserDefaults.standard.string(forKey: storageKey) ?? ""
    }
}
