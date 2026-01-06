//
//  WallpaperModels.swift
//  hello-wallpaper
//
//  Created by tao on 2026/1/6.
//

import Foundation
import AppKit

// MARK: - Search Response
struct WallhavenSearchResponse: Codable {
    let data: [WallpaperItem]
    let meta: SearchMeta
}

struct SearchMeta: Codable {
    let currentPage: Int
    let lastPage: Int
    let perPage: Int
    let total: Int
    let query: String?
    let seed: String?
    
    enum CodingKeys: String, CodingKey {
        case currentPage = "current_page"
        case lastPage = "last_page"
        case perPage = "per_page"
        case total
        case query
        case seed
    }
}

// MARK: - Wallpaper Item
struct WallpaperItem: Codable, Identifiable {
    let id: String
    let url: String
    let shortUrl: String
    let views: Int
    let favorites: Int
    let source: String
    let purity: String
    let category: String
    let dimensionX: Int
    let dimensionY: Int
    let resolution: String
    let ratio: String
    let fileSize: Int
    let fileType: String
    let createdAt: String
    let colors: [String]
    let path: String
    let thumbs: Thumbs
    
    enum CodingKeys: String, CodingKey {
        case id, url
        case shortUrl = "short_url"
        case views, favorites, source, purity, category
        case dimensionX = "dimension_x"
        case dimensionY = "dimension_y"
        case resolution, ratio
        case fileSize = "file_size"
        case fileType = "file_type"
        case createdAt = "created_at"
        case colors, path, thumbs
    }
}

struct Thumbs: Codable {
    let large: String
    let original: String
    let small: String
}

// MARK: - Wallpaper Detail Response
struct WallpaperDetailResponse: Codable {
    let data: WallpaperDetail
}

struct WallpaperDetail: Codable, Identifiable {
    let id: String
    let url: String
    let shortUrl: String
    let uploader: Uploader?
    let views: Int
    let favorites: Int
    let source: String
    let purity: String
    let category: String
    let dimensionX: Int
    let dimensionY: Int
    let resolution: String
    let ratio: String
    let fileSize: Int
    let fileType: String
    let createdAt: String
    let colors: [String]
    let path: String
    let thumbs: Thumbs
    let tags: [WallpaperTag]?
    
    enum CodingKeys: String, CodingKey {
        case id, url
        case shortUrl = "short_url"
        case uploader, views, favorites, source, purity, category
        case dimensionX = "dimension_x"
        case dimensionY = "dimension_y"
        case resolution, ratio
        case fileSize = "file_size"
        case fileType = "file_type"
        case createdAt = "created_at"
        case colors, path, thumbs, tags
    }
}

struct Uploader: Codable {
    let username: String
    let group: String
    let avatar: [String: String]
}

struct WallpaperTag: Codable, Identifiable {
    let id: Int
    let name: String
    let alias: String?
    let categoryId: Int
    let category: String
    let purity: String
    let createdAt: String
    
    enum CodingKeys: String, CodingKey {
        case id, name, alias
        case categoryId = "category_id"
        case category, purity
        case createdAt = "created_at"
    }
}

// MARK: - Search Parameters
struct WallhavenSearchParams {
    var query: String = ""
    var categories: String = "111"  // general/anime/people
    var purity: String = "100"      // sfw/sketchy/nsfw
    var sorting: Sorting = .dateAdded
    var order: Order = .desc
    var topRange: TopRange = .oneMonth
    var atleast: String?            // minimum resolution e.g. "1920x1080"
    var resolutions: [String]?      // exact resolutions
    var ratios: [String]?           // aspect ratios
    var colors: String?             // hex color without #
    var page: Int = 1
    var seed: String?               // for random sorting
    var apiKey: String?
    
    enum Sorting: String {
        case dateAdded = "date_added"
        case relevance
        case random
        case views
        case favorites
        case toplist
        case hot
    }
    
    enum Order: String {
        case desc, asc
    }
    
    enum TopRange: String {
        case oneDay = "1d"
        case threeDays = "3d"
        case oneWeek = "1w"
        case oneMonth = "1M"
        case threeMonths = "3M"
        case sixMonths = "6M"
        case oneYear = "1y"
    }
    
    func toQueryItems() -> [URLQueryItem] {
        var items: [URLQueryItem] = []
        
        if !query.isEmpty {
            items.append(URLQueryItem(name: "q", value: query))
        }
        items.append(URLQueryItem(name: "categories", value: categories))
        items.append(URLQueryItem(name: "purity", value: purity))
        items.append(URLQueryItem(name: "sorting", value: sorting.rawValue))
        items.append(URLQueryItem(name: "order", value: order.rawValue))
        
        if sorting == .toplist {
            items.append(URLQueryItem(name: "topRange", value: topRange.rawValue))
        }
        
        if let atleast = atleast {
            items.append(URLQueryItem(name: "atleast", value: atleast))
        }
        
        if let resolutions = resolutions, !resolutions.isEmpty {
            items.append(URLQueryItem(name: "resolutions", value: resolutions.joined(separator: ",")))
        }
        
        if let ratios = ratios, !ratios.isEmpty {
            items.append(URLQueryItem(name: "ratios", value: ratios.joined(separator: ",")))
        }
        
        if let colors = colors {
            items.append(URLQueryItem(name: "colors", value: colors))
        }
        
        items.append(URLQueryItem(name: "page", value: String(page)))
        
        if let seed = seed {
            items.append(URLQueryItem(name: "seed", value: seed))
        }
        
        if let apiKey = apiKey {
            items.append(URLQueryItem(name: "apikey", value: apiKey))
        }
        
        return items
    }
}

// MARK: - Local Wallpaper
struct LocalWallpaper: Codable, Identifiable, Equatable {
    let id: String
    let path: String
    let name: String
    let width: Int
    let height: Int
    let fileSize: Int
    let addedAt: Date
    
    var resolution: String { "\(width)x\(height)" }
    
    init(path: String) {
        self.id = UUID().uuidString
        self.path = path
        self.name = URL(fileURLWithPath: path).lastPathComponent
        self.addedAt = Date()
        
        if let image = NSImage(contentsOfFile: path) {
            let rep = image.representations.first
            self.width = rep?.pixelsWide ?? Int(image.size.width)
            self.height = rep?.pixelsHigh ?? Int(image.size.height)
        } else {
            self.width = 0
            self.height = 0
        }
        
        if let attrs = try? FileManager.default.attributesOfItem(atPath: path),
           let size = attrs[.size] as? Int {
            self.fileSize = size
        } else {
            self.fileSize = 0
        }
    }
}

// MARK: - App Settings
struct WallpaperSettings: Codable {
    var lightWallpaperPath: String?
    var darkWallpaperPath: String?
    var lightWallpaperId: String?
    var darkWallpaperId: String?
    var autoSwitchEnabled: Bool = true
    var apiKey: String?
    var favorites: [String] = []
    var localFavorites: [LocalWallpaper] = []
}
