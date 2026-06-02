import SwiftUI

struct StrokeAnimationView: View {
    let character: CharacterInfo

    @State private var replayID = 0

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(red: 0.98, green: 0.97, blue: 0.93))

            HanziWriterAnimationView(literal: character.literal, reloadID: replayID)
                .padding(10)

            VStack {
                Spacer()
                HStack {
                    Spacer()
                    Button {
                        replayID += 1
                    } label: {
                        Image(systemName: "arrow.clockwise")
                            .frame(width: 34, height: 34)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Color(red: 0.10, green: 0.40, blue: 0.36))
                    .accessibilityLabel("重新播放笔顺")
                }
                .padding(12)
            }
        }
    }
}
