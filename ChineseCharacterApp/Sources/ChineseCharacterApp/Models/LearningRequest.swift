import Foundation

struct LearningRequest: Equatable {
    var transcript: String = ""
    var targetText: String = ""

    var characters: [String] {
        targetText.map(String.init).filter { character in
            character.range(of: #"\p{Han}"#, options: .regularExpression) != nil
        }
    }
}
