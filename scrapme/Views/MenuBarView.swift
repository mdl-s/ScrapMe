//
//  MenuBarView.swift
//  scrapme
//
//  Created by Michael Slimani on 08/12/2025.
//

import SwiftUI

struct MenuBarView: View {
    @EnvironmentObject var manager: ScrapingManager
    @State private var selectedPeriod: ScrapingManager.ScrapePeriod = .week
    @State private var showingEventsList = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .foregroundStyle(.blue)
                Text("ScrapMe")
                    .font(.headline)
                Spacer()
                StatusBadge(status: manager.status)
            }
            .padding(.bottom, 4)
            
            Divider()
            
            // Period Picker
            HStack {
                Text("Période:")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                Picker("", selection: $selectedPeriod) {
                    ForEach(ScrapingManager.ScrapePeriod.allCases, id: \.self) { period in
                        Text(period.rawValue).tag(period)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 180)
                
                Spacer()
                
                // Current period badge
                Text(manager.lastScrapedPeriod.rawValue)
                    .font(.caption2)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.blue.opacity(0.2))
                    .foregroundStyle(.blue)
                    .clipShape(Capsule())
            }
            
            Divider()
            
            // Stats
            HStack(spacing: 16) {
                StatView(
                    value: "\(manager.events.count)",
                    label: "Événements",
                    icon: "calendar"
                )
                StatView(
                    value: "\(manager.highImpactEvents.count)",
                    label: "High Impact",
                    icon: "exclamationmark.triangle.fill",
                    color: .red
                )
                StatView(
                    value: "\(manager.todayEvents.count)",
                    label: "Aujourd'hui",
                    icon: "sun.max.fill",
                    color: .orange
                )
            }
            
            // View all events button
            Button {
                showingEventsList = true
            } label: {
                HStack {
                    Text("Voir tous les événements")
                    Spacer()
                    Image(systemName: "arrow.up.right.square")
                }
                .font(.caption)
                .foregroundStyle(.blue)
            }
            .buttonStyle(.plain)
            .popover(isPresented: $showingEventsList) {
                EventsListView()
                    .environmentObject(manager)
            }
            
            Divider()
            
            // Today's High Impact Events
            if !manager.todayEvents.filter({ $0.impact == .high }).isEmpty {
                Text("High Impact - Aujourd'hui")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                ForEach(manager.todayEvents.filter { $0.impact == .high }.prefix(5)) { event in
                    EventRow(event: event)
                }
                
                Divider()
            }
            
            // Last Update
            HStack {
                Image(systemName: "clock")
                    .foregroundStyle(.secondary)
                Text("Dernière MàJ: \(manager.formattedLastUpdate)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Divider()
            
            // Actions
            HStack(spacing: 8) {
                Button {
                    Task {
                        await manager.scrapeAndUpdate(period: selectedPeriod)
                    }
                } label: {
                    Label("Actualiser", systemImage: "arrow.clockwise")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(manager.isLoading)
                
                Button {
                    Task {
                        await manager.scrapeOnly(period: selectedPeriod)
                    }
                } label: {
                    Label("Scrape", systemImage: "doc.text.magnifyingglass")
                }
                .buttonStyle(.bordered)
                .disabled(manager.isLoading)
            }
            
            Divider()
            
            // Footer buttons
            HStack {
                SettingsLink {
                    Label("Paramètres", systemImage: "gear")
                }
                .buttonStyle(.plain)
                
                Spacer()
                
                Button {
                    NSApplication.shared.terminate(nil)
                } label: {
                    Label("Quitter", systemImage: "power")
                }
                .buttonStyle(.plain)
                .foregroundStyle(.red)
            }
            .font(.caption)
        }
        .padding()
        .frame(width: 320)
    }
}

// MARK: - Subviews

struct StatusBadge: View {
    let status: ScrapingManager.Status
    
    var body: some View {
        HStack(spacing: 4) {
            if case .scraping = status {
                ProgressView()
                    .scaleEffect(0.5)
                    .frame(width: 12, height: 12)
            } else if case .uploading = status {
                ProgressView()
                    .scaleEffect(0.5)
                    .frame(width: 12, height: 12)
            } else {
                Image(systemName: status.icon)
                    .font(.caption2)
            }
            Text(statusText)
                .font(.caption2)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(backgroundColor.opacity(0.2))
        .foregroundStyle(backgroundColor)
        .clipShape(Capsule())
    }
    
    private var statusText: String {
        switch status {
        case .idle: return "En attente"
        case .scraping: return "Scraping..."
        case .uploading: return "Upload..."
        case .success: return "OK"
        case .error: return "Erreur"
        }
    }
    
    private var backgroundColor: Color {
        switch status {
        case .idle: return .secondary
        case .scraping, .uploading: return .blue
        case .success: return .green
        case .error: return .red
        }
    }
}

struct StatView: View {
    let value: String
    let label: String
    let icon: String
    var color: Color = .blue
    
    var body: some View {
        VStack(spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .foregroundStyle(color)
                Text(value)
                    .font(.title2)
                    .fontWeight(.semibold)
            }
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

struct EventRow: View {
    let event: EconomicEvent
    
    var body: some View {
        HStack {
            Circle()
                .fill(impactColor)
                .frame(width: 8, height: 8)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(event.name)
                    .font(.caption)
                    .lineLimit(1)
                HStack(spacing: 4) {
                    Text(event.currency)
                        .font(.caption2)
                        .fontWeight(.medium)
                        .foregroundStyle(.blue)
                    Text(event.time)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            
            Spacer()
            
            if !event.forecast.isEmpty {
                Text(event.forecast)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
    }
    
    private var impactColor: Color {
        switch event.impact {
        case .high: return .red
        case .medium: return .orange
        case .low: return .yellow
        case .unknown: return .gray
        }
    }
}

#Preview {
    MenuBarView()
        .environmentObject(ScrapingManager.shared)
}
