//
//  SettingsView.swift
//  scrapme
//
//  Created by Michael Slimani on 08/12/2025.
//

import SwiftUI
import ServiceManagement

struct SettingsView: View {
    @EnvironmentObject var manager: ScrapingManager
    @AppStorage("launchAtLogin") private var launchAtLogin = false
    
    var body: some View {
        TabView {
            GeneralSettingsView(launchAtLogin: $launchAtLogin)
                .environmentObject(manager)
                .tabItem {
                    Label("Général", systemImage: "gear")
                }
            
            AboutView()
                .tabItem {
                    Label("À propos", systemImage: "info.circle")
                }
        }
        .frame(width: 450, height: 300)
    }
}

// MARK: - General Settings
struct GeneralSettingsView: View {
    @EnvironmentObject var manager: ScrapingManager
    @Binding var launchAtLogin: Bool
    
    private let intervals: [(String, TimeInterval)] = [
        ("15 minutes", 900),
        ("30 minutes", 1800),
        ("1 heure", 3600),
        ("2 heures", 7200),
        ("4 heures", 14400)
    ]
    
    var body: some View {
        Form {
            Section {
                Toggle("Démarrer au login", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { _, newValue in
                        setLaunchAtLogin(enabled: newValue)
                    }
                
                Toggle("Mise à jour automatique", isOn: $manager.autoUpdateEnabled)
            }
            
            Section {
                Picker("Intervalle de mise à jour", selection: $manager.updateInterval) {
                    ForEach(intervals, id: \.1) { interval in
                        Text(interval.0).tag(interval.1)
                    }
                }
                .disabled(!manager.autoUpdateEnabled)
            }
            
            Section("Supabase") {
                Toggle("Upload vers Supabase", isOn: $manager.uploadToSupabase)
                Text("Synchronise les événements avec votre base Supabase après chaque scrape.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Section {
                HStack {
                    Text("Dernière mise à jour")
                    Spacer()
                    Text(manager.formattedLastUpdate)
                        .foregroundStyle(.secondary)
                }
                
                HStack {
                    Text("Événements chargés")
                    Spacer()
                    Text("\(manager.events.count)")
                        .foregroundStyle(.secondary)
                }
                
                HStack {
                    Text("Statut")
                    Spacer()
                    Text(manager.status.description)
                        .foregroundStyle(statusColor)
                }
            }
        }
        .formStyle(.grouped)
        .padding()
    }
    
    private var statusColor: Color {
        switch manager.status {
        case .idle: return .secondary
        case .scraping, .uploading: return .blue
        case .success: return .green
        case .error: return .red
        }
    }
    
    private func setLaunchAtLogin(enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            print("[Settings] Error setting launch at login: \(error)")
        }
    }
}

// MARK: - About View
struct AboutView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "chart.line.uptrend.xyaxis")
                .font(.system(size: 60))
                .foregroundStyle(.blue)
            
            Text("ScrapMe")
                .font(.title)
                .fontWeight(.bold)
            
            Text("Version 1.0.0")
                .foregroundStyle(.secondary)
            
            Text("Application de scraping du calendrier économique Forex Factory")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
            
            Divider()
            
            Link(destination: URL(string: "https://www.forexfactory.com/calendar")!) {
                Label("Forex Factory", systemImage: "link")
            }
            
            Spacer()
            
            Text("© 2025 Michael Slimani")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview {
    SettingsView()
        .environmentObject(ScrapingManager.shared)
}
