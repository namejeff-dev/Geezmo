import SwiftUI
import WebOSClient

struct TrackpadView: View {
    @ObservedObject var viewModel: MainViewModel

    @State private var lastTranslation: CGSize = .zero

    private var recentApps: [WebOSResponseApplication] {
        viewModel.recentAppIds.compactMap { recentId in
            viewModel.apps.first { $0.id == recentId }
        }
    }

    var body: some View {
        RoundedRectangle(cornerRadius: 24)
            .fill(Color(uiColor: .secondarySystemBackground))
            .overlay {
                VStack(spacing: 10) {
                    Image(systemName: "cursorarrow.motionlines")
                        .font(.system(size: 28, weight: .medium))
                        .foregroundStyle(.secondary)

                    Text("Trackpad")
                        .font(.headline)
                        .foregroundStyle(.secondary)

                    Text("Drag to move • Tap to click")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }
            .frame(height: 260)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        let dx = value.translation.width - lastTranslation.width
                        let dy = value.translation.height - lastTranslation.height

                        let multiplier: CGFloat = 1.6

                        let moveX = Int(dx * multiplier)
                        let moveY = Int(dy * multiplier)

                        if moveX != 0 || moveY != 0 {
                            viewModel.sendKey(.move(dx: moveX, dy: moveY))
                        }

                        lastTranslation = value.translation
                    }
                    .onEnded { value in
                        let distance = hypot(
                            value.translation.width,
                            value.translation.height
                        )

                        if distance < 8 {
                            viewModel.sendKey(.click)
                        }

                        lastTranslation = .zero
                    }
            )
            .padding(.horizontal)
    }
}
