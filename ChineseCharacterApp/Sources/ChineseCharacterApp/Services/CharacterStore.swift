import Foundation

@MainActor
final class CharacterStore: ObservableObject {
    @Published private(set) var charactersByLiteral: [String: CharacterInfo] = [:]

    init() {
        load()
    }

    func info(for literal: String) -> CharacterInfo {
        charactersByLiteral[literal] ?? CharacterInfo.fallback(for: literal)
    }

    private func load() {
        guard let url = Bundle.main.url(forResource: "CharacterData", withExtension: "json") else {
            return
        }

        do {
            let data = try Data(contentsOf: url)
            let characters = try JSONDecoder().decode([CharacterInfo].self, from: data)
            charactersByLiteral = Dictionary(uniqueKeysWithValues: characters.map { ($0.literal, $0) })
        } catch {
            assertionFailure("Failed to load CharacterData.json: \(error)")
        }
    }
}
