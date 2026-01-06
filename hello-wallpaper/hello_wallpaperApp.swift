//
//  hello_wallpaperApp.swift
//  hello-wallpaper
//

import SwiftUI

@main
struct hello_wallpaperApp: App {
    @State private var wallpaperManager = WallpaperManager.shared
    
    var body: some Scene {
        WindowGroup {
            WallpaperSearchView()
                .frame(minWidth: 700, minHeight: 500)
        }
        .windowResizability(.contentSize)
        
        MenuBarExtra("Hello Wallpaper", systemImage: "photo.on.rectangle") {
            MenuBarView()
        }
        .menuBarExtraStyle(.menu)
    }
}

struct MenuBarView: View {
    @State private var manager = WallpaperManager.shared
    
    var body: some View {
        Text("Current: \(manager.currentAppearance == .dark ? "Dark" : "Light") Mode")
            .foregroundStyle(.secondary)
        
        Divider()
        
        Text("☀️ Light: \(lightWallpaperName)")
        Text("🌙 Dark: \(darkWallpaperName)")
        
        Divider()
        
        Toggle("Auto Switch", isOn: Binding(
            get: { manager.settings.autoSwitchEnabled },
            set: { manager.settings.autoSwitchEnabled = $0 }
        ))
        
        Toggle("Launch at Login", isOn: Binding(
            get: { LaunchAtLogin.isEnabled },
            set: { _ in LaunchAtLogin.isEnabled.toggle() }
        ))
        
        Divider()
        
        Button("Apply Wallpaper") {
            Task {
                await manager.applyWallpaperForCurrentAppearance()
            }
        }
        
        Button("Open Window") {
            NSApp.activate(ignoringOtherApps: true)
            for window in NSApp.windows where window.canBecomeMain {
                window.makeKeyAndOrderFront(nil)
                break
            }
        }
        
        Divider()
        
        Button("Quit") {
            NSApplication.shared.terminate(nil)
        }
        .keyboardShortcut("q")
    }
    
    private var lightWallpaperName: String {
        guard let path = manager.settings.lightWallpaperPath else { return "Not Set" }
        return URL(fileURLWithPath: path).lastPathComponent
    }
    
    private var darkWallpaperName: String {
        guard let path = manager.settings.darkWallpaperPath else { return "Not Set" }
        return URL(fileURLWithPath: path).lastPathComponent
    }
}
