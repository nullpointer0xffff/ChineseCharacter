import Foundation

enum PinyinFormatter {
    static func pinyin(for text: String) -> String {
        let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedText.isEmpty else { return "" }

        let mutable = NSMutableString(string: trimmedText) as CFMutableString
        CFStringTransform(mutable, nil, kCFStringTransformMandarinLatin, false)
        return (mutable as String)
            .replacingOccurrences(of: "  ", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func pinyin(forCharacter literal: String) -> String {
        pinyin(for: literal).components(separatedBy: .whitespacesAndNewlines).first ?? literal
    }
}
