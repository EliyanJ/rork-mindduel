//
//  CortexApp.swift
//  Cortex
//
//  Created by Rork on July 3, 2026.
//

import SwiftUI

@main
struct CortexApp: App {
    @State private var authManager: AuthManager
    @State private var onlineModel: OnlineModel
    @State private var storeViewModel = StoreViewModel()

    init() {
        let auth = AuthManager()
        _authManager = State(initialValue: auth)
        _onlineModel = State(initialValue: OnlineModel(auth: auth))

        // Answer telemetry feeds the difficulty calibration pipeline. It needs a
        // bearer token to attribute events, and `AuthManager` is owned here.
        AnswerTelemetry.shared.configure { await auth.validAccessToken() }

        // Version 1.0 ships free: no purchase SDK is linked and no ads load.
        if Monetization.isEnabled {
            AdsManager.shared.start()
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(authManager)
                .environment(onlineModel)
                .environment(storeViewModel)
        }
    }
}
