//
//  SupabaseService.swift
//  scrapme
//
//  Created by Michael Slimani on 08/12/2025.
//

import Foundation

actor SupabaseService {
    // Configuration - à déplacer vers un fichier de config ou Keychain
    private let supabaseURL = "https://samfxehmtyfpckfihfpb.supabase.co"
    private let anonKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InNhbWZ4ZWhtdHlmcGNrZmloZnBiIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjAxNjc1NjUsImV4cCI6MjA3NTc0MzU2NX0.H5j6HpKpHQHDzrSszlhPuXEOFI5aPAey27ylpPHKZSg"
    
    private var session: URLSession {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        return URLSession(configuration: config)
    }
    
    enum SupabaseError: LocalizedError {
        case invalidURL
        case networkError(Error)
        case invalidResponse(Int)
        case decodingError(Error)
        
        var errorDescription: String? {
            switch self {
            case .invalidURL:
                return "URL invalide"
            case .networkError(let error):
                return "Erreur réseau: \(error.localizedDescription)"
            case .invalidResponse(let code):
                return "Réponse invalide: HTTP \(code)"
            case .decodingError(let error):
                return "Erreur de décodage: \(error.localizedDescription)"
            }
        }
    }
    
    /// Appelle la fonction Edge Supabase pour mettre à jour le calendrier
    func triggerCalendarUpdate() async throws {
        guard let url = URL(string: "\(supabaseURL)/functions/v1/fetch-economic-calendar") else {
            throw SupabaseError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(anonKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let (_, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw SupabaseError.invalidResponse(0)
        }
        
        print("[Supabase] Edge function response: \(httpResponse.statusCode)")
        
        guard (200...299).contains(httpResponse.statusCode) else {
            throw SupabaseError.invalidResponse(httpResponse.statusCode)
        }
    }
    
    /// Upload direct des événements vers Supabase
    func uploadEvents(_ events: [EconomicEvent]) async throws {
        guard !events.isEmpty else {
            print("[Supabase] No events to upload")
            return
        }
        
        // URL avec on_conflict pour l'upsert
        guard let url = URL(string: "\(supabaseURL)/rest/v1/economic_events?on_conflict=event_date,time,name,currency") else {
            throw SupabaseError.invalidURL
        }
        
        // Convertir les événements en dictionnaires pour Supabase
        let payload = events.map { $0.toSupabaseDict() }
        let jsonData = try JSONSerialization.data(withJSONObject: payload)
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(anonKey)", forHTTPHeaderField: "Authorization")
        request.setValue(anonKey, forHTTPHeaderField: "apikey")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        // Upsert: met à jour si existe, sinon insère
        request.setValue("resolution=merge-duplicates,return=minimal", forHTTPHeaderField: "Prefer")
        request.httpBody = jsonData
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw SupabaseError.invalidResponse(0)
        }
        
        print("[Supabase] Upload response: \(httpResponse.statusCode)")
        
        if !(200...299).contains(httpResponse.statusCode) {
            if let errorString = String(data: data, encoding: .utf8) {
                print("[Supabase] Error: \(errorString)")
            }
            throw SupabaseError.invalidResponse(httpResponse.statusCode)
        }
        
        print("[Supabase] Successfully uploaded \(events.count) events")
    }
}
