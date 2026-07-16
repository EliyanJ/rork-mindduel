//
//  CortexApp.swift
//  Cortex
//
//  Created by Rork on July 3, 2026.
//

import SwiftUI
import RevenueCat

@main
struct CortexApp: App {
    @State private var authManager: AuthManager
    @State private var onlineModel: OnlineModel
    @State private var storeViewModel = StoreViewModel()

    init() {
        let auth = AuthManager()
        _authManager = State(initialValue: auth)
        _onlineModel = State(initialValue: OnlineModel(auth: auth))

        #if DEBUG
        Purchases.logLevel = .debug
        Purchases.configure(withAPIKey: Config.EXPO_PUBLIC_REVENUECAT_TEST_API_KEY)
        #else
        Purchases.configure(withAPIKey: Config.EXPO_PUBLIC_REVENUECAT_IOS_API_KEY)
        #endif

        AdsManager.shared.start()
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
