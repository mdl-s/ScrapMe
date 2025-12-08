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
}

// MARK: - Supabase payload
extension EconomicEvent {
    func toSupabasePayload() -> [String: Any] {
        return [
            "date": date,
            "time": time,
            "currency": currency,
            "impact": impact.rawValue,
            "name": name,
            "actual": actual,
            "forecast": forecast,
            "previous": previous,
            "detail_url": detailUrl
        ]
    }
}
