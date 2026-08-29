//
//  MainView.swift
//  Geezmo
//
//  Created by Yaroslav Sedyshev on 18.07.2024.
//

import SwiftUI
import FirebaseAnalytics

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

    var body: some View {
        HStack(spacing: 14) {
            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: 28)
                    .fill(Color.black.opacity(0.72))

                VStack(spacing: 0) {
                    HStack {
                        Image(systemName: "speaker.wave.2")
                            .font(.system(size: 20, weight: .medium))
                            .foregroundStyle(.white.opacity(0.85))

                        Spacer()
                    }
                    .padding(.top, 18)
                    .padding(.horizontal, 18)

                    Spacer()

                    VStack(spacing: 8) {
                        Image(systemName: "cursorarrow.motionlines")
                            .font(.system(size: 26, weight: .medium))
                            .foregroundStyle(.white.opacity(0.35))

                        Text("Trackpad")
                            .font(.system(size: 18, weight: .semibold, design: .rounded))
                            .foregroundStyle(.white.opacity(0.55))

                        Text("Drag to move • Tap to click")
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .foregroundStyle(.white.opacity(0.28))
                    }

                    Spacer()

                    HStack {
                        Image(systemName: "scope")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundStyle(.white.opacity(0.70))

                        Spacer()
                    }
                    .padding(.bottom, 18)
                    .padding(.horizontal, 18)
                }
            }
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

            RoundedRectangle(cornerRadius: 18)
                .fill(Color.white.opacity(0.22))
                .frame(width: 34)
                .overlay {
                    VStack {
                        Spacer()

                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.black.opacity(0.85))
                            .frame(width: 22, height: 92)

                        Spacer()
                    }
                    .padding(.vertical, 14)
                }
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            let dy = value.translation.height - lastScrollTranslation

                            let scrollMultiplier: CGFloat = 6.0
                            let scrollY = Int(-dy * scrollMultiplier)

                            if scrollY != 0 {
                                viewModel.sendKey(.scroll(dx: 0, dy: scrollY))
                            }

                            lastScrollTranslation = value.translation.height
                        }
                        .onEnded { _ in
                            lastScrollTranslation = 0
                        }
                )
        }
        .frame(height: 260)
        .padding(.horizontal)
    }
}
