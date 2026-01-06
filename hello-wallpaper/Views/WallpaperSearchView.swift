//
//  WallpaperSearchView.swift
//  hello-wallpaper
//

import SwiftUI
import UniformTypeIdentifiers

enum SidebarItem: String, CaseIterable, Identifiable {
    case explore = "Explore"
    case local = "Local"
    case favorites = "Favorites"
    case current = "Current"
    
    var id: String { rawValue }
    
    var icon: String {
        switch self {
        case .explore: return "sparkle.magnifyingglass"
        case .local: return "folder"
        case .favorites: return "heart.fill"
        case .current: return "display"
        }
    }
}

struct WallpaperSearchView: View {
    @State private var selectedItem: SidebarItem = .explore
    @State private var manager = WallpaperManager.shared
    
    var body: some View {
        NavigationSplitView {
            List(SidebarItem.allCases, selection: $selectedItem) { item in
                Label(item.rawValue, systemImage: item.icon)
                    .tag(item)
            }
            .navigationSplitViewColumnWidth(min: 180, ideal: 200)
        } detail: {
            switch selectedItem {
            case .explore:
                ExploreView()
            case .local:
                LocalFilesView()
            case .favorites:
                FavoritesView()
            case .current:
                CurrentWallpapersView()
            }
        }
    }
}

struct ExploreView: View {
    @State private var searchText = ""
    @State private var wallpapers: [WallpaperItem] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var currentPage = 1
    @State private var hasMorePages = true
    @State private var selectedWallpaper: WallpaperItem?
    @State private var hoveredId: String?
    
    private let columns = [
        GridItem(.adaptive(minimum: 280, maximum: 400), spacing: 16)
    ]
    
    var body: some View {
        VStack(spacing: 0) {
            headerView
            
            if let error = errorMessage {
                errorView(error)
            } else if wallpapers.isEmpty && !isLoading {
                emptyView
            } else {
                wallpaperGrid
            }
        }
        .sheet(item: $selectedWallpaper) { wallpaper in
            WallpaperPreviewSheet(wallpaper: wallpaper)
        }
        .task {
            await loadWallpapers()
        }
    }
    
    private var headerView: some View {
        HStack(spacing: 12) {
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                
                TextField("Search wallpapers...", text: $searchText)
                    .textFieldStyle(.plain)
                    .onSubmit {
                        Task {
                            currentPage = 1
                            wallpapers = []
                            await loadWallpapers()
                        }
                    }
                
                if !searchText.isEmpty {
                    Button {
                        searchText = ""
                        Task {
                            currentPage = 1
                            wallpapers = []
                            await loadWallpapers()
                        }
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(10)
            .background(.background.opacity(0.8))
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color.gray.opacity(0.2), lineWidth: 1)
            )
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
    }
    
    private var emptyView: some View {
        ContentUnavailableView(
            "No Wallpapers",
            systemImage: "photo.on.rectangle",
            description: Text("Search for wallpapers or check your connection")
        )
    }
    
    private func errorView(_ message: String) -> some View {
        ContentUnavailableView {
            Label("Error", systemImage: "exclamationmark.triangle")
        } description: {
            Text(message)
        } actions: {
            Button("Retry") {
                Task {
                    currentPage = 1
                    wallpapers = []
                    await loadWallpapers()
                }
            }
            .buttonStyle(.borderedProminent)
        }
    }
    
    private var wallpaperGrid: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 16) {
                ForEach(wallpapers) { wallpaper in
                    WallpaperCard(
                        wallpaper: wallpaper,
                        isHovered: hoveredId == wallpaper.id,
                        onTap: { selectedWallpaper = wallpaper }
                    )
                    .onHover { isHovered in
                        withAnimation(.easeInOut(duration: 0.2)) {
                            hoveredId = isHovered ? wallpaper.id : nil
                        }
                    }
                    .onAppear {
                        if wallpaper.id == wallpapers.last?.id {
                            loadMoreIfNeeded()
                        }
                    }
                }
            }
            .padding(20)
            
            if isLoading {
                ProgressView()
                    .scaleEffect(1.2)
                    .padding(30)
            }
        }
    }
    
    private func loadWallpapers() async {
        guard !isLoading else { return }
        
        isLoading = true
        errorMessage = nil
        
        var params = WallhavenSearchParams()
        params.query = searchText
        params.page = currentPage
        params.sorting = .toplist
        params.atleast = "1920x1080"
        
        do {
            let response = try await WallhavenAPI.shared.search(params: params)
            
            if currentPage == 1 {
                wallpapers = response.data
            } else {
                wallpapers.append(contentsOf: response.data)
            }
            
            hasMorePages = currentPage < response.meta.lastPage
        } catch {
            errorMessage = error.localizedDescription
        }
        
        isLoading = false
    }
    
    private func loadMoreIfNeeded() {
        guard !isLoading && hasMorePages else { return }
        currentPage += 1
        Task {
            await loadWallpapers()
        }
    }
}

struct LocalFilesView: View {
    @State private var manager = WallpaperManager.shared
    @State private var selectedLocal: LocalWallpaper?
    @State private var hoveredId: String?
    
    private let columns = [
        GridItem(.adaptive(minimum: 280, maximum: 400), spacing: 16)
    ]
    
    var body: some View {
        Group {
            if manager.settings.localFavorites.isEmpty {
                emptyStateView
            } else {
                VStack(spacing: 0) {
                    HStack {
                        Text("\(manager.settings.localFavorites.count) wallpapers")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        
                        Spacer()
                        
                        Button {
                            importLocalFiles()
                        } label: {
                            Label("Add", systemImage: "plus")
                        }
                        .buttonStyle(.bordered)
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    
                    ScrollView {
                        LazyVGrid(columns: columns, spacing: 16) {
                            ForEach(manager.settings.localFavorites) { local in
                                LocalWallpaperCard(
                                    wallpaper: local,
                                    isHovered: hoveredId == local.id,
                                    onTap: { selectedLocal = local },
                                    onRemove: { manager.removeLocalFavorite(local) }
                                )
                                .onHover { isHovered in
                                    withAnimation(.easeInOut(duration: 0.2)) {
                                        hoveredId = isHovered ? local.id : nil
                                    }
                                }
                            }
                        }
                        .padding(20)
                    }
                }
            }
        }
        .sheet(item: $selectedLocal) { local in
            LocalPreviewSheet(wallpaper: local)
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Spacer()
            
            Image(systemName: "photo.on.rectangle.angled")
                .font(.system(size: 64))
                .foregroundStyle(.tertiary)
            
            Text("No Local Wallpapers")
                .font(.title2)
                .fontWeight(.medium)
            
            Text("Import wallpapers from your computer")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            
            Button {
                importLocalFiles()
            } label: {
                Label("Add Wallpapers", systemImage: "plus")
                    .padding(.horizontal, 8)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .padding(.top, 8)
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private func importLocalFiles() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowedContentTypes = [.image, .png, .jpeg, .heic]
        
        if panel.runModal() == .OK {
            for url in panel.urls {
                manager.addLocalFavorite(path: url.path)
            }
        }
    }
}

struct LocalWallpaperCard: View {
    let wallpaper: LocalWallpaper
    let isHovered: Bool
    let onTap: () -> Void
    let onRemove: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 0) {
                ZStack(alignment: .topTrailing) {
                    if let image = NSImage(contentsOfFile: wallpaper.path) {
                        Image(nsImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(height: 180)
                            .clipped()
                    } else {
                        Rectangle()
                            .fill(Color.gray.opacity(0.1))
                            .frame(height: 180)
                            .overlay {
                                VStack {
                                    Image(systemName: "photo")
                                        .font(.largeTitle)
                                    Text("Not Found")
                                        .font(.caption)
                                }
                                .foregroundStyle(.secondary)
                            }
                    }
                    
                    Button {
                        withAnimation {
                            onRemove()
                        }
                    } label: {
                        Image(systemName: "xmark")
                            .font(.caption)
                            .foregroundStyle(.white)
                            .padding(6)
                            .background(.red)
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .padding(8)
                }
                
                HStack {
                    Text(wallpaper.resolution)
                        .font(.caption)
                        .fontWeight(.semibold)
                    
                    Spacer()
                    
                    Text(wallpaper.name)
                        .font(.caption2)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
                .foregroundStyle(.secondary)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color(nsColor: .controlBackgroundColor))
            }
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .shadow(color: .black.opacity(isHovered ? 0.3 : 0.15), radius: isHovered ? 15 : 8, y: isHovered ? 8 : 4)
            .scaleEffect(isHovered ? 1.02 : 1.0)
        }
        .buttonStyle(.plain)
    }
}

struct LocalPreviewSheet: View {
    let wallpaper: LocalWallpaper
    @Environment(\.dismiss) private var dismiss
    @State private var manager = WallpaperManager.shared
    @State private var selectedMode: WallpaperManager.AppearanceMode = .light
    @State private var isSettingWallpaper = false
    
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button { dismiss() } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .keyboardShortcut(.escape, modifiers: [])
                
                Spacer()
                
                Text(wallpaper.name)
                    .font(.headline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                
                Spacer()
                
                Color.clear.frame(width: 28)
            }
            .padding()
            .background(.ultraThinMaterial)
            
            GeometryReader { geo in
                if let image = NSImage(contentsOfFile: wallpaper.path) {
                    Image(nsImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: geo.size.width, height: geo.size.height)
                } else {
                    ContentUnavailableView("File not found", systemImage: "photo")
                }
            }
            .background(Color.black)
            
            VStack(spacing: 16) {
                HStack(spacing: 24) {
                    InfoBadge(icon: "aspectratio", value: wallpaper.resolution)
                    InfoBadge(icon: "doc", value: formatFileSize(wallpaper.fileSize))
                }
                
                HStack(spacing: 12) {
                    Picker("Mode", selection: $selectedMode) {
                        Label("Light", systemImage: "sun.max").tag(WallpaperManager.AppearanceMode.light)
                        Label("Dark", systemImage: "moon").tag(WallpaperManager.AppearanceMode.dark)
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 200)
                    
                    Button {
                        Task { await setWallpaper() }
                    } label: {
                        HStack {
                            if isSettingWallpaper {
                                ProgressView()
                                    .controlSize(.small)
                            } else {
                                Image(systemName: "display")
                            }
                            Text("Set Wallpaper")
                        }
                        .frame(width: 140)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(isSettingWallpaper)
                }
            }
            .padding()
            .background(.ultraThinMaterial)
        }
        .frame(minWidth: 800, minHeight: 600)
    }
    
    private func setWallpaper() async {
        isSettingWallpaper = true
        defer { isSettingWallpaper = false }
        
        await manager.setLocalWallpaper(wallpaper: wallpaper, forMode: selectedMode)
        dismiss()
    }
    
    private func formatFileSize(_ bytes: Int) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: Int64(bytes))
    }
}

struct FavoritesView: View {
    @State private var manager = WallpaperManager.shared
    @State private var favoriteWallpapers: [WallpaperItem] = []
    @State private var isLoading = false
    @State private var selectedWallpaper: WallpaperItem?
    @State private var hoveredId: String?
    
    private let columns = [
        GridItem(.adaptive(minimum: 280, maximum: 400), spacing: 16)
    ]
    
    var body: some View {
        Group {
            if manager.settings.favorites.isEmpty {
                ContentUnavailableView(
                    "No Favorites",
                    systemImage: "heart.slash",
                    description: Text("Wallpapers you favorite will appear here")
                )
            } else if isLoading {
                ProgressView("Loading favorites...")
            } else if favoriteWallpapers.isEmpty {
                ContentUnavailableView(
                    "Loading...",
                    systemImage: "arrow.clockwise",
                    description: Text("Fetching your favorite wallpapers")
                )
            } else {
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 16) {
                        ForEach(favoriteWallpapers) { wallpaper in
                            WallpaperCard(
                                wallpaper: wallpaper,
                                isHovered: hoveredId == wallpaper.id,
                                onTap: { selectedWallpaper = wallpaper }
                            )
                            .onHover { isHovered in
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    hoveredId = isHovered ? wallpaper.id : nil
                                }
                            }
                        }
                    }
                    .padding(20)
                }
            }
        }
        .sheet(item: $selectedWallpaper) { wallpaper in
            WallpaperPreviewSheet(wallpaper: wallpaper)
        }
        .task {
            await loadFavorites()
        }
        .onChange(of: manager.settings.favorites) {
            Task {
                await loadFavorites()
            }
        }
    }
    
    private func loadFavorites() async {
        guard !manager.settings.favorites.isEmpty else {
            favoriteWallpapers = []
            return
        }
        
        isLoading = true
        var loaded: [WallpaperItem] = []
        
        for id in manager.settings.favorites {
            do {
                let detail = try await WallhavenAPI.shared.getWallpaper(id: id)
                let item = WallpaperItem(
                    id: detail.id,
                    url: detail.url,
                    shortUrl: detail.shortUrl,
                    views: detail.views,
                    favorites: detail.favorites,
                    source: detail.source,
                    purity: detail.purity,
                    category: detail.category,
                    dimensionX: detail.dimensionX,
                    dimensionY: detail.dimensionY,
                    resolution: detail.resolution,
                    ratio: detail.ratio,
                    fileSize: detail.fileSize,
                    fileType: detail.fileType,
                    createdAt: detail.createdAt,
                    colors: detail.colors,
                    path: detail.path,
                    thumbs: detail.thumbs
                )
                loaded.append(item)
            } catch {
                print("Failed to load wallpaper \(id): \(error)")
            }
        }
        
        favoriteWallpapers = loaded
        isLoading = false
    }
}

struct CurrentWallpapersView: View {
    @State private var manager = WallpaperManager.shared
    
    var body: some View {
        ScrollView {
            VStack(spacing: 32) {
                currentModeIndicator
                
                HStack(alignment: .top, spacing: 24) {
                    WallpaperSlot(
                        title: "Light Mode",
                        icon: "sun.max.fill",
                        wallpaperPath: manager.settings.lightWallpaperPath,
                        accentColor: .orange,
                        isActive: manager.currentAppearance == .light,
                        onClear: { manager.clearWallpaper(forMode: .light) }
                    )
                    
                    WallpaperSlot(
                        title: "Dark Mode",
                        icon: "moon.fill",
                        wallpaperPath: manager.settings.darkWallpaperPath,
                        accentColor: .indigo,
                        isActive: manager.currentAppearance == .dark,
                        onClear: { manager.clearWallpaper(forMode: .dark) }
                    )
                }
                .padding(.horizontal, 40)
                
                settingsSection
            }
            .padding(.vertical, 30)
        }
    }
    
    private var currentModeIndicator: some View {
        HStack(spacing: 10) {
            Image(systemName: manager.currentAppearance == .dark ? "moon.fill" : "sun.max.fill")
                .font(.body)
                .foregroundStyle(manager.currentAppearance == .dark ? .indigo : .orange)
            
            Text("System is in \(manager.currentAppearance == .dark ? "Dark" : "Light") Mode")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.regularMaterial)
        .clipShape(Capsule())
    }
    
    private var settingsSection: some View {
        VStack(spacing: 20) {
            Divider()
                .padding(.horizontal, 40)
            
            VStack(alignment: .leading, spacing: 16) {
                Toggle(isOn: Binding(
                    get: { manager.settings.autoSwitchEnabled },
                    set: { manager.settings.autoSwitchEnabled = $0 }
                )) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Auto Switch")
                            .font(.body)
                        Text("Change wallpaper when system appearance changes")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .toggleStyle(.switch)
                
                Button {
                    Task {
                        await manager.applyWallpaperForCurrentAppearance()
                    }
                } label: {
                    Label("Apply Now", systemImage: "arrow.clockwise")
                }
                .buttonStyle(.bordered)
            }
            .padding(.horizontal, 40)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

struct WallpaperSlot: View {
    let title: String
    let icon: String
    let wallpaperPath: String?
    let accentColor: Color
    let isActive: Bool
    let onClear: () -> Void
    
    @State private var isHovered = false
    
    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .foregroundStyle(accentColor)
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                if isActive {
                    Text("Active")
                        .font(.caption2)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(accentColor.opacity(0.2))
                        .foregroundStyle(accentColor)
                        .clipShape(Capsule())
                }
            }
            
            ZStack {
                if let path = wallpaperPath, FileManager.default.fileExists(atPath: path) {
                    if let nsImage = NSImage(contentsOfFile: path) {
                        Image(nsImage: nsImage)
                            .resizable()
                            .aspectRatio(16/10, contentMode: .fill)
                            .clipped()
                    }
                } else {
                    Rectangle()
                        .fill(Color.gray.opacity(0.08))
                        .aspectRatio(16/10, contentMode: .fill)
                        .overlay {
                            VStack(spacing: 8) {
                                Image(systemName: "photo")
                                    .font(.title)
                                Text("Not Set")
                                    .font(.caption)
                            }
                            .foregroundStyle(.tertiary)
                        }
                }
                
                if wallpaperPath != nil && isHovered {
                    Color.black.opacity(0.5)
                    Button {
                        onClear()
                    } label: {
                        Image(systemName: "trash")
                            .font(.title3)
                            .foregroundStyle(.white)
                            .padding(10)
                            .background(.red)
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isActive ? accentColor : Color.clear, lineWidth: 2)
            )
            .shadow(color: .black.opacity(0.1), radius: 8, y: 4)
            .onHover { isHovered = $0 }
        }
        .frame(maxWidth: .infinity)
    }
}

struct WallpaperCard: View {
    let wallpaper: WallpaperItem
    let isHovered: Bool
    let onTap: () -> Void
    
    @State private var manager = WallpaperManager.shared
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 0) {
                ZStack(alignment: .topTrailing) {
                    AsyncImage(url: URL(string: wallpaper.thumbs.large)) { phase in
                        switch phase {
                        case .empty:
                            Rectangle()
                                .fill(Color.gray.opacity(0.1))
                                .overlay {
                                    ProgressView()
                                }
                        case .success(let image):
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        case .failure:
                            Rectangle()
                                .fill(Color.gray.opacity(0.1))
                                .overlay {
                                    Image(systemName: "photo")
                                        .font(.largeTitle)
                                        .foregroundStyle(.secondary)
                                }
                        @unknown default:
                            EmptyView()
                        }
                    }
                    .frame(height: 180)
                    .clipped()
                    
                    Button {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                            manager.toggleFavorite(wallpaper.id)
                        }
                    } label: {
                        Image(systemName: manager.isFavorite(wallpaper.id) ? "heart.fill" : "heart")
                            .font(.title3)
                            .foregroundStyle(manager.isFavorite(wallpaper.id) ? .red : .white)
                            .symbolEffect(.bounce, value: manager.isFavorite(wallpaper.id))
                            .padding(8)
                            .background(.black.opacity(0.4))
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .padding(8)
                }
                
                HStack {
                    Text(wallpaper.resolution)
                        .font(.caption)
                        .fontWeight(.semibold)
                    
                    Spacer()
                    
                    HStack(spacing: 12) {
                        Label("\(formatCompact(wallpaper.views))", systemImage: "eye")
                        Label("\(formatCompact(wallpaper.favorites))", systemImage: "heart")
                    }
                    .font(.caption2)
                }
                .foregroundStyle(.secondary)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color(nsColor: .controlBackgroundColor))
            }
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .shadow(color: .black.opacity(isHovered ? 0.3 : 0.15), radius: isHovered ? 15 : 8, y: isHovered ? 8 : 4)
            .scaleEffect(isHovered ? 1.02 : 1.0)
        }
        .buttonStyle(.plain)
    }
    
    private func formatCompact(_ num: Int) -> String {
        if num >= 1000000 {
            return String(format: "%.1fM", Double(num) / 1000000)
        } else if num >= 1000 {
            return String(format: "%.1fK", Double(num) / 1000)
        }
        return "\(num)"
    }
}

struct WallpaperPreviewSheet: View {
    let wallpaper: WallpaperItem
    @Environment(\.dismiss) private var dismiss
    @State private var manager = WallpaperManager.shared
    @State private var selectedMode: WallpaperManager.AppearanceMode = .light
    @State private var isSettingWallpaper = false
    @State private var imageLoaded = false
    
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button { dismiss() } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .keyboardShortcut(.escape, modifiers: [])
                
                Spacer()
                
                Text(wallpaper.resolution)
                    .font(.headline)
                    .foregroundStyle(.secondary)
                
                Spacer()
                
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                        manager.toggleFavorite(wallpaper.id)
                    }
                } label: {
                    Image(systemName: manager.isFavorite(wallpaper.id) ? "heart.fill" : "heart")
                        .font(.title2)
                        .foregroundStyle(manager.isFavorite(wallpaper.id) ? .red : .secondary)
                        .symbolEffect(.bounce, value: manager.isFavorite(wallpaper.id))
                }
                .buttonStyle(.plain)
            }
            .padding()
            .background(.ultraThinMaterial)
            
            GeometryReader { geo in
                AsyncImage(url: URL(string: wallpaper.path)) { phase in
                    switch phase {
                    case .empty:
                        ZStack {
                            AsyncImage(url: URL(string: wallpaper.thumbs.large)) { thumbPhase in
                                if case .success(let image) = thumbPhase {
                                    image
                                        .resizable()
                                        .aspectRatio(contentMode: .fit)
                                        .blur(radius: 10)
                                }
                            }
                            ProgressView()
                                .scaleEffect(1.5)
                        }
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .onAppear { imageLoaded = true }
                    case .failure:
                        ContentUnavailableView("Failed to load", systemImage: "photo")
                    @unknown default:
                        EmptyView()
                    }
                }
                .frame(width: geo.size.width, height: geo.size.height)
            }
            .background(Color.black)
            
            VStack(spacing: 16) {
                HStack(spacing: 24) {
                    InfoBadge(icon: "eye", value: formatNumber(wallpaper.views))
                    InfoBadge(icon: "heart", value: formatNumber(wallpaper.favorites))
                    InfoBadge(icon: "doc", value: formatFileSize(wallpaper.fileSize))
                    InfoBadge(icon: "aspectratio", value: wallpaper.resolution)
                }
                
                HStack(spacing: 12) {
                    Picker("Mode", selection: $selectedMode) {
                        Label("Light", systemImage: "sun.max").tag(WallpaperManager.AppearanceMode.light)
                        Label("Dark", systemImage: "moon").tag(WallpaperManager.AppearanceMode.dark)
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 200)
                    
                    Button {
                        Task { await setWallpaper() }
                    } label: {
                        HStack {
                            if isSettingWallpaper {
                                ProgressView()
                                    .controlSize(.small)
                            } else {
                                Image(systemName: "display")
                            }
                            Text("Set Wallpaper")
                        }
                        .frame(width: 140)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(isSettingWallpaper)
                }
            }
            .padding()
            .background(.ultraThinMaterial)
        }
        .frame(minWidth: 800, minHeight: 600)
    }
    
    private func setWallpaper() async {
        isSettingWallpaper = true
        defer { isSettingWallpaper = false }
        
        do {
            try await manager.downloadAndSetWallpaper(wallpaper: wallpaper, forMode: selectedMode)
            dismiss()
        } catch {
            print("Failed to set wallpaper: \(error)")
        }
    }
    
    private func formatNumber(_ num: Int) -> String {
        if num >= 1000000 {
            return String(format: "%.1fM", Double(num) / 1000000)
        } else if num >= 1000 {
            return String(format: "%.1fK", Double(num) / 1000)
        }
        return "\(num)"
    }
    
    private func formatFileSize(_ bytes: Int) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: Int64(bytes))
    }
}

struct InfoBadge: View {
    let icon: String
    let value: String
    
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .foregroundStyle(.secondary)
            Text(value)
                .fontWeight(.medium)
        }
        .font(.callout)
    }
}

#Preview {
    WallpaperSearchView()
        .frame(width: 1000, height: 700)
}
