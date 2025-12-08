//
//  ScrapingManager.swift
//  scrapme
//
//  Created by Michael Slimani on 08/12/2025.
//

import Foundation
import Combine

@MainActor
final class ScrapingManager: ObservableObject {
    static let shared = ScrapingManager()
    
    // MARK: - Published Properties
    @Published private(set) var events: [EconomicEvent] = []
    @Published private(set) var lastUpdate: Date?
    @Published private(set) var isLoading = false
    @Published private(set) var error: String?
    @Published private(set) var status: Status = .idle
    @Published private(set) var lastScrapedPeriod: ScrapePeriod = .week
    
    enum ScrapePeriod: String, CaseIterable {
        case today = "Aujourd'hui"
        case week = "Semaine"
        
        var apiValue: ForexFactoryScraper.Period {
            switch self {
            case .today: return .today
            case .week: return .week
            }
        }
    }
    
    // MARK: - Settings
    @Published var autoUpdateEnabled = true {
        didSet {
            UserDefaults.standard.set(autoUpdateEnabled, forKey: "autoUpdateEnabled")
            if autoUpdateEnabled {
                startAutoUpdate()
            } else {
                stopAutoUpdate()
            }
        }
    }
    
    @Published var updateInterval: TimeInterval = 3600 { // 1 heure par défaut
        didSet {
            UserDefaults.standard.set(updateInterval, forKey: "updateInterval")
            if autoUpdateEnabled {
                startAutoUpdate()
            }
        }
    }
    
    @Published var uploadToSupabase = true { // Activé par défaut - upload direct vers Supabase
        didSet {
            UserDefaults.standard.set(uploadToSupabase, forKey: "uploadToSupabase")
        }
    }
    
    // MARK: - Private Properties
    private let scraper = ForexFactoryScraper()
    private let supabase = SupabaseService()
    private var updateTimer: Timer?
    
    enum Status: Equatable {
        case idle
        case scraping
        case uploading
        case success
        case error(String)
        
        var description: String {
            switch self {
            case .idle: return "En attente"
            case .scraping: return "Scraping en cours..."
            case .uploading: return "Mise à jour Supabase..."
            case .success: return "Succès"
            case .error(let msg): return "Erreur: \(msg)"
            }
        }
        
        var icon: String {
            switch self {
            case .idle: return "circle"
            case .scraping, .uploading: return "arrow.triangle.2.circlepath"
            case .success: return "checkmark.circle.fill"
            case .error: return "exclamationmark.triangle.fill"
            }
        }
    }
    
    // MARK: - Initialization
    private init() {
        loadSettings()
    }
    
    private func loadSettings() {
        // Auto-update: default true si jamais défini
        if UserDefaults.standard.object(forKey: "autoUpdateEnabled") == nil {
            autoUpdateEnabled = true
        } else {
            autoUpdateEnabled = UserDefaults.standard.bool(forKey: "autoUpdateEnabled")
        }
        
        let savedInterval = UserDefaults.standard.double(forKey: "updateInterval")
        updateInterval = savedInterval > 0 ? savedInterval : 3600
        
        // Upload Supabase: default true si jamais défini
        if UserDefaults.standard.object(forKey: "uploadToSupabase") == nil {
            uploadToSupabase = true
        } else {
            uploadToSupabase = UserDefaults.standard.bool(forKey: "uploadToSupabase")
        }
    }
    
    // MARK: - Public Methods
    func start() {
        if autoUpdateEnabled {
            startAutoUpdate()
        }
        
        // Premier scrape au démarrage
        Task {
            await scrapeAndUpdate()
        }
    }
    
    func scrapeAndUpdate(period: ScrapePeriod = .week) async {
        guard !isLoading else { return }
        
        isLoading = true
        error = nil
        status = .scraping
        lastScrapedPeriod = period
        
        do {
            // 1. Scrape Forex Factory
            let scrapedEvents = try await scraper.scrapeCalendar(period: period.apiValue)
            events = scrapedEvents
            
            print("[Manager] Scraped \(scrapedEvents.count) events")
            
            // 2. Upload direct vers Supabase
            if uploadToSupabase {
                status = .uploading
                try await supabase.uploadEvents(scrapedEvents)
            }
            
            // 3. Success
            lastUpdate = Date()
            status = .success
            error = nil
            
            print("[Manager] Update complete")
            
            // Reset status after 5 seconds
            try? await Task.sleep(nanoseconds: 5_000_000_000)
            if case .success = status {
                status = .idle
            }
            
        } catch {
            self.error = error.localizedDescription
            status = .error(error.localizedDescription)
            print("[Manager] Error: \(error)")
        }
        
        isLoading = false
    }
    
    func scrapeOnly(period: ScrapePeriod = .week) async {
        guard !isLoading else { return }
        
        isLoading = true
        error = nil
        status = .scraping
        lastScrapedPeriod = period
        
        do {
            let scrapedEvents = try await scraper.scrapeCalendar(period: period.apiValue)
            events = scrapedEvents
            lastUpdate = Date()
            status = .success
            
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            if case .success = status {
                status = .idle
            }
        } catch {
            self.error = error.localizedDescription
            status = .error(error.localizedDescription)
        }
        
        isLoading = false
    }
    
    // MARK: - Auto Update
    private func startAutoUpdate() {
        stopAutoUpdate()
        
        updateTimer = Timer.scheduledTimer(withTimeInterval: updateInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                await self?.scrapeAndUpdate()
            }
        }
        
        print("[Manager] Auto-update started (interval: \(updateInterval)s)")
    }
    
    private func stopAutoUpdate() {
        updateTimer?.invalidate()
        updateTimer = nil
        print("[Manager] Auto-update stopped")
    }
    
    // MARK: - Helpers
    var formattedLastUpdate: String {
        guard let lastUpdate else { return "Jamais" }
        
        let formatter = RelativeDateTimeFormatter()
        formatter.locale = Locale(identifier: "fr_FR")
        return formatter.localizedString(for: lastUpdate, relativeTo: Date())
    }
    
    var highImpactEvents: [EconomicEvent] {
        events.filter { $0.impact == .high }
    }
    
    var todayEvents: [EconomicEvent] {
        let dateFormatter = DateFormatter()
        dateFormatter.locale = Locale(identifier: "en_US")
        dateFormatter.dateFormat = "EEEMMM d"
        let todayStr = dateFormatter.string(from: Date())
        
        return events.filter { $0.date == todayStr }
    }
}
