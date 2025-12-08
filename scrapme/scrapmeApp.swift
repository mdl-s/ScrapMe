//
//  scrapmeApp.swift
//  scrapme
//
//  Created by Michael Slimani on 08/12/2025.
//

import SwiftUI
import ServiceManagement

@main
struct scrapmeApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var manager = ScrapingManager.shared
    
    var body: some Scene {
        // Menu Bar uniquement - pas de fenêtre principale
        MenuBarExtra {
            MenuBarView()
                .environmentObject(manager)
        } label: {
            Label("ScrapMe", systemImage: statusIcon)
        }
        .menuBarExtraStyle(.window)
        
        // Settings window
        Settings {
            SettingsView()
                .environmentObject(manager)
        }
    }
    
    private var statusIcon: String {
        switch manager.status {
        case .idle:
            return "chart.line.uptrend.xyaxis"
        case .scraping, .uploading:
            return "arrow.triangle.2.circlepath"
        case .success:
            return "checkmark.circle.fill"
        case .error:
            return "exclamationmark.triangle.fill"
        }
    }
}

// MARK: - App Delegate
class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Démarrer le manager
        Task { @MainActor in
            ScrapingManager.shared.start()
        }
    }
    
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return false // Ne pas quitter quand on ferme la fenêtre
    }
}
