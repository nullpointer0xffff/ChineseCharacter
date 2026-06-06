import Foundation

@MainActor
final class FavoriteCharacterStore: ObservableObject {
    @Published private(set) var favorites: [String] = []

    private let storageKey = "favorite_characters"

    init() {
        favorites = UserDefaults.standard.stringArray(forKey: storageKey) ?? []
    }

    func contains(_ literal: String) -> Bool {
        favorites.contains(literal)
    }

    func toggle(_ literal: String) {
        if favorites.contains(literal) {
            favorites.removeAll { $0 == literal }
        } else {
            favorites.insert(literal, at: 0)
        }
        UserDefaults.standard.set(favorites, forKey: storageKey)
    }
}
