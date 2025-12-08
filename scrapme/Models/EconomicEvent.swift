//
//  EconomicEvent.swift
//  scrapme
//
//  Created by Michael Slimani on 08/12/2025.
//

import Foundation

struct EconomicEvent: Identifiable, Codable, Equatable, Sendable {
    var id: String { "\(date)-\(time)-\(currency)-\(name)" }
    
    let date: String        // e.g., "MonDec 9"
    let time: String        // e.g., "8:30am"
    let currency: String    // e.g., "USD"
    let impact: Impact
    let name: String        // e.g., "Core Retail Sales m/m"
    let actual: String
    let forecast: String
    let previous: String
    let detailUrl: String
    
    /// Date ISO pour Supabase (calculée à partir de `date`)
    var eventDate: String {
        parseEventDate(from: date)
    }
    
    /// Parse "MonDec 9" -> "2024-12-09"
    private func parseEventDate(from dateStr: String) -> String {
        let months: [String: Int] = [
            "Jan": 1, "Feb": 2, "Mar": 3, "Apr": 4, "May": 5, "Jun": 6,
            "Jul": 7, "Aug": 8, "Sep": 9, "Oct": 10, "Nov": 11, "Dec": 12
        ]
        
        // Remove day of week (first 3 chars): "MonDec 9" -> "Dec 9" ou "Dec9"
        let withoutDay = String(dateStr.dropFirst(3))
        
        // Extract month and day
        var monthStr = ""
        var dayStr = ""
        
        for (month, _) in months {
            if withoutDay.hasPrefix(month) {
                monthStr = month
                dayStr = String(withoutDay.dropFirst(month.count)).trimmingCharacters(in: .whitespaces)
                break
            }
        }
        
        guard let month = months[monthStr], let day = Int(dayStr) else {
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withFullDate]
            return formatter.string(from: Date())
        }
        
        let calendar = Calendar.current
        let now = Date()
        let currentYear = calendar.component(.year, from: now)
        let currentMonth = calendar.component(.month, from: now)
        
        // Si le mois est avant le mois actuel, c'est probablement l'année prochaine
        let year = month < currentMonth ? currentYear + 1 : currentYear
        
        return String(format: "%04d-%02d-%02d", year, month, day)
    }
    
    enum Impact: String, Codable, CaseIterable {
        case high = "High"
        case medium = "Medium"
        case low = "Low"
        case unknown = "Unknown"
        
        var color: String {
            switch self {
            case .high: return "red"
            case .medium: return "orange"
            case .low: return "yellow"
            case .unknown: return "gray"
            }
        }
    }
    
    enum CodingKeys: String, CodingKey {
        case date, time, currency, impact, name, actual, forecast, previous
        case detailUrl = "detail_url"
    }
    
    /// Payload pour Supabase (snake_case)
    func toSupabaseDict() -> [String: Any] {
        return [
            "date": date,
            "time": time,
            "currency": currency,
            "impact": impact.rawValue,
            "name": name,
            "actual": actual.isEmpty ? NSNull() : actual,
            "forecast": forecast.isEmpty ? NSNull() : forecast,
            "previous": previous.isEmpty ? NSNull() : previous,
            "detail_url": detailUrl,
            "event_date": eventDate
        ]
    }
}
