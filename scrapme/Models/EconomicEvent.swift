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
    
    /// Parse "Mon Jan 6" or "MonJan 6" or "MonJan6" -> "2026-01-06"
    private func parseEventDate(from dateStr: String) -> String {
        let months: [String: Int] = [
            "Jan": 1, "Feb": 2, "Mar": 3, "Apr": 4, "May": 5, "Jun": 6,
            "Jul": 7, "Aug": 8, "Sep": 9, "Oct": 10, "Nov": 11, "Dec": 12
        ]
        
        // Remove day of week (first 3 chars) and trim whitespace
        // Handles: "Mon Jan 6" -> " Jan 6" -> "Jan 6"
        // Handles: "MonJan 6" -> "Jan 6"
        // Handles: "MonJan6" -> "Jan6"
        let withoutDay = String(dateStr.dropFirst(3)).trimmingCharacters(in: .whitespaces)
        
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
        let currentDay = calendar.component(.day, from: now)
        
        // Déterminer l'année correcte:
        // - Si le mois est le même que le mois actuel, utiliser l'année actuelle
        // - Si le mois est après le mois actuel, utiliser l'année actuelle (événement futur)
        // - Si le mois est avant le mois actuel:
        //   - Si c'est dans les 7 derniers jours (décembre -> janvier), utiliser l'année précédente
        //   - Sinon, utiliser l'année prochaine (cas rare)
        var year = currentYear
        
        if month < currentMonth {
            // Le mois est avant le mois actuel
            // Vérifier si c'est un événement récent (ex: fin décembre quand on est début janvier)
            if currentMonth == 1 && month == 12 && day >= 25 {
                // C'est un événement de fin décembre, donc année précédente
                year = currentYear - 1
            } else {
                // Sinon, c'est probablement l'année prochaine
                year = currentYear + 1
            }
        }
        // Si month >= currentMonth, on garde currentYear
        
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
