//
//  ForexFactoryScraper.swift
//  scrapme
//
//  Created by Michael Slimani on 08/12/2025.
//

import Foundation
import SwiftSoup

actor ForexFactoryScraper {
    private let baseURL = "https://www.forexfactory.com/calendar"
    
    private var session: URLSession {
        let config = URLSessionConfiguration.default
        config.httpAdditionalHeaders = [
            "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,image/apng,*/*;q=0.8",
            "Accept-Language": "en-US,en;q=0.9",
            "User-Agent": "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
            "Connection": "keep-alive",
            "Upgrade-Insecure-Requests": "1",
            "Sec-Fetch-Dest": "document",
            "Sec-Fetch-Mode": "navigate",
            "Sec-Fetch-Site": "none",
            "Sec-Fetch-User": "?1",
            "Cache-Control": "max-age=0",
            "Referer": "https://www.forexfactory.com/",
            "DNT": "1"
        ]
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 60
        return URLSession(configuration: config)
    }
    
    enum ScrapingError: LocalizedError {
        case invalidURL
        case networkError(Error)
        case parsingError(String)
        case noData
        
        var errorDescription: String? {
            switch self {
            case .invalidURL:
                return "URL invalide"
            case .networkError(let error):
                return "Erreur réseau: \(error.localizedDescription)"
            case .parsingError(let message):
                return "Erreur de parsing: \(message)"
            case .noData:
                return "Aucune donnée reçue"
            }
        }
    }
    
    enum Period: String {
        case today
        case week
    }
    
    func scrapeCalendar(period: Period = .week) async throws -> [EconomicEvent] {
        guard let url = URL(string: baseURL) else {
            throw ScrapingError.invalidURL
        }
        
        let (data, response) = try await session.data(from: url)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw ScrapingError.noData
        }
        
        print("[Scraper] HTTP Status: \(httpResponse.statusCode)")
        
        guard httpResponse.statusCode == 200 else {
            throw ScrapingError.networkError(NSError(domain: "", code: httpResponse.statusCode))
        }
        
        guard let html = String(data: data, encoding: .utf8) else {
            throw ScrapingError.noData
        }
        
        return try parseCalendar(html: html, period: period)
    }
    
    private func parseCalendar(html: String, period: Period) throws -> [EconomicEvent] {
        let doc = try SwiftSoup.parse(html)
        
        guard let calendarTable = try doc.select("table.calendar__table").first() else {
            throw ScrapingError.parsingError("Calendar table not found")
        }
        
        var events: [EconomicEvent] = []
        var currentDate: String?
        var currentTime: String = "" // Track last seen time for consecutive events
        
        let rows = try calendarTable.select("tr.calendar__row")
        
        for row in rows {
            // Get date if present
            if let dateCell = try row.select("td.calendar__cell.calendar__date").first() {
                let dateText = try dateCell.text().trimmingCharacters(in: .whitespacesAndNewlines)
                if !dateText.isEmpty {
                    if let span = try dateCell.select("span").first() {
                        currentDate = try span.text().trimmingCharacters(in: .whitespacesAndNewlines)
                    } else {
                        currentDate = dateText
                    }
                    // Reset time when date changes
                    currentTime = ""
                }
            }
            
            guard let date = currentDate, !date.isEmpty else { continue }
            
            // Get time - keep track of last seen time for consecutive events at same time
            let timeCell = try row.select("td.calendar__cell.calendar__time").first()
            let timeText = try timeCell?.text().trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            
            // Update currentTime only if we have a new time value
            if !timeText.isEmpty {
                currentTime = timeText
            }
            
            // Use currentTime (which persists across rows with empty time cells)
            let time = currentTime
            
            // Skip only if we truly have no time info and it's not a special event
            if time.isEmpty {
                continue
            }
            
            // Get currency
            let currencyCell = try row.select("td.calendar__cell.calendar__currency").first()
            let currency = try currencyCell?.text().trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            
            // Get impact
            let impactCell = try row.select("td.calendar__cell.calendar__impact").first()
            let impact = parseImpact(from: impactCell)
            
            // Get event name
            let eventCell = try row.select("td.calendar__cell.calendar__event").first()
            let eventName = try eventCell?.text().trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            
            // Get actual, forecast, previous
            let actualCell = try row.select("td.calendar__cell.calendar__actual").first()
            let actual = try actualCell?.text().trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            
            let forecastCell = try row.select("td.calendar__cell.calendar__forecast").first()
            let forecast = try forecastCell?.text().trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            
            let previousCell = try row.select("td.calendar__cell.calendar__previous").first()
            let previous = try previousCell?.text().trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            
            // Only add if we have essential data
            if !eventName.isEmpty && !currency.isEmpty {
                let detailUrl = generateDetailUrl(for: eventName)
                
                let event = EconomicEvent(
                    date: date,
                    time: time,
                    currency: currency,
                    impact: impact,
                    name: eventName,
                    actual: actual,
                    forecast: forecast,
                    previous: previous,
                    detailUrl: detailUrl
                )
                events.append(event)
            }
        }
        
        // Filter for today if needed
        if period == .today {
            let dateFormatter = DateFormatter()
            dateFormatter.locale = Locale(identifier: "en_US")
            
            // Format: "MonDec 9" or "MonDec9"
            dateFormatter.dateFormat = "EEEMMM d"
            let todayStr1 = dateFormatter.string(from: Date())
            
            dateFormatter.dateFormat = "EEEMMMd"
            let todayStr2 = dateFormatter.string(from: Date())
            
            events = events.filter { $0.date == todayStr1 || $0.date == todayStr2 }
        }
        
        print("[Scraper] Parsed \(events.count) events")
        return events
    }
    
    private func parseImpact(from element: Element?) -> EconomicEvent.Impact {
        guard let element = element else { return .unknown }
        
        do {
            if let span = try element.select("span").first() {
                let classes = try span.classNames()
                
                if classes.contains("icon--ff-impact-red") {
                    return .high
                } else if classes.contains("icon--ff-impact-ora") {
                    return .medium
                } else if classes.contains("icon--ff-impact-yel") {
                    return .low
                }
            }
        } catch {
            print("[Scraper] Error parsing impact: \(error)")
        }
        
        return .unknown
    }
    
    private func generateDetailUrl(for eventName: String) -> String {
        let slug = eventName
            .lowercased()
            .replacingOccurrences(of: " ", with: "-")
            .replacingOccurrences(of: "/", with: "")
            .replacingOccurrences(of: "%", with: "")
            .replacingOccurrences(of: "(", with: "")
            .replacingOccurrences(of: ")", with: "")
        
        return "https://www.forexfactory.com/calendar/\(slug)"
    }
}
