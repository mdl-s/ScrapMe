//
//  EventsListView.swift
//  scrapme
//
//  Created by Michael Slimani on 08/12/2025.
//

import SwiftUI

struct EventsListView: View {
    @EnvironmentObject var manager: ScrapingManager
    @State private var searchText = ""
    @State private var filterImpact: EconomicEvent.Impact?
    @State private var filterCurrency: String?
    
    var body: some View {
        VStack(spacing: 0) {
            // Header avec infos
            headerView
            
            Divider()
            
            // Filters
            filtersView
            
            Divider()
            
            // Events list
            if filteredEvents.isEmpty {
                emptyView
            } else {
                eventsList
            }
        }
        .frame(width: 400, height: 500)
    }
    
    // MARK: - Header
    private var headerView: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Image(systemName: "calendar")
                        .foregroundStyle(.blue)
                    Text("Événements scrapés")
                        .font(.headline)
                }
                
                HStack(spacing: 12) {
                    Label("\(manager.events.count) total", systemImage: "list.bullet")
                    Label(manager.lastScrapedPeriod.rawValue, systemImage: "clock")
                        .foregroundStyle(.blue)
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            // Refresh button
            Button {
                Task {
                    await manager.scrapeOnly(period: manager.lastScrapedPeriod)
                }
            } label: {
                Image(systemName: "arrow.clockwise")
            }
            .disabled(manager.isLoading)
        }
        .padding()
    }
    
    // MARK: - Filters
    private var filtersView: some View {
        HStack(spacing: 12) {
            // Search
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField("Rechercher...", text: $searchText)
                    .textFieldStyle(.plain)
            }
            .padding(6)
            .background(Color.secondary.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 6))
            
            // Impact filter
            Picker("Impact", selection: $filterImpact) {
                Text("Tous").tag(nil as EconomicEvent.Impact?)
                ForEach(EconomicEvent.Impact.allCases, id: \.self) { impact in
                    HStack {
                        Circle()
                            .fill(impactColor(impact))
                            .frame(width: 8, height: 8)
                        Text(impact.rawValue)
                    }
                    .tag(impact as EconomicEvent.Impact?)
                }
            }
            .pickerStyle(.menu)
            .frame(width: 100)
            
            // Currency filter
            Picker("Devise", selection: $filterCurrency) {
                Text("Toutes").tag(nil as String?)
                ForEach(availableCurrencies, id: \.self) { currency in
                    Text(currency).tag(currency as String?)
                }
            }
            .pickerStyle(.menu)
            .frame(width: 80)
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
    }
    
    // MARK: - Events List
    private var eventsList: some View {
        ScrollView {
            LazyVStack(spacing: 1) {
                ForEach(groupedEvents.keys.sorted(), id: \.self) { date in
                    Section {
                        ForEach(groupedEvents[date] ?? []) { event in
                            EventDetailRow(event: event)
                        }
                    } header: {
                        HStack {
                            Text(date)
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text("\(groupedEvents[date]?.count ?? 0) événements")
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }
                        .padding(.horizontal)
                        .padding(.vertical, 6)
                        .background(Color.secondary.opacity(0.05))
                    }
                }
            }
        }
    }
    
    // MARK: - Empty View
    private var emptyView: some View {
        VStack(spacing: 12) {
            Image(systemName: "calendar.badge.exclamationmark")
                .font(.system(size: 40))
                .foregroundStyle(.secondary)
            Text("Aucun événement")
                .font(.headline)
            Text("Essayez de modifier les filtres ou de rafraîchir")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Helpers
    private var filteredEvents: [EconomicEvent] {
        manager.events.filter { event in
            // Search filter
            let matchesSearch = searchText.isEmpty ||
                event.name.localizedCaseInsensitiveContains(searchText) ||
                event.currency.localizedCaseInsensitiveContains(searchText)
            
            // Impact filter
            let matchesImpact = filterImpact == nil || event.impact == filterImpact
            
            // Currency filter
            let matchesCurrency = filterCurrency == nil || event.currency == filterCurrency
            
            return matchesSearch && matchesImpact && matchesCurrency
        }
    }
    
    private var groupedEvents: [String: [EconomicEvent]] {
        Dictionary(grouping: filteredEvents, by: { $0.date })
    }
    
    private var availableCurrencies: [String] {
        Array(Set(manager.events.map { $0.currency })).sorted()
    }
    
    private func impactColor(_ impact: EconomicEvent.Impact) -> Color {
        switch impact {
        case .high: return .red
        case .medium: return .orange
        case .low: return .yellow
        case .unknown: return .gray
        }
    }
}

// MARK: - Event Detail Row
struct EventDetailRow: View {
    let event: EconomicEvent
    @State private var isHovered = false
    
    var body: some View {
        HStack(spacing: 12) {
            // Impact indicator
            Circle()
                .fill(impactColor)
                .frame(width: 10, height: 10)
            
            // Time
            Text(event.time)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundStyle(.secondary)
                .frame(width: 50, alignment: .leading)
            
            // Currency
            Text(event.currency)
                .font(.caption)
                .fontWeight(.bold)
                .foregroundStyle(.blue)
                .frame(width: 35)
            
            // Event name
            Text(event.name)
                .font(.caption)
                .lineLimit(1)
            
            Spacer()
            
            // Values
            HStack(spacing: 8) {
                if !event.actual.isEmpty {
                    ValueBadge(label: "A", value: event.actual, color: .green)
                }
                if !event.forecast.isEmpty {
                    ValueBadge(label: "F", value: event.forecast, color: .blue)
                }
                if !event.previous.isEmpty {
                    ValueBadge(label: "P", value: event.previous, color: .secondary)
                }
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(isHovered ? Color.secondary.opacity(0.1) : Color.clear)
        .onHover { hovering in
            isHovered = hovering
        }
        .onTapGesture {
            if let url = URL(string: event.detailUrl) {
                NSWorkspace.shared.open(url)
            }
        }
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

struct ValueBadge: View {
    let label: String
    let value: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 2) {
            Text(label)
                .font(.system(size: 8, weight: .bold))
                .foregroundStyle(color)
            Text(value)
                .font(.system(size: 10))
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 2)
        .background(color.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 3))
    }
}

#Preview {
    EventsListView()
        .environmentObject(ScrapingManager.shared)
}
