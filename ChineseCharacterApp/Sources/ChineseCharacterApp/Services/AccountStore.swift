import Foundation

@MainActor
final class AccountStore: ObservableObject {
    @Published var email: String {
        didSet {
            UserDefaults.standard.set(email, forKey: emailStorageKey)
        }
    }

    var normalizedEmail: String? {
        let value = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return value.isEmpty ? nil : value
    }

    var isRegistered: Bool {
        normalizedEmail != nil
    }

    private let emailStorageKey = "account_email"

    init() {
        email = UserDefaults.standard.string(forKey: emailStorageKey) ?? ""
    }

    func signOutToGuest() {
        email = ""
    }
}
