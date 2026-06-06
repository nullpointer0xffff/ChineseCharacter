import AVFoundation
import Foundation

@MainActor
final class MandarinSpeaker: NSObject, ObservableObject, AVSpeechSynthesizerDelegate {
    @Published private(set) var speakingLiteral: String?

    private let synthesizer = AVSpeechSynthesizer()

    override init() {
        super.init()
        synthesizer.delegate = self
    }

    func speak(_ text: String) {
        synthesizer.stopSpeaking(at: .immediate)

        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = preferredMandarinVoice()
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate * 0.78
        utterance.pitchMultiplier = 1.0
        utterance.volume = 1.0

        speakingLiteral = text
        synthesizer.speak(utterance)
    }

    private func preferredMandarinVoice() -> AVSpeechSynthesisVoice? {
        let voices = AVSpeechSynthesisVoice.speechVoices()
            .filter { $0.language == "zh-CN" }

        return voices.sorted { lhs, rhs in
            score(lhs) > score(rhs)
        }.first ?? AVSpeechSynthesisVoice(language: "zh-CN")
    }

    private func score(_ voice: AVSpeechSynthesisVoice) -> Int {
        var value = voice.quality.rawValue * 10
        if voice.name.localizedCaseInsensitiveContains("Tingting") {
            value += 100
        }
        if voice.identifier.localizedCaseInsensitiveContains("zh_cn") ||
            voice.identifier.localizedCaseInsensitiveContains("mandarin") {
            value += 10
        }
        return value
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        Task { @MainActor in
            speakingLiteral = nil
        }
    }
}
