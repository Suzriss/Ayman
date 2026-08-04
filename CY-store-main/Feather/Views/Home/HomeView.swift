//
//  HomeView.swift
//  CY STORE
//
//  Created by samara on 13.05.2026.
//  Modified for CY STORE - Safe Native Banners & Auto-Scroll.
//

import SwiftUI
import CoreData
import AltSourceKit
import NimbleViews

struct HomeView: View {
    @Environment(\.openURL) var openURL
    @StateObject var viewModel = SourcesViewModel.shared
    @ObservedObject private var _pagedStore = CeresifyPagedAppsStore.shared

    @State private var _allApps: [(source: ASRepository, app: ASRepository.App)] = []
    @State private var _banners: [ASRepository.News] = []
    /// خطة بديلة لو رد ?page=1 ما رجّع مميّزين (مثلاً endpoint الـ pagination
    /// مو جاهز بعد) — نجيبهم من المسار الكامل القديم بدل ما القسم يضل فاضي.
    @State private var _legacyFeatured: [CeresifyStore.Featured] = []
    @State private var _selectedRoute: SourceAppRoute?
    @State private var _currentBannerIndex = 0
    /// جلب البنرات/كل التطبيقات (لغرض التنقل) يشتغل بالخلفية بدون ما يعطّل ظهور
    /// المحتوى السريع من التحميل المجزّأ.
    @State private var _isBackgroundLoading = true
    @State private var _hasStartedBackgroundLoad = false

    private let bannerTimer = Timer.publish(every: 3.5, on: .main, in: .common).autoconnect()

    @FetchRequest(
        entity: AltSource.entity(),
        sortDescriptors: [NSSortDescriptor(keyPath: \AltSource.name, ascending: true)],
        animation: .snappy
    ) private var _sources: FetchedResults<AltSource>

    private var _displayFeatured: [CeresifyStore.Featured] {
        _pagedStore.featured.isEmpty ? _legacyFeatured : _pagedStore.featured
    }

    /// يبحث عن تطبيق ببصمة bundleId — من التحميل المجزّأ السريع أول شي، وبعدين
    /// من الفهرس الكامل (يجهز بالخلفية) لما يوصل.
    private func _findApp(byId appId: String) -> (source: ASRepository, app: ASRepository.App)? {
        if let match = _allApps.first(where: { $0.app.id == appId }) {
            return match
        }
        guard let app = _pagedStore.apps.first(where: { $0.id == appId }) else { return nil }
        let synthetic = ASRepository(id: "ceresify", name: nil, apps: _pagedStore.apps)
        return (source: synthetic, app: app)
    }

    var body: some View {
        NBNavigationView("الرئيسية") {
            ZStack {
                let stillLoading = _pagedStore.isLoading || _isBackgroundLoading

                if stillLoading && _banners.isEmpty && _displayFeatured.isEmpty {
                    CeresifyLoaderView(message: "جاري التحديث...")
                } else if _banners.isEmpty && _displayFeatured.isEmpty {
                    if #available(iOS 17, *) {
                        ContentUnavailableView {
                            Label("لا توجد تطبيقات", systemImage: "tray.fill")
                        } description: {
                            Text("لم يتم العثور على تطبيقات أو عروض حالياً.")
                        }
                    } else {
                        Text("لا توجد تطبيقات")
                            .foregroundColor(.secondary)
                    }
                } else {
                    List {
                        _featuredSection

                        // MARK: - قسم البنرات الإعلانية (تُدار من لوحة تحكم Ceresify)
                        if !_banners.isEmpty {
                            Section {
                                TabView(selection: $_currentBannerIndex) {
                                    ForEach(_banners.indices, id: \.self) { index in
                                        let banner = _banners[index]

                                        Button {
                                            if let url = banner.url {
                                                openURL(url)
                                            } else if let appID = banner.appID.flatMap({ $0 }),
                                                      let targetApp = _findApp(byId: appID) {
                                                _selectedRoute = SourceAppRoute(source: targetApp.source, app: targetApp.app)
                                            }
                                        } label: {
                                            if let imgUrl = banner.imageURL {
                                                AsyncImage(url: imgUrl) { phase in
                                                    if let image = phase.image {
                                                        image
                                                            .resizable()
                                                            .aspectRatio(contentMode: .fill)
                                                    } else if phase.error != nil {
                                                        Rectangle()
                                                            .fill(Color(uiColor: .secondarySystemBackground))
                                                            .overlay(Image(systemName: "photo.fill").foregroundColor(.secondary))
                                                    } else {
                                                        Rectangle()
                                                            .fill(Color(uiColor: .secondarySystemBackground))
                                                            .overlay(ProgressView())
                                                    }
                                                }
                                                .frame(height: 190)
                                                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                                                .padding(.horizontal, 16)
                                            }
                                        }
                                        .buttonStyle(.plain)
                                        .tag(index)
                                    }
                                }
                                .frame(height: 230)
                                .tabViewStyle(.page(indexDisplayMode: .always))
                                .listRowInsets(EdgeInsets())
                                .listRowBackground(Color.clear)
                                .listRowSeparator(.hidden)
                                .onReceive(bannerTimer) { _ in
                                    if !_banners.isEmpty {
                                        withAnimation(.easeInOut(duration: 0.5)) {
                                            _currentBannerIndex = (_currentBannerIndex + 1) % _banners.count
                                        }
                                    }
                                }
                            }
                        }
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .compatNavigationDestination(item: $_selectedRoute) { route in
                SourceAppsDetailView(source: route.source, app: route.app)
            }
            .refreshable {
                await _pagedStore.refresh()
                await _loadBackgroundData(force: true)
            }
        }
        .task(id: Array(_sources)) {
            await _pagedStore.loadInitialIfNeeded()
            await _loadBackgroundData()
        }
    }


    // MARK: - أقسام مفصولة (لتخفيف الحِمل عن مترجم SwiftUI)
    @ViewBuilder
    private var _featuredSection: some View {
        // MARK: - قسم التطبيقات المميّزة (بطاقات كبيرة تُدار من اللوحة)
        if !_displayFeatured.isEmpty {
            Section {
                ForEach(_displayFeatured) { item in
                    _featuredRow(item)
                }
            }
        }
    }

    @ViewBuilder
    private func _featuredRow(_ item: CeresifyStore.Featured) -> some View {
        Button {
            _selectFeatured(item)
        } label: {
            FeaturedCardView(item: item)
        }
        .buttonStyle(.plain)
        .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
        .listRowBackground(Color.clear)
        .listRowSeparator(.hidden)
    }

    private func _selectFeatured(_ item: CeresifyStore.Featured) {
        if let target = _findApp(byId: item.bundleIdentifier) {
            _selectedRoute = SourceAppRoute(source: target.source, app: target.app)
        }
    }

    // MARK: - جلب البنرات وفهرس التنقل الكامل (بالخلفية، ما يعطّل عرض المميّزين)
    private func _loadBackgroundData(force: Bool = false) async {
        // نحمّل مرة وحدة فقط — التبديل بين الخانات ما يعيد الجلب.
        // (force = true عند السحب للتحديث)
        guard force || !_hasStartedBackgroundLoad else { return }
        _hasStartedBackgroundLoad = true
        _isBackgroundLoading = true

        do {
            await viewModel.fetchSources(_sources, refresh: force)
        } catch {
            print("تحميل صامت للسورسات المتاحة...")
        }

        let rawSources = _sources

        var allApps: [(source: ASRepository, app: ASRepository.App)] = []
        var allBanners: [ASRepository.News] = []

        for rawSource in rawSources {
            guard let source = viewModel.sources[rawSource] else { continue }

            for app in source.apps {
                allApps.append((source: source, app: app))
            }

            // البنرات تجي من مصدر أحمد المصنّف فقط (تدار من لوحة تحكم Ceresify)
            if let sourceURLString = rawSource.sourceURL?.absoluteString.lowercased(),
               sourceURLString == CeresifyStore.repoURLString.lowercased(),
               let news = source.news {
                allBanners.append(contentsOf: news)
            }
        }

        let validBanners = allBanners.filter { $0.imageURL != nil }

        // خطة بديلة للمميّزين فقط إذا فشل المسار السريع (paged) يجيبهم.
        var legacyFeatured: [CeresifyStore.Featured] = []
        if _pagedStore.featured.isEmpty {
            legacyFeatured = await CeresifyStore.fetchFeatured()
        }

        self._allApps = allApps
        self._banners = validBanners
        self._legacyFeatured = legacyFeatured

        if self._currentBannerIndex >= validBanners.count {
            self._currentBannerIndex = 0
        }
        self._isBackgroundLoading = false
    }
}

// MARK: - Supporting Types
struct SourceAppRoute: Identifiable, Hashable {
    let source: ASRepository
    let app: ASRepository.App
    let id: String = UUID().uuidString
}

// MARK: - Extension for Navigation
extension View {
    @ViewBuilder
    func compatNavigationDestination<Item: Identifiable & Hashable, Destination: View>(
        item: Binding<Item?>,
        @ViewBuilder destination: @escaping (Item) -> Destination
    ) -> some View {
        if #available(iOS 16.0, *) {
            self.navigationDestination(isPresented: Binding(
                get: { item.wrappedValue != nil },
                set: { if !$0 { item.wrappedValue = nil } }
            )) {
                if let selectedItem = item.wrappedValue {
                    destination(selectedItem)
                }
            }
        } else {
            self.background(
                NavigationLink(
                    isActive: Binding(
                        get: { item.wrappedValue != nil },
                        set: { if !$0 { item.wrappedValue = nil } }
                    )
                ) {
                    if let selectedItem = item.wrappedValue {
                        destination(selectedItem)
                    } else {
                        EmptyView()
                    }
                } label: {
                    EmptyView()
                }
                .hidden()
            )
        }
    }
}
