import AVFoundation
import Foundation

@MainActor
final class AudioRecorder: NSObject, ObservableObject, AVAudioRecorderDelegate {
    @Published private(set) var isRecording = false
    @Published private(set) var latestRecordingURL: URL?
    @Published private(set) var level: Double = 0

    private var recorder: AVAudioRecorder?
    private var meterTimer: Timer?

    func start() async throws {
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playAndRecord, mode: .spokenAudio, options: [.defaultToSpeaker])
        try session.setActive(true)

        if #available(iOS 17.0, *) {
            let granted = await AVAudioApplication.requestRecordPermission()
            guard granted else { throw AudioRecorderError.permissionDenied }
        } else {
            let granted = await withCheckedContinuation { continuation in
                session.requestRecordPermission { continuation.resume(returning: $0) }
            }
            guard granted else { throw AudioRecorderError.permissionDenied }
        }

        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("learning-query-\(UUID().uuidString)")
            .appendingPathExtension("m4a")

        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 16_000,
            AVNumberOfChannelsKey: 1,
            AVEncoderBitRateKey: 32_000,
            AVEncoderAudioQualityKey: AVAudioQuality.medium.rawValue
        ]

        let recorder = try AVAudioRecorder(url: url, settings: settings)
        recorder.delegate = self
        recorder.isMeteringEnabled = true
        recorder.record()
        self.recorder = recorder
        latestRecordingURL = url
        isRecording = true
        startMetering()
    }

    func stop() -> URL? {
        let url = latestRecordingURL
        recorder?.stop()
        recorder = nil
        isRecording = false
        stopMetering()
        return url
    }

    func cancel() {
        recorder?.stop()
        recorder?.deleteRecording()
        recorder = nil
        if let latestRecordingURL {
            try? FileManager.default.removeItem(at: latestRecordingURL)
        }
        latestRecordingURL = nil
        isRecording = false
        stopMetering()
    }

    private func startMetering() {
        stopMetering()
        meterTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self, let recorder = self.recorder else { return }
                recorder.updateMeters()
                let power = recorder.averagePower(forChannel: 0)
                self.level = Self.normalizedLevel(from: power)
            }
        }
    }

    private func stopMetering() {
        meterTimer?.invalidate()
        meterTimer = nil
        level = 0
    }

    private static func normalizedLevel(from power: Float) -> Double {
        let clampedPower = max(-55, min(0, power))
        return pow(10, Double(clampedPower) / 35)
    }
}

enum AudioRecorderError: LocalizedError {
    case permissionDenied

    var errorDescription: String? {
        "请允许麦克风权限后再录音。"
    }
}
