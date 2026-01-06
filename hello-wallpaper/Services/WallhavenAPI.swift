//
//  WallhavenAPI.swift
//  hello-wallpaper
//

import Foundation

enum WallhavenAPIError: Error, LocalizedError {
    case invalidURL
    case networkError(Error)
    case decodingError(Error)
    case httpError(Int)
    case unauthorized
    case rateLimited
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .decodingError(let error):
            return "Decoding error: \(error.localizedDescription)"
        case .httpError(let code):
            return "HTTP error: \(code)"
        case .unauthorized:
            return "Unauthorized - check your API key"
        case .rateLimited:
            return "Rate limited - too many requests"
        }
    }
}

actor WallhavenAPI {
    static let shared = WallhavenAPI()
    
    private let baseURL = "https://wallhaven.cc/api/v1"
    private let session: URLSession
    
    init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        self.session = URLSession(configuration: config)
    }
    
    func search(params: WallhavenSearchParams) async throws -> WallhavenSearchResponse {
        var components = URLComponents(string: "\(baseURL)/search")!
        components.queryItems = params.toQueryItems()
        
        guard let url = components.url else {
            throw WallhavenAPIError.invalidURL
        }
        
        return try await fetch(url: url, type: WallhavenSearchResponse.self)
    }
    
    func getWallpaper(id: String, apiKey: String? = nil) async throws -> WallpaperDetail {
        var components = URLComponents(string: "\(baseURL)/w/\(id)")!
        
        if let apiKey = apiKey {
            components.queryItems = [URLQueryItem(name: "apikey", value: apiKey)]
        }
        
        guard let url = components.url else {
            throw WallhavenAPIError.invalidURL
        }
        
        let response: WallpaperDetailResponse = try await fetch(url: url, type: WallpaperDetailResponse.self)
        return response.data
    }
    
    func downloadWallpaper(from urlString: String, to destination: URL) async throws {
        guard let url = URL(string: urlString) else {
            throw WallhavenAPIError.invalidURL
        }
        
        let (tempURL, response) = try await session.download(from: url)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw WallhavenAPIError.networkError(NSError(domain: "Invalid response", code: 0))
        }
        
        switch httpResponse.statusCode {
        case 200...299:
            let fileManager = FileManager.default
            if fileManager.fileExists(atPath: destination.path) {
                try fileManager.removeItem(at: destination)
            }
            try fileManager.moveItem(at: tempURL, to: destination)
        case 401:
            throw WallhavenAPIError.unauthorized
        case 429:
            throw WallhavenAPIError.rateLimited
        default:
            throw WallhavenAPIError.httpError(httpResponse.statusCode)
        }
    }
    
    private func fetch<T: Decodable>(url: URL, type: T.Type) async throws -> T {
        let (data, response) = try await session.data(from: url)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw WallhavenAPIError.networkError(NSError(domain: "Invalid response", code: 0))
        }
        
        switch httpResponse.statusCode {
        case 200...299:
            do {
                return try JSONDecoder().decode(T.self, from: data)
            } catch {
                throw WallhavenAPIError.decodingError(error)
            }
        case 401:
            throw WallhavenAPIError.unauthorized
        case 429:
            throw WallhavenAPIError.rateLimited
        default:
            throw WallhavenAPIError.httpError(httpResponse.statusCode)
        }
    }
}
