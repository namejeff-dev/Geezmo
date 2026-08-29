//
//  MainViewModel+.swift
//  Geezmo
//
//  Created by Yaroslav Sedyshev on 18.07.2024.
//

import SwiftUI
import WebOSClient

extension MainViewModel {
    func connectAndRegister(forcingConnection: Bool = false) {
        guard let host = AppSettings.shared.host,
              let url = URL(string: "wss://\(host):3001"),
              !isConnected || forcingConnection 
        else { return }
        
        disconnect()

        configure(
            url: url,
            delegate: self,
            shouldPerformHeartbeat: true,
            heartbeatTimeInterval: 20,
            shouldLogActivity: false
        )

        connect()
        send(
            .register(
                pairingType: .pin,
                clientKey: AppSettings.shared.clientKey
            ),
            id: Globals.SubscriptionIds.registrationRequestId
        )
    }
    
    func isButtonDisabled(_ type: KeyButtonType) -> Bool {
        if type == .powerOff {
            return false
        }
//        if type == .playPause {
//            if (playState == "playing" || playState == "paused") && isConnected {
//                return false
//            } else {
//                return true
//            }
//        }
        return !isConnected
    }
    
    private func requestLocalNetworkAuthorization(_ completion: ((Bool) -> Void)?) {
        let authorization = LocalNetworkAuthorization()
        authorization.requestAuthorization { granted in
            completion?(granted)
        }
    }
    
    func navigateToDeviceDiscoveryViewIfNeeded(_ context: DeviceDiscoveryNavigationContext) {
        requestLocalNetworkAuthorization { [weak self] granted in
            guard let self else { return }
            if granted {
                if context == .fromMainView && AppSettings.shared.host == nil {
                    preferencesPresented = true
                } else if context == .fromPreferences && AppSettings.shared.host == nil {
                    DispatchQueue.main.asyncAfter(deadline: .now() + Globals.TimeIntervals.minimal) { [weak self] in
                        guard let self else { return }
                        navigationPath.append(.discover)
                    }
                }
            } else {
                if context == .fromMainView {
                    alert(.multicastPermissionsDenied)
                }
            }
        }
    }

    func handleScenePhase(_ scenePhase: ScenePhase) {
        switch scenePhase {
        case .active: connectAndRegister(forcingConnection: true)
        case .background, .inactive: disconnect()
        default: break
        }
    }

    func discoverDevices() {
        deviceDiscoveryFinished = false
        devices.removeAll()
        ssdpClient.discoverService()
    }
    
    func loadApps() {
        loadingAppsFinished = false
        apps.removeAll()
        send(.listApps, id: Globals.SubscriptionIds.listAppsRequestId)
    }
    
    func launchApp(id: String) {
        send(.launchApp(appId: id, contentId: nil, params: nil))
        appListPresented = false
    }

    func subscribeAll() {
        send(
            .registerRemoteKeyboard,
            id: Globals.SubscriptionIds.remoteKeyboardRequestId
        )
        send(
            .getForegroundAppMediaStatus(subscribe: true),
            id: Globals.SubscriptionIds.mediaPlaybackRequestId
        )
        send(
            .getVolume(subscribe: true),
            id: Globals.SubscriptionIds.volumeLevelRequestId
        )
        send(
            .getPowerState(subscribe: true),
            id: Globals.SubscriptionIds.powerStateRequestId
        )
    }
    
    func showConnectionStatus() {
        toast(isConnected ? .connected : .disconnected)
    }
    
    func isCurrentLanguageKazakh() -> Bool {
        if let currentLanguage = Locale.preferredLanguages.first {
            return currentLanguage.hasPrefix("kk")
        }
        return false
    }
    
    func pairDiscoveredDevice(with device: DeviceData) {
        disconnect()
        AppSettings.shared.deviceName = device.name
        AppSettings.shared.host = device.host
        AppSettings.shared.mac = device.mac
        AppSettings.shared.clientKey = nil
        preferencesPresented = false
        connectAndRegister(forcingConnection: true)
    }

    func resetConnectionData() {
        disconnect()
        AppSettings.shared.host = nil
        AppSettings.shared.clientKey = nil
        preferencesPresented = false
        DispatchQueue.main.asyncAfter(deadline: .now() + Globals.TimeIntervals.medium) { [weak self] in
            guard let self else { return }
            preferencesPresented = true
        }
    }

    func setHostManually(
        host: String,
        mac: String? = nil
    ) {
        disconnect()
    
        let cleanHost =
            host.trimmingCharacters(in: .whitespacesAndNewlines)
    
        AppSettings.shared.host = cleanHost
    
        if let mac {
            let cleanMac =
                mac.trimmingCharacters(
                    in: .whitespacesAndNewlines
                )
    
            if !cleanMac.isEmpty {
                AppSettings.shared.mac =
                    cleanMac.uppercased()
            }
        }
    
        AppSettings.shared.clientKey = nil
        preferencesPresented = false
    
        connectAndRegister(forcingConnection: true)
    }
    
    func powerOnOrOff() {
        if isConnected {
            send(.turnOff)
            toast(.powerOff)
            disconnect()
        } else {
            wakeMeUp()
        }
    }
    
    func wakeMeUp() {
        guard let host = AppSettings.shared.host,
              let mac = AppSettings.shared.mac else {
            return
        }
        WakeOnLANService
            .shared
            .wakeDevice(at: host, macAddress: mac) { [weak self] result in
                guard let self else { return }
                if case .failure(let error) = result {
                    let alertConfiguration =
                    AlertConfiguration(
                        title: Strings.General.error,
                        message: error.localizedDescription,
                        primaryButton: .cancel(),
                        secondaryButton: nil
                    )
                    alert(alertConfiguration)
                    return
                }
                
                connectAndRegister(forcingConnection: true)
                toast(.powerOn)
            }
    }
}
