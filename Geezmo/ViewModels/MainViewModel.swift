//
//  MainViewModel.swift
//  Geezmo
//
//  Created by Yaroslav Sedyshev on 18.07.2024.
//

import SwiftUI
import WatchConnectivity
import WebOSClient
import SSDPClient
import FirebaseAnalytics

private enum Constants {
    static let volumeSubscriptionRequestId = "volumeSubscription"
}

final class MainViewModel: NSObject, ObservableObject {
    @Published var isDiscoverDevicesActivityIndicatorShown: Bool = true
    @Published var isAppsLoadingActivityIndicatorShown: Bool = true
    @Published var isAlertPresented: Bool = false
    @Published var alertConfiguration: AlertConfiguration?
    @Published var isToastPresented: Bool = false
    @Published var toastConfiguration: ToastConfiguration?
    @Published var colorButtonsPresented: Bool = false
    @Published var playState: String?
    @Published var deviceDiscoveryFinished: Bool = false
    @Published var keyboardPresented: Bool = false
    @Published var pinPadPresented: Bool = false
    @Published var pairingCode: String? = nil
    @Published var isFocused: Bool = false
    @Published var isMuted: Bool = false
    @Published var isScreenOff: Bool = false
    @Published var isConnected: Bool = false
    @Published var preferencesPresented: Bool = false
    @Published var appListPresented: Bool = false
    @Published var devices = Set<DeviceData>()
    @Published var loadingAppsFinished: Bool = false
    @Published var apps = [WebOSResponseApplication]()
    @Published var navigationPath = [NavigationScreens]()
    @Published var preferencesAlternativeView: Bool = AppSettings.shared.phoneAlternativeView {
        didSet {
            AppSettings.shared.phoneAlternativeView = preferencesAlternativeView
        }
    }
    @Published var preferencesHapticFeedback: Bool = AppSettings.shared.phoneHaptics {
        didSet {
            AppSettings.shared.phoneHaptics = preferencesHapticFeedback
        }
    }
    @Published var recentAppIds: [String] = {
        UserDefaults.standard.stringArray(
            forKey: "recentAppIds"
        ) ?? []
    }()

    @Published var appIconPaths: [String: String] = [:]

    func rememberRecentApp(id: String) {
        var ids = recentAppIds

        ids.removeAll { $0 == id }
        ids.insert(id, at: 0)

        if ids.count > 4 {
            ids = Array(ids.prefix(4))
        }
    
        recentAppIds = ids
    
        UserDefaults.standard.set(
            ids,
            forKey: "recentAppIds"
        )
    }
    
    @Published
    var faqItems: [FAQItem] = [
        FAQItem(question: Strings.FAQ.q1, answer: Strings.FAQ.a1, isExpanded: true),
        FAQItem(question: Strings.FAQ.q2, answer: Strings.FAQ.a2, isExpanded: true),
        FAQItem(question: Strings.FAQ.q3, answer: Strings.FAQ.a3, isExpanded: true),
        FAQItem(question: Strings.FAQ.q4, answer: Strings.FAQ.a4, isExpanded: true),
        FAQItem(question: Strings.FAQ.q5, answer: Strings.FAQ.a5, isExpanded: true),
        FAQItem(question: Strings.FAQ.q6, answer: Strings.FAQ.a6, isExpanded: true),
        FAQItem(question: Strings.FAQ.q7, answer: Strings.FAQ.a7, isExpanded: true),
        FAQItem(question: Strings.FAQ.q8, answer: Strings.FAQ.a8, isExpanded: true),
        FAQItem(question: Strings.FAQ.q9, answer: Strings.FAQ.a9, isExpanded: true),
        FAQItem(question: Strings.FAQ.q10, answer: Strings.FAQ.a10, isExpanded: true),
    ]
    
    var session: WCSession
    private var tv: WebOSClient?
    var ssdpClient = SSDPDiscovery()
    var services: [SSDPService] = []
    
    init(session: WCSession = .default) {
        self.session = session
        super.init()
        ssdpClient.delegate = self
        session.delegate = self
        session.activate()
        connectAndRegister()
    }
    
    func configure(
        url: URL,
        delegate: WebOSClientDelegate?,
        shouldPerformHeartbeat: Bool,
        heartbeatTimeInterval: TimeInterval,
        shouldLogActivity: Bool
    ) {
        tv =
        WebOSClient(
            url: url,
            delegate: delegate,
            shouldPerformHeartbeat: shouldPerformHeartbeat,
            heartbeatTimeInterval: heartbeatTimeInterval,
            shouldLogActivity: shouldLogActivity
        )
    }

    @discardableResult
    func send(_ target: WebOSTarget, id: String? = nil) -> String? {
        var newId: String?

        if let id {
            newId = tv?.send(target, id: id)
        } else {
            newId = tv?.send(target)
        }

        if case .turnOff = target {
            tv?.disconnect()
        }

        return newId
    }
    
    func send(jsonRequest: String) {
        tv?.send(jsonRequest: jsonRequest)
    }

    func sendKey(_ keyTarget: WebOSKeyTarget) {
        tv?.sendKey(keyTarget)
        Analytics.logEvent(AnalyticsEvents.General.buttonTapped.rawValue, parameters: nil)
    }
    
    func sendKey(keyData: Data) {
        tv?.sendKey(keyData: keyData)
        Analytics.logEvent(AnalyticsEvents.General.buttonTapped.rawValue, parameters: nil)
    }
    
    func disconnect() {
        tv?.disconnect()
        Task { @MainActor in
            withAnimation(.easeInOut(duration: Globals.TimeIntervals.disabled)) {
                isConnected = false
                colorButtonsPresented = false
                playState = nil
            }
        }
        Analytics.logEvent(AnalyticsEvents.General.tvDisconnected.rawValue, parameters: nil)
    }
    
    func connect() {
        tv?.connect()
        Analytics.logEvent(AnalyticsEvents.General.tvConnected.rawValue, parameters: nil)
    }

    func toast(_ configuration: ToastConfiguration) {
        Task { @MainActor in
            toastConfiguration = configuration
            isToastPresented = true
        }
    }
    
    func alert(_ configuration: AlertConfiguration) {
        Task { @MainActor in
            alertConfiguration = configuration
            isAlertPresented = true
        }
    }
}
