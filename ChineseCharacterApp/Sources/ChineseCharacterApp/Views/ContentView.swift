import SwiftUI

struct ContentView: View {
    @StateObject private var backendSettings = BackendSettingsStore()
    @StateObject private var deviceIdentity = DeviceIdentityStore()
    @StateObject private var characterStore = CharacterStore()
    @StateObject private var recorder = AudioRecorder()
    @StateObject private var speaker = MandarinSpeaker()

    @State private var learningRequest = LearningRequest()
    @State private var selectedLiteral: String?
    @State private var isProcessing = false
    @State private var errorMessage: String?
    @State private var showingSettings = false
    @State private var recordingDidStart = false
    @State private var isCancelArmed = false
    @State private var statusMessage = "按住说话，松开识别"
    @State private var remainingCredits: Int?

    var body: some View {
        NavigationStack {
            ZStack {
                Color(red: 0.98, green: 0.97, blue: 0.93).ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 22) {
                        header
                        recorderPanel

                        if !learningRequest.transcript.isEmpty {
                            transcriptPanel
                        }

                        if !learningRequest.characters.isEmpty {
                            characterPicker
                            selectedCharacterPanel
                        }
                    }
                    .padding(20)
                }
            }
            .navigationTitle("中文写字")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingSettings = true
                    } label: {
                        Image(systemName: "server.rack")
                    }
                    .accessibilityLabel("设置后端")
                }
            }
            .sheet(isPresented: $showingSettings) {
                SettingsView(backendBaseURL: $backendSettings.baseURL)
                    .presentationDetents([.medium])
            }
            .alert("需要处理一下", isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )) {
                Button("好") { errorMessage = nil }
            } message: {
                Text(errorMessage ?? "")
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("说一句想学的话")
                .font(.system(size: 34, weight: .bold))
                .foregroundStyle(Color(red: 0.12, green: 0.12, blue: 0.10))
            Text("例如：“我想去公园怎么写”。")
                .font(.headline)
                .foregroundStyle(.secondary)
            if let remainingCredits {
                Text("还可以使用 \(remainingCredits) 次")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color(red: 0.10, green: 0.40, blue: 0.36))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var recorderPanel: some View {
        VStack(spacing: 16) {
            recordingStatus

            if isProcessing {
                ProgressView(statusMessage)
                    .frame(maxWidth: .infinity, alignment: .center)
            }

            pressToTalkButton
        }
        .padding(16)
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private var recordingStatus: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: recorder.isRecording ? "waveform.circle.fill" : "mic.circle.fill")
                    .font(.title2)
                    .foregroundStyle(recorder.isRecording ? .red : Color(red: 0.10, green: 0.40, blue: 0.36))

                Text(statusMessage)
                    .font(.headline)
                    .foregroundStyle(isCancelArmed ? .red : .primary)

                Spacer()
            }

            HStack(alignment: .bottom, spacing: 4) {
                ForEach(0..<18, id: \.self) { index in
                    Capsule()
                        .fill(isCancelArmed ? Color.red : Color(red: 0.10, green: 0.40, blue: 0.36))
                        .frame(width: 6, height: barHeight(at: index))
                        .opacity(recorder.isRecording ? 1 : 0.22)
                        .animation(.easeOut(duration: 0.08), value: recorder.level)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 44)
        }
    }

    private var pressToTalkButton: some View {
        let gesture = DragGesture(minimumDistance: 0)
            .onChanged { value in
                guard !isProcessing else { return }
                if !recordingDidStart {
                    recordingDidStart = true
                    isCancelArmed = false
                    statusMessage = "正在录音，上滑取消"
                    Task { await beginRecording() }
                }

                isCancelArmed = value.translation.height < -70
                if recorder.isRecording {
                    statusMessage = isCancelArmed ? "松开手指，取消录音" : "正在录音，上滑取消"
                }
            }
            .onEnded { _ in
                guard recordingDidStart else { return }
                recordingDidStart = false
                Task { await finishRecording(cancelled: isCancelArmed) }
            }

        return ZStack {
            RoundedRectangle(cornerRadius: 8)
                .fill(isCancelArmed ? Color.red : Color(red: 0.10, green: 0.40, blue: 0.36))

            HStack(spacing: 10) {
                Image(systemName: isCancelArmed ? "xmark" : "mic.fill")
                Text(isCancelArmed ? "松开取消" : "按住说话")
            }
            .font(.title3.weight(.semibold))
            .foregroundStyle(.white)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 64)
        .opacity(isProcessing ? 0.45 : 1)
        .gesture(gesture)
        .accessibilityLabel("按住说话")
    }

    private var transcriptPanel: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("听到的是")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(learningRequest.transcript)
                .font(.title3)
                .foregroundStyle(.primary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var characterPicker: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("选择一个字")
                .font(.headline)

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 64), spacing: 12)], spacing: 12) {
                ForEach(Array(learningRequest.characters.enumerated()), id: \.offset) { _, literal in
                    Button {
                        selectedLiteral = literal
                        speaker.speak(literal)
                    } label: {
                        Text(literal)
                            .font(.system(size: 34, weight: .bold))
                            .frame(width: 64, height: 64)
                            .background(selectedLiteral == literal ? Color(red: 0.93, green: 0.77, blue: 0.28) : .white)
                            .foregroundStyle(Color(red: 0.12, green: 0.12, blue: 0.10))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("学习 \(literal)")
                }
            }
        }
    }

    @ViewBuilder
    private var selectedCharacterPanel: some View {
        let literal = selectedLiteral ?? learningRequest.characters.first
        if let literal {
            let info = characterStore.info(for: literal)
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .firstTextBaseline) {
                    Text(info.literal)
                        .font(.system(size: 80, weight: .bold))
                    VStack(alignment: .leading, spacing: 6) {
                        Text(info.pinyin)
                            .font(.title.weight(.semibold))
                        Text(info.pronunciationHint)
                            .font(.body)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button {
                        speaker.speak(info.literal)
                    } label: {
                        Image(systemName: "speaker.wave.2.fill")
                            .font(.title2)
                            .frame(width: 46, height: 46)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Color(red: 0.10, green: 0.40, blue: 0.36))
                    .accessibilityLabel("播放读音")
                }

                StrokeAnimationView(character: info)
                    .frame(maxWidth: .infinity)
                    .aspectRatio(1, contentMode: .fit)

                Text(info.meaning)
                    .font(.body)
                    .foregroundStyle(.secondary)
            }
            .padding(16)
            .background(.white)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .onAppear {
                selectedLiteral = literal
            }
        }
    }

    private func beginRecording() async {
        do {
            guard backendBaseURL() != nil else {
                showingSettings = true
                statusMessage = "请先填写后端地址"
                throw BackendClientError.invalidBaseURL
            }

            learningRequest = LearningRequest()
            selectedLiteral = nil
            try await recorder.start()
        } catch {
            recordingDidStart = false
            isCancelArmed = false
            errorMessage = error.localizedDescription
        }
    }

    private func finishRecording(cancelled: Bool) async {
        if cancelled {
            recorder.cancel()
            isCancelArmed = false
            statusMessage = "已取消，按住重新说"
            return
        }

        guard let url = recorder.stop() else {
            statusMessage = "没有录到声音，请再试一次"
            return
        }

        do {
            try await processRecording(url)
        } catch {
            statusMessage = "识别失败，请再试一次"
            errorMessage = error.localizedDescription
        }
    }

    private func processRecording(_ url: URL) async throws {
        guard let baseURL = backendBaseURL() else {
            showingSettings = true
            statusMessage = "请先填写后端地址"
            throw BackendClientError.invalidBaseURL
        }

        isProcessing = true
        defer { isProcessing = false }

        statusMessage = "正在识别语音..."
        let client = BackendClient(baseURL: baseURL, deviceID: deviceIdentity.deviceID)
        let result = try await client.extractLearningText(audioURL: url)
        remainingCredits = result.remainingCredits

        let transcript = result.transcript.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !transcript.isEmpty else {
            statusMessage = "没有听清楚，请再试一次"
            throw AppError.emptyTranscript
        }

        learningRequest.transcript = transcript
        statusMessage = "正在找出要学的字..."
        let targetText = result.targetText.trimmingCharacters(in: .whitespacesAndNewlines)
        learningRequest.targetText = targetText
        selectedLiteral = learningRequest.characters.first
        statusMessage = learningRequest.characters.isEmpty ? "没有找到汉字，请再说一次" : "按住说话，松开识别"
    }

    private func backendBaseURL() -> URL? {
        let value = backendSettings.baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { return nil }
        return URL(string: value)
    }

    private func barHeight(at index: Int) -> CGFloat {
        let baseline: Double = 0.10
        let wave = 0.35 + 0.65 * abs(sin(Double(index) * 0.75))
        let activeLevel = recorder.isRecording ? max(baseline, recorder.level) : baseline
        return CGFloat(8 + 34 * min(1, activeLevel * wave))
    }
}

private enum AppError: LocalizedError {
    case emptyTranscript

    var errorDescription: String? {
        switch self {
        case .emptyTranscript:
            return "这段录音没有识别出文字，请靠近麦克风再试一次。"
        }
    }
}
