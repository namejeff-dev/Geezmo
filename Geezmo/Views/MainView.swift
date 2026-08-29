//
//  MainView.swift
//  Geezmo
//
//  Created by Yaroslav Sedyshev on 18.07.2024.
//

import SwiftUI
import FirebaseAnalytics
import WebOSClient

struct MainView: View {
    @Environment(\.scenePhase) var scenePhase
    @ObservedObject var viewModel: MainViewModel
    @State private var trackpadMode = false

    var body: some View {
        NavigationStack {
            ScrollView([], showsIndicators: false) {
                VStack {
                    Spacer()

                    Picker("", selection: $trackpadMode) {
                        Text("Remote").tag(false)
                        Text("Trackpad").tag(true)
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)
                    .padding(.bottom, 12)
                
                    if trackpadMode {
                        TrackpadView(viewModel: viewModel)
                    } else {
                        if viewModel.preferencesAlternativeView {
                            if viewModel.colorButtonsPresented {
                                ButtonGroupColorAlternativeView()
                                    .environmentObject(viewModel)
                            } else {
                                ButtonGroupDefaultAlternativeView()
                                    .environmentObject(viewModel)
                            }
                        } else {
                            if viewModel.colorButtonsPresented {
                                ButtonGroupColorView()
                                    .environmentObject(viewModel)
                            } else {
                                ButtonGroupDefaultView()
                                    .environmentObject(viewModel)
                            }
                        }
                    }
                
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            }
            .ignoresSafeArea(.keyboard)
            .background(Color(uiColor: .systemGray6))
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    HStack(spacing: 5) {
                        Text(Strings.General.shortAppName)
                            .font(.system(size: Globals.smallTitleSize, weight: .bold, design: .rounded))
                            .foregroundColor(.accent)
                    }
                    .padding(.leading, Globals.iconPadding)
                    .padding(.top, 10)
                }
                
                ToolbarItem(placement: .topBarTrailing) {
                    Image(systemName: "circle.grid.2x2.fill")
                        .font(.system(size: Globals.iconSize, weight: .bold, design: .rounded))
                        .foregroundColor(viewModel.isConnected ? .secondary : Color(uiColor: .tertiaryLabel))
                        .padding(.trailing, Globals.iconPadding)
                        .padding(.top, 10)
                        .onTapGesture {
                            viewModel.appListPresented = true
                            if viewModel.preferencesHapticFeedback {
                                UIImpactFeedbackGenerator(style: .rigid).impactOccurred()
                            }
                        }
                        .disabled(!viewModel.isConnected)
                }
                
                ToolbarItem(placement: .topBarTrailing) {
                    Image(systemName: "gearshape.fill")
                        .font(.system(size: Globals.iconSize, weight: .bold, design: .rounded))
                        .foregroundColor(.secondary)
                        .padding(.trailing, Globals.iconPadding)
                        .padding(.top, 10)
                        .onTapGesture {
                            viewModel.preferencesPresented = true
                            if viewModel.preferencesHapticFeedback {
                                UIImpactFeedbackGenerator(style: .rigid).impactOccurred()
                            }
                        }
                }
            }
            .alert(isPresented: $viewModel.isAlertPresented) {
                if viewModel.alertConfiguration?.secondaryButton != nil {
                    Alert(
                        title: Text(viewModel.alertConfiguration?.title ?? ""),
                        message: Text(viewModel.alertConfiguration?.message ?? ""),
                        primaryButton: viewModel.alertConfiguration?.primaryButton ?? .cancel(),
                        secondaryButton: viewModel.alertConfiguration?.secondaryButton ?? .cancel()
                    )
                } else {
                    Alert(
                        title: Text(viewModel.alertConfiguration?.title ?? ""),
                        message: Text(viewModel.alertConfiguration?.message ?? ""),
                        dismissButton: viewModel.alertConfiguration?.primaryButton ?? .cancel()
                    )
                }
            }
            .sheet(
                isPresented: $viewModel.preferencesPresented,
                onDismiss: {
                    viewModel.navigationPath.removeAll()
                }, content: {
                    PreferencesView(viewModel: viewModel)
                        .presentationDragIndicator(.visible)
                        .presentationCornerRadius(24)
                }
            )
            .sheet(
                isPresented: $viewModel.appListPresented,
                onDismiss: {
                    viewModel.navigationPath.removeAll()
                }, content: {
                    AppsView(viewModel: viewModel)
                        .presentationDragIndicator(.visible)
                        .presentationCornerRadius(24)
                }
            )
            .sheet(
                isPresented: $viewModel.keyboardPresented,
                onDismiss: {
                    //if viewModel.isFocused { viewModel.sendKey(.back) }
                },
                content: {
                    KeyboardView(showModal: $viewModel.keyboardPresented, viewModel: viewModel)
                        .presentationDetents([.height(55)])
                        .presentationDragIndicator(.visible)
                        .presentationCornerRadius(12)
                }
            )
            .sheet(
                isPresented: $viewModel.pinPadPresented,
                onDismiss: {
                    if let pairingCode = viewModel.pairingCode, pairingCode.count == 8 {
                        viewModel.send(.setPin(pairingCode))
                    } else {
                        DispatchQueue.main.asyncAfter(deadline: .now() + Globals.TimeIntervals.medium) {
                            viewModel.pinPadPresented = true
                        }
                    }
                },
                content: {
                    PinPadView(showModal: $viewModel.pinPadPresented, viewModel: viewModel)
                        .presentationDetents([.height(115)])
                        .presentationDragIndicator(.visible)
                        .presentationCornerRadius(24)
                }
            )
            .sheet(
                isPresented: $viewModel.isToastPresented,
                onDismiss: {
                    if viewModel.toastConfiguration == .prompted && viewModel.isConnected {
                        viewModel.toast(.promptAccepted)
                    }
                },
                content: {
                    ToastSheetView(configuration: viewModel.toastConfiguration!, viewModel: viewModel)
                        .presentationDetents([.height(175)])
                        .presentationDragIndicator(.visible)
                        .presentationCornerRadius(24)
                        .onTapGesture {
                            guard viewModel.toastConfiguration?.closeOnTap == true else {
                                return
                            }
                            viewModel.isToastPresented = false
                        }
                }
            )
            .onChange(of: scenePhase) {
                viewModel.handleScenePhase(scenePhase)
            }
            .onAppear {
                viewModel.navigateToDeviceDiscoveryViewIfNeeded(.fromMainView)
                Analytics.logEvent(AnalyticsEvents.MainView.mainViewStarted.rawValue, parameters: nil)
            }
        }
    }
}

struct TrackpadView: View {
    @ObservedObject var viewModel: MainViewModel

    @State private var lastTranslation: CGSize = .zero
    @State private var lastScrollTranslation: CGFloat = 0
    @State private var scrollThumbOffset: CGFloat = 0
    @State private var lastHorizontalScrollTranslation: CGFloat = 0
    @State private var horizontalThumbOffset: CGFloat = 0

    var body: some View {
        VStack(spacing: 18) {
            HStack(spacing: 12) {

                // MARK: Trackpad
                ZStack {
                    RoundedRectangle(cornerRadius: 28)
                        .fill(Color.black.opacity(0.72))

                    VStack(spacing: 8) {
                        Image(systemName: "cursorarrow.motionlines")
                            .font(.system(size: 30, weight: .medium))
                            .foregroundStyle(.white.opacity(0.40))

                        Text("Trackpad")
                            .font(.system(
                                size: 18,
                                weight: .semibold,
                                design: .rounded
                            ))
                            .foregroundStyle(.white.opacity(0.55))

                        Text("Drag to move • Tap to click")
                            .font(.system(
                                size: 12,
                                weight: .medium,
                                design: .rounded
                            ))
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
                                    .move(dx: moveX, dy: moveY)
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

                // MARK: Scroll strip
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

                                let scrollY =
                                    Int(-dy * sensitivity)

                                if scrollY != 0 {
                                    viewModel.sendKey(
                                        .scroll(dx: 0, dy: scrollY)
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
            .frame(height: 280)
            
            // MARKL: Horizontal Scroll
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
                                .foregroundStyle(.white.opacity(0.45))
            
                            Spacer()
            
                            Image(systemName: "chevron.right")
                                .font(.caption2)
                                .foregroundStyle(.white.opacity(0.45))
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
                            } else if dx <= -threshold {
                                viewModel.sendKey(.left)
                                lastHorizontalScrollTranslation =
                                    value.translation.width
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

            // MARK: Bottom buttons
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
                .frame(height: 64)
                .background(
                    RoundedRectangle(cornerRadius: 22)
                        .fill(Color.black.opacity(0.72))
                )
        }
        .buttonStyle(.plain)
        .disabled(!viewModel.isConnected)
    }
}
