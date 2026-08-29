import SwiftUI
import WebOSClient

struct TrackpadView: View {
    @ObservedObject var viewModel: MainViewModel

    // Cursor
    @State private var lastTranslation: CGSize = .zero

    // Vertical scroll
    @State private var lastScrollTranslation: CGFloat = 0
    @State private var scrollThumbOffset: CGFloat = 0

    // Horizontal left/right scrubber
    @State private var lastHorizontalScrollTranslation: CGFloat = 0
    @State private var horizontalThumbOffset: CGFloat = 0

    // Recently launched apps
    private var recentApps: [WebOSResponseApplication] {
        viewModel.recentAppIds.compactMap { recentId in
            viewModel.apps.first { $0.id == recentId }
        }
    }

    var body: some View {
        VStack(spacing: 14) {

            // MARK: Recent Apps
            if !recentApps.isEmpty {
                HStack(spacing: 10) {
                    ForEach(recentApps) { app in
                        Button {
                            if let id = app.id {
                                viewModel.launchApp(id: id)

                                if viewModel.preferencesHapticFeedback {
                                    UIImpactFeedbackGenerator(
                                        style: .soft
                                    ).impactOccurred()
                                }
                            }
                        } label: {
                            VStack(spacing: 5) {
                                Circle()
                                    .fill(Color(uiColor: .systemGray5))
                                    .frame(width: 44, height: 44)
                                    .overlay {
                                        Text(app.title?.toInitials() ?? "?")
                                            .font(
                                                .system(
                                                    size: 13,
                                                    weight: .bold,
                                                    design: .rounded
                                                )
                                            )
                                            .foregroundStyle(.primary)
                                    }

                                Text(app.title ?? "App")
                                    .font(
                                        .system(
                                            size: 10,
                                            weight: .medium,
                                            design: .rounded
                                        )
                                    )
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.65)
                            }
                            .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 4)
            }

            // MARK: Trackpad + Vertical Scroll
            HStack(spacing: 12) {

                // MARK: Main Trackpad
                ZStack {
                    RoundedRectangle(cornerRadius: 28)
                        .fill(Color.black.opacity(0.72))

                    VStack(spacing: 8) {
                        Image(systemName: "cursorarrow.motionlines")
                            .font(.system(size: 30, weight: .medium))
                            .foregroundStyle(.white.opacity(0.40))

                        Text("Trackpad")
                            .font(
                                .system(
                                    size: 18,
                                    weight: .semibold,
                                    design: .rounded
                                )
                            )
                            .foregroundStyle(.white.opacity(0.55))

                        Text("Drag to move • Tap to click")
                            .font(
                                .system(
                                    size: 12,
                                    weight: .medium,
                                    design: .rounded
                                )
                            )
                            .foregroundStyle(.white.opacity(0.30))
                    }
                }
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            let dx =
                                value.translation.width -
                                lastTranslation.width

                            let dy =
                                value.translation.height -
                                lastTranslation.height

                            let sensitivity: CGFloat = 1.6

                            let moveX = Int(dx * sensitivity)
                            let moveY = Int(dy * sensitivity)

                            if moveX != 0 || moveY != 0 {
                                viewModel.sendKey(
                                    .move(
                                        dx: moveX,
                                        dy: moveY
                                    )
                                )
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

                                if viewModel.preferencesHapticFeedback {
                                    UIImpactFeedbackGenerator(
                                        style: .light
                                    ).impactOccurred()
                                }
                            }

                            lastTranslation = .zero
                        }
                )

                // MARK: Vertical Scroll
                RoundedRectangle(cornerRadius: 18)
                    .fill(Color.white.opacity(0.18))
                    .frame(width: 38)
                    .overlay {
                        ZStack {
                            VStack {
                                Image(systemName: "chevron.up")
                                    .font(.caption2)
                                    .foregroundStyle(
                                        .white.opacity(0.45)
                                    )

                                Spacer()

                                Image(systemName: "chevron.down")
                                    .font(.caption2)
                                    .foregroundStyle(
                                        .white.opacity(0.45)
                                    )
                            }
                            .padding(.vertical, 12)

                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.black.opacity(0.85))
                                .frame(width: 24, height: 72)
                                .offset(y: scrollThumbOffset)
                        }
                    }
                    .contentShape(Rectangle())
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { value in
                                let dy =
                                    value.translation.height -
                                    lastScrollTranslation

                                let sensitivity: CGFloat = 6

                                // Reversed direction, as you preferred
                                let scrollY =
                                    Int(-dy * sensitivity)

                                if scrollY != 0 {
                                    viewModel.sendKey(
                                        .scroll(
                                            dx: 0,
                                            dy: scrollY
                                        )
                                    )
                                }

                                lastScrollTranslation =
                                    value.translation.height

                                scrollThumbOffset = max(
                                    -70,
                                    min(
                                        70,
                                        value.translation.height * 0.35
                                    )
                                )
                            }
                            .onEnded { _ in
                                lastScrollTranslation = 0

                                withAnimation(
                                    .spring(
                                        response: 0.25,
                                        dampingFraction: 0.7
                                    )
                                ) {
                                    scrollThumbOffset = 0
                                }
                            }
                    )
            }
            .frame(height: 260)

            // MARK: Horizontal Left / Right Scrubber
            RoundedRectangle(cornerRadius: 18)
                .fill(Color.white.opacity(0.18))
                .frame(maxWidth: 260)
                .frame(height: 38)
                .frame(maxWidth: .infinity)
                .overlay {
                    ZStack {
                        HStack {
                            Image(systemName: "chevron.left")
                                .font(.caption2)
                                .foregroundStyle(
                                    .white.opacity(0.45)
                                )

                            Spacer()

                            Image(systemName: "chevron.right")
                                .font(.caption2)
                                .foregroundStyle(
                                    .white.opacity(0.45)
                                )
                        }
                        .padding(.horizontal, 12)

                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.black.opacity(0.85))
                            .frame(width: 72, height: 24)
                            .offset(x: horizontalThumbOffset)
                    }
                }
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            let dx =
                                value.translation.width -
                                lastHorizontalScrollTranslation

                            let threshold: CGFloat = 25

                            if dx >= threshold {
                                viewModel.sendKey(.right)

                                lastHorizontalScrollTranslation =
                                    value.translation.width

                                if viewModel.preferencesHapticFeedback {
                                    UIImpactFeedbackGenerator(
                                        style: .soft
                                    ).impactOccurred()
                                }

                            } else if dx <= -threshold {
                                viewModel.sendKey(.left)

                                lastHorizontalScrollTranslation =
                                    value.translation.width

                                if viewModel.preferencesHapticFeedback {
                                    UIImpactFeedbackGenerator(
                                        style: .soft
                                    ).impactOccurred()
                                }
                            }

                            horizontalThumbOffset = max(
                                -90,
                                min(
                                    90,
                                    value.translation.width * 0.35
                                )
                            )
                        }
                        .onEnded { _ in
                            lastHorizontalScrollTranslation = 0

                            withAnimation(
                                .spring(
                                    response: 0.25,
                                    dampingFraction: 0.7
                                )
                            ) {
                                horizontalThumbOffset = 0
                            }
                        }
                )

            // MARK: Bottom Buttons
            HStack(spacing: 16) {
                trackpadButton(
                    icon: "arrow.uturn.backward",
                    action: {
                        viewModel.sendKey(.back)
                    }
                )

                trackpadButton(
                    icon: "house.fill",
                    action: {
                        viewModel.sendKey(.home)
                    }
                )

                trackpadButton(
                    icon: "gearshape.fill",
                    action: {
                        viewModel.sendKey(.menu)
                    }
                )
            }
        }
        .padding(.horizontal)
        .onAppear {
            if viewModel.isConnected && viewModel.apps.isEmpty {
                viewModel.loadApps()
            }
        }
    }

    private func trackpadButton(
        icon: String,
        action: @escaping () -> Void
    ) -> some View {
        Button {
            action()

            if viewModel.preferencesHapticFeedback {
                UIImpactFeedbackGenerator(
                    style: .medium
                ).impactOccurred()
            }
        } label: {
            Image(systemName: icon)
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(
                    viewModel.isConnected
                    ? Color.accentColor
                    : Color.secondary
                )
                .frame(maxWidth: .infinity)
                .frame(height: 58)
                .background(
                    RoundedRectangle(cornerRadius: 22)
                        .fill(Color.black.opacity(0.72))
                )
        }
        .buttonStyle(.plain)
        .disabled(!viewModel.isConnected)
    }
}
