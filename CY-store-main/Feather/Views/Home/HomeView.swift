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

    @State private var _selectedRoute: SourceAppRoute?
    @State private var _currentBannerIndex = 0

    /// خطة بديلة كاملة (سورسات + repo.json) — تُملأ فقط لو فشل التحميل
    /// المجزّأ الأول (failedInitialLoad)، عشان الرئيسية ما تضل فاضية.
    @State private var _legacyAllApps: [(source: ASRepository, app: ASRepository.App)] = []
    @State private var _legacyBanners: [ASRepository.News] = []
    @State private var _legacyFeatured: [CeresifyStore.Featured] = []
    @State private var _isBackgroundLoading = false
    @State private var _hasStartedLegacyFallback = false

    private let bannerTimer = Timer.publish(every: 3.5, on: .main, in: .common).autoconnect()

    @FetchRequest(
        entity: AltSource.entity(),
        sortDescriptors: [NSSortDescriptor(keyPath: \AltSource.name, ascending: true)],
        animation: .snappy
    ) private var _sources: FetchedResults<AltSource>

    private var _displayFeatured: [CeresifyStore.Featured] {
        _pagedStore.featured.isEmpty ? _legacyFeatured : _pagedStore.featured
    }

    /// كل التطبيقات (لغرض التنقل من البنرات/المميّزين) — من التحميل المجزّأ
    /// السريع عادةً، أو من الخطة البديلة الكاملة لو فشل الأول.
    private var _allApps: [(source: ASRepository, app: ASRepository.App)] {
        guard !_pagedStore.apps.isEmpty else { return _legacyAllApps }
        let synthetic = ASRepository(id: "ceresify", name: nil, apps: _pagedStore.apps)
        return _pagedStore.apps.map { (source: synthetic, app: $0) }
    }

    /// البنرات الإعلانية — من ردّ الصفحة الأولى (سريع)، أو من الخطة البديلة
    /// الكاملة لو فشل التحميل المجزّأ.
    private var _banners: [ASRepository.News] {
        let pagedBanners = _pagedStore.news.filter { $0.imageURL != nil }
        return pagedBanners.isEmpty ? _legacyBanners : pagedBanners
    }

    /// يبحث عن تطبيق ببصمة bundleId داخل فهرس التنقل الحالي.
    private func _findApp(byId appId: String) -> (source: ASRepository, app: ASRepository.App)? {
        _allApps.first(where: { $0.app.id == appId })
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
                await _loadLegacyFallbackIfNeeded(force: true)
            }
        }
        .task(id: Array(_sources)) {
            await _pagedStore.loadInitialIfNeeded()
            await _loadLegacyFallbackIfNeeded()
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

    // MARK: - الخطة البديلة الكاملة (تشتغل بس لو فشل التحميل المجزّأ الأول)
    /// تنزّل السورسات كاملة (الطريقة القديمة) عشان الرئيسية ما تضل فاضية لو
    /// endpoint الـ pagination غير متاح. لا تشتغل إطلاقاً بالمسار الطبيعي —
    /// تُفعَّل فقط لما _pagedStore.failedInitialLoad تصير true.
    private func _loadLegacyFallbackIfNeeded(force: Bool = false) async {
        guard _pagedStore.failedInitialLoad else { return }
        guard force || !_hasStartedLegacyFallback else { return }
        _hasStartedLegacyFallback = true
        _isBackgroundLoading = true
        defer { _isBackgroundLoading = false }

        await viewModel.fetchSources(_sources, refresh: force)

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
        let legacyFeatured = await CeresifyStore.fetchFeatured()

        self._legacyAllApps = allApps
        self._legacyBanners = validBanners
        self._legacyFeatured = legacyFeatured

        if self._currentBannerIndex >= validBanners.count {
            self._currentBannerIndex = 0
        }
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
