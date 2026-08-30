//
//  SingleAppView.swift
//  Geezmo
//
//  Created by Yaroslav Sedyshev on 17.08.2024.
//

import SwiftUI
import WebOSClient
import FirebaseAnalytics

struct SingleAppView: View {
    let app: WebOSResponseApplication
    @ObservedObject var viewModel: MainViewModel

    var body: some View {
        VStack {
            Button(app.title ?? "N/A", action: {
                if let appId = app.id {
                    viewModel.launchApp(id: appId)
                    Analytics.logEvent(AnalyticsEvents.AppsView.appLaunchTapped.rawValue, parameters: ["app_title": app.title ?? "unknown"])
                    if viewModel.preferencesHapticFeedback {
                        UIImpactFeedbackGenerator(style: .rigid).impactOccurred()
                    }
                }
            })
            .buttonStyle(AccentButtonStyle(app: app, viewModel: viewModel))
        }
    }
}

struct AccentButtonStyle: ButtonStyle {
    var app: WebOSResponseApplication
    @ObservedObject var viewModel: MainViewModel
    func makeBody(configuration: Configuration) -> some View {
        VStack {
            TVAppIconView(
                app: app,
                size: (UIScreen.main.bounds.width - 200) / 3,
                viewModel: viewModel
            )
            .scaleEffect(configuration.isPressed ? 1.08 : 1.0)
            
            Text(app.title ?? "N/A")
                .font(.system(size: Globals.smallTitleSize, weight: .bold, design: .rounded))
                .foregroundStyle(configuration.isPressed ? .white : .primary)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal)
        .frame(width: (UIScreen.main.bounds.width - 60) / 3, height: (UIScreen.main.bounds.width - 60) / 3)
        //.background(Color(uiColor: .systemGray5).opacity(0.25))
        .cornerRadius(12)
        .animation(.easeInOut(duration: 0.25), value: configuration.isPressed)
        .onChange(of: configuration.isPressed) {
            if configuration.isPressed {
                if viewModel.preferencesHapticFeedback {
                    UIImpactFeedbackGenerator(style: .soft).impactOccurred()
                }
            }
        }
    }
}

final class TVAppIconLoader: NSObject, ObservableObject, URLSessionDelegate {
    @Published var image: UIImage?

    private lazy var session: URLSession = {
        URLSession(
            configuration: .default,
            delegate: self,
            delegateQueue: nil
        )
    }()

    func load(from urlString: String?) {
        guard
            let urlString,
            let originalURL = URL(string: urlString)
        else {
            return
        }

        loadURL(originalURL) { [weak self] success in
            guard !success else {
                return
            }

            guard
                var components = URLComponents(
                    url: originalURL,
                    resolvingAgainstBaseURL: false
                )
            else {
                return
            }

            components.scheme = "http"
            components.port = 3000

            guard let fallbackURL = components.url else {
                return
            }

            self?.loadURL(fallbackURL) { _ in }
        }
    }

    private func loadURL(
        _ url: URL,
        completion: @escaping (Bool) -> Void
    ) {
        session.dataTask(with: url) { [weak self] data, response, error in
            guard
                error == nil,
                let httpResponse = response as? HTTPURLResponse,
                (200...299).contains(httpResponse.statusCode),
                let data,
                let image = UIImage(data: data)
            else {
                completion(false)
                return
            }

            Task { @MainActor in
                self?.image = image
                completion(true)
            }
        }
        .resume()
    }

    func urlSession(
        _ session: URLSession,
        didReceive challenge: URLAuthenticationChallenge,
        completionHandler: @escaping (
            URLSession.AuthChallengeDisposition,
            URLCredential?
        ) -> Void
    ) {
        guard
            challenge.protectionSpace.authenticationMethod ==
                NSURLAuthenticationMethodServerTrust,
            let serverTrust = challenge.protectionSpace.serverTrust,
            challenge.protectionSpace.host == AppSettings.shared.host
        else {
            completionHandler(.performDefaultHandling, nil)
            return
        }

        completionHandler(
            .useCredential,
            URLCredential(trust: serverTrust)
        )
    }
}

struct TVAppIconView: View {
    let app: WebOSResponseApplication
    let size: CGFloat
    @ObservedObject var viewModel: MainViewModel

    @StateObject private var loader = TVAppIconLoader()

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.22)
                .fill(Color(uiColor: .systemGray5))

            if let image = loader.image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .padding(size * 0.08)
            } else {
                Text(app.title?.toInitials() ?? "?")
                    .font(
                        .system(
                            size: size * 0.30,
                            weight: .bold,
                            design: .rounded
                        )
                    )
                    .foregroundStyle(.primary)
            }
        }
        .frame(width: size, height: size)
        .clipShape(
            RoundedRectangle(cornerRadius: size * 0.22)
        )
        .onAppear {
            guard
                let appId = app.id,
                let iconURL = viewModel.appIconPaths[appId]
            else {
                return
            }
        
            loader.load(from: iconURL)
        }
    }
}
