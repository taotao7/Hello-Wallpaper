//
//  WallpaperManager.swift
//  hello-wallpaper
//

import Foundation
import AppKit
import Combine

@Observable
final class WallpaperManager {
    static let shared = WallpaperManager()
    
    var settings: WallpaperSettings {
        didSet { saveSettings() }
    }
    
    var currentAppearance: AppearanceMode = .light
    
    private let settingsKey = "WallpaperSettings"
    private let wallpaperDirectory: URL
    private var appearanceObserver: NSObjectProtocol?
    
    enum AppearanceMode: String {
        case light, dark
    }
    
    init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        wallpaperDirectory = appSupport.appendingPathComponent("HelloWallpaper/Wallpapers", isDirectory: true)
        
        try? FileManager.default.createDirectory(at: wallpaperDirectory, withIntermediateDirectories: true)
        
        if let data = UserDefaults.standard.data(forKey: settingsKey),
           let decoded = try? JSONDecoder().decode(WallpaperSettings.self, from: data) {
            settings = decoded
        } else {
            settings = WallpaperSettings()
        }
        
        currentAppearance = Self.detectCurrentAppearance()
        startObservingAppearance()
    }
    
    private static func detectCurrentAppearance() -> AppearanceMode {
        let isDark = UserDefaults.standard.string(forKey: "AppleInterfaceStyle") == "Dark"
        return isDark ? .dark : .light
    }
    
    deinit {
        if let observer = appearanceObserver {
            DistributedNotificationCenter.default().removeObserver(observer)
        }
    }
    
    private func saveSettings() {
        if let data = try? JSONEncoder().encode(settings) {
            UserDefaults.standard.set(data, forKey: settingsKey)
        }
    }
    
    private func updateCurrentAppearance() {
        currentAppearance = Self.detectCurrentAppearance()
    }
    
    private func startObservingAppearance() {
        appearanceObserver = DistributedNotificationCenter.default().addObserver(
            forName: NSNotification.Name("AppleInterfaceThemeChangedNotification"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.handleAppearanceChange()
        }
    }
    
    private func handleAppearanceChange() {
        updateCurrentAppearance()
        
        guard settings.autoSwitchEnabled else { return }
        
        Task {
            await applyWallpaperForCurrentAppearance()
        }
    }
    
    func applyWallpaperForCurrentAppearance() async {
        let path = currentAppearance == .dark ? settings.darkWallpaperPath : settings.lightWallpaperPath
        
        guard let wallpaperPath = path else { return }
        
        let url = URL(fileURLWithPath: wallpaperPath)
        guard FileManager.default.fileExists(atPath: wallpaperPath) else { return }
        
        await setWallpaper(url: url)
    }
    
    func setWallpaper(url: URL) async {
        await MainActor.run {
            for screen in NSScreen.screens {
                try? NSWorkspace.shared.setDesktopImageURL(url, for: screen, options: [:])
            }
        }
    }
    
    func downloadAndSetWallpaper(wallpaper: WallpaperItem, forMode mode: AppearanceMode) async throws {
        let fileName = "\(wallpaper.id).\(wallpaper.fileType.split(separator: "/").last ?? "jpg")"
        let destination = wallpaperDirectory.appendingPathComponent(fileName)
        
        if !FileManager.default.fileExists(atPath: destination.path) {
            try await WallhavenAPI.shared.downloadWallpaper(from: wallpaper.path, to: destination)
        }
        
        switch mode {
        case .light:
            settings.lightWallpaperPath = destination.path
            settings.lightWallpaperId = wallpaper.id
        case .dark:
            settings.darkWallpaperPath = destination.path
            settings.darkWallpaperId = wallpaper.id
        }
        
        if currentAppearance == mode {
            await setWallpaper(url: destination)
        }
    }
    
    func clearWallpaper(forMode mode: AppearanceMode) {
        switch mode {
        case .light:
            settings.lightWallpaperPath = nil
            settings.lightWallpaperId = nil
        case .dark:
            settings.darkWallpaperPath = nil
            settings.darkWallpaperId = nil
        }
    }
    
    func isFavorite(_ wallpaperId: String) -> Bool {
        settings.favorites.contains(wallpaperId)
    }
    
    func toggleFavorite(_ wallpaperId: String) {
        if let index = settings.favorites.firstIndex(of: wallpaperId) {
            settings.favorites.remove(at: index)
        } else {
            settings.favorites.append(wallpaperId)
        }
    }
    
    func addLocalFavorite(path: String) {
        guard !settings.localFavorites.contains(where: { $0.path == path }) else { return }
        let local = LocalWallpaper(path: path)
        settings.localFavorites.append(local)
    }
    
    func removeLocalFavorite(_ wallpaper: LocalWallpaper) {
        settings.localFavorites.removeAll { $0.id == wallpaper.id }
    }
    
    func setLocalWallpaper(wallpaper: LocalWallpaper, forMode mode: AppearanceMode) async {
        let url = URL(fileURLWithPath: wallpaper.path)
        
        switch mode {
        case .light:
            settings.lightWallpaperPath = wallpaper.path
            settings.lightWallpaperId = "local:\(wallpaper.id)"
        case .dark:
            settings.darkWallpaperPath = wallpaper.path
            settings.darkWallpaperId = "local:\(wallpaper.id)"
        }
        
        if currentAppearance == mode {
            await setWallpaper(url: url)
        }
    }
}
