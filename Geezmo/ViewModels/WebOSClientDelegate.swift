//
//  WebOSClientDelegate.swift
//  Geezmo
//
//  Created by Yaroslav Sedyshev on 18.07.2024.
//

import SwiftUI
import WebOSClient

extension MainViewModel: WebOSClientDelegate {
    func didPrompt() {
        Task { @MainActor in
            toast(.prompted)
        }
    }
    
    func didDisplayPin() {
        Task { @MainActor in
            pinPadPresented = true
        }
    }

    func didRegister(with clientKey: String) {
        AppSettings.shared.clientKey = clientKey
        subscribeAll()
        Task { @MainActor in
            withAnimation(.easeInOut(duration: Globals.TimeIntervals.disabled)) {
                isConnected = true
            }
            isToastPresented = false
        }
    }

    func didReceive(_ result: Result<WebOSResponse, Error>) {
        if case .success(let response) = result,
           response.id == Globals.SubscriptionIds.remoteKeyboardRequestId,
           let focus = response.payload?.currentWidget?.focus {
            Task { @MainActor in
                keyboardPresented = focus
                isFocused = focus
            }
        }

        if case .success(let response) = result,
           response.id == Globals.SubscriptionIds.mediaPlaybackRequestId,
           let playState = response.payload?.foregroundAppInfo?.first?.playState {
            Task { @MainActor in
                self.playState = playState
            }
        }
        
        if case .success(let response) = result,
           response.id == Globals.SubscriptionIds.volumeLevelRequestId,
           let muteState = response.payload?.volumeStatus?.muteStatus {
            Task { @MainActor in
                self.isMuted = muteState
                self.session.sendMessage([.muteState: self.isMuted], replyHandler: nil)
            }
        }
        
        if case .success(let response) = result,
           response.id == Globals.SubscriptionIds.powerStateRequestId,
           let screenState = response.payload?.state {
            Task { @MainActor in
                self.isScreenOff = screenState.uppercased().contains("SCREEN OFF")
                self.session.sendMessage([.screenState: self.isScreenOff], replyHandler: nil)
            }
        }
        
        if case .success(let response) = result,
           response.id == Globals.SubscriptionIds.listAppsRequestId {
            guard let applications = response.payload?.applications else {
                return
            }
               
            Task { @MainActor in
                apps = applications.filter { !($0.systemApp ?? false) }
                apps.append(contentsOf: applications.filter { $0.folderPath?.contains("com.webos.app.browser") ?? false })
                loadingAppsFinished = true
            }
        }

        if case .failure(let error) = result {
            print("~err: \(error.localizedDescription)")
        }
        
        if case .failure(let error) = result {
            let errorMessage = error.localizedDescription
            if errorMessage.contains("rejected pairing") || errorMessage.contains("cancelled") {
                connectAndRegister(forcingConnection: true)
            }
        }
    }

func didReceive(jsonResponse: String) {
    guard
        let data = jsonResponse.data(using: .utf8),
        let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
        let id = json["id"] as? String,
        id == Globals.SubscriptionIds.listLaunchPointsRequestId
    else {
        return
    }

    guard
        let payload = json["payload"] as? [String: Any],
        let launchPoints = payload["launchPoints"] as? [[String: Any]]
    else {
        return
    }

    var icons: [String: String] = [:]

    for launchPoint in launchPoints {
        guard
            let appId = launchPoint["id"] as? String,
            let icon = launchPoint["icon"] as? String,
            !icon.isEmpty
        else {
            continue
        }

        icons[appId] = icon
    }

    Task { @MainActor in
        self.appIconPaths = icons
    }
}

func didReceiveNetworkError(_ error: Error?) {
    if let error = error as NSError? {
        if error.code == 57 || error.code == 60 || error.code == 54 {
            disconnect()
        }
    }
}
}
