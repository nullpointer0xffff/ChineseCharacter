import Foundation

final class HanziWriterAssetStore {
    static let shared = HanziWriterAssetStore()

    private var cachedScript: String?
    private var cachedCharacterData: [String: String] = [:]

    private init() {}

    func script() throws -> String {
        if let cachedScript {
            return cachedScript
        }

        guard let url = Bundle.main.url(
            forResource: "hanzi-writer.min",
            withExtension: "js"
        ) else {
            throw HanziWriterAssetError.missingScript
        }

        let script = try String(contentsOf: url, encoding: .utf8)
        cachedScript = script
        return script
    }

    func characterData(for literal: String) throws -> String {
        if let cached = cachedCharacterData[literal] {
            return cached
        }

        guard let url = Bundle.main.url(
            forResource: literal,
            withExtension: "json"
        ) else {
            throw HanziWriterAssetError.missingCharacterData(literal)
        }

        let data = try String(contentsOf: url, encoding: .utf8)
        cachedCharacterData[literal] = data
        return data
    }
}

enum HanziWriterAssetError: LocalizedError {
    case missingScript
    case missingCharacterData(String)

    var errorDescription: String? {
        switch self {
        case .missingScript:
            return "没有找到 Hanzi Writer 动画脚本。"
        case .missingCharacterData(let literal):
            return "本地笔顺字库里没有“\(literal)”这个字。"
        }
    }
}
