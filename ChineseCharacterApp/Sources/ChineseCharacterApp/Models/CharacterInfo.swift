import Foundation

struct CharacterInfo: Codable, Identifiable, Hashable {
    var id: String { literal }

    let literal: String
    let pinyin: String
    let pronunciationHint: String
    let meaning: String
    let strokes: [StrokeSegment]
}

struct StrokeSegment: Codable, Hashable {
    let points: [StrokePoint]
}

struct StrokePoint: Codable, Hashable {
    let x: Double
    let y: Double
}

extension CharacterInfo {
    static func fallback(for literal: String) -> CharacterInfo {
        CharacterInfo(
            literal: literal,
            pinyin: "待补充",
            pronunciationHint: "普通话读音待补充",
            meaning: "本地字库里还没有这个字。",
            strokes: StrokeSegment.placeholder
        )
    }
}

extension StrokeSegment {
    static let placeholder: [StrokeSegment] = [
        StrokeSegment(points: [
            StrokePoint(x: 0.22, y: 0.22),
            StrokePoint(x: 0.78, y: 0.22)
        ]),
        StrokeSegment(points: [
            StrokePoint(x: 0.50, y: 0.16),
            StrokePoint(x: 0.50, y: 0.84)
        ]),
        StrokeSegment(points: [
            StrokePoint(x: 0.25, y: 0.62),
            StrokePoint(x: 0.75, y: 0.62)
        ])
    ]
}
