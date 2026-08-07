//
//  SourcesView.swift
//  SY STORE
//
//  Created by samara on 10.04.2025.
//  Modified for Direct Apps Display.
//

import CoreData
import AltSourceKit
import SwiftUI
import NimbleViews

// MARK: - View
struct SourcesView: View {
    @StateObject var viewModel = SourcesViewModel.shared
    @State private var _categories: [CeresifyStore.Category] = []
    @State private var _didLoadCategories = false
    @State private var _isOtherSourcesPresenting = false

    @FetchRequest(
        entity: AltSource.entity(),
        sortDescriptors: [NSSortDescriptor(keyPath: \AltSource.name, ascending: true)],
        animation: .snappy
    ) private var _sources: FetchedResults<AltSource>

    // مصدر أحمد المصنّف — نفس الرابط اللي نستورده تلقائياً بالأسفل
    private var _ahmadSource: AltSource? {
        _sources.first {
            $0.sourceURL?.absoluteString.lowercased() == CeresifyStore.repoURLString.lowercased()
        }
    }

    private var _otherSources: [AltSource] {
        _sources.filter {
            $0.sourceURL?.absoluteString.lowercased() != CeresifyStore.repoURLString.lowercased()
        }
    }

    // MARK: Body
    var body: some View {
        NBNavigationView("التطبيقات") {
            Group {
                if let ahmad = _ahmadSource {
                    SourceAppsView(object: [ahmad], categories: _categories, isCeresifySource: true, viewModel: viewModel)
                } else {
                    // لسه سورس أحمد ما انسحب أو انحذف — نعرض كل السورسات المتوفرة مؤقتاً بدون فئات
                    SourceAppsView(object: Array(_sources), viewModel: viewModel)
                }
            }
            .toolbar {
                NBToolbarButton(
                    systemImage: "tray.2",
                    placement: .topBarLeading
                ) {
                    _isOtherSourcesPresenting = true
                }
            }
        }
        .task(id: Array(_sources)) {
            _importDefaultSources() // جلب المصادر تلقائياً
            // الفئات ما تنتظر تنزيل السورسات كاملة (فيها ريبو أحمد ١٢ ميجا) —
            // تجيب نفسها بشكل مستقل وسريع من اللوحة، وتظهر قبل التطبيقات.
            async let sourcesFetch: () = viewModel.fetchSources(_sources)
            if !_didLoadCategories {
                await _loadCategories()
                _didLoadCategories = true
            }
            await sourcesFetch
        }
        .refreshable {
            if _ahmadSource != nil {
                await CeresifyPagedAppsStore.shared.refresh()
            }
            async let sourcesFetch: () = viewModel.fetchSources(_sources, refresh: true)
            await _loadCategories()
            _didLoadCategories = true
            await sourcesFetch
        }
        .sheet(isPresented: $_isOtherSourcesPresenting) {
            OtherSourcesListView(sources: _otherSources, viewModel: viewModel)
        }
    }

    /// يجيب فئات اللوحة (/api/categories) وفئات ردّ /api/apps/paged بالتوازي —
    /// نفس الطلب اللي أصلاً يجيب التطبيقات ويظهرها بالسلايدر، فتوصل بنفس
    /// سرعة التطبيقات بالضبط. نعرض فئات الـ paged فوراً أول ما توصل عشان
    /// السلايدر ما يضل متأخر عن التطبيقات، وبعدين نرقّي لفئات اللوحة (أسماء
    /// وأيقونات أحسن) إذا وصلت ورجّعت شي فعلي. وكخطة أخيرة، نبنيها من
    /// التطبيقات المحمّلة فعلياً (ناقصة، بس أفضل من ولا شي).
    private func _loadCategories() async {
        guard _ahmadSource != nil else { return }

        async let panelTask = CeresifyStore.fetchCategories()

        await CeresifyPagedAppsStore.shared.loadInitialIfNeeded()
        let serverCategories = CeresifyPagedAppsStore.shared.categories
        if !serverCategories.isEmpty {
            _categories = serverCategories
        }

        let panel = await panelTask
        if !panel.isEmpty {
            _categories = panel
            return
        }
        if !serverCategories.isEmpty { return }

        let appCategories = CeresifyStore.categories(from: CeresifyPagedAppsStore.shared.apps)
        guard !appCategories.isEmpty else { return }
        _categories = appCategories
    }

    // MARK: - دالة استيراد المصادر
    private func _importDefaultSources() {
        let myStoreSources = [
            // === المصادر المعتمدة للمتجر ===
            CeresifyStore.repoURLString,
            "https://raw.githubusercontent.com/ipa-black/ATTACK-repo/refs/heads/main/ATTACK.json",
            "https://community-apps.sidestore.io/sidecommunity.json",
            "https://repository.apptesters.org"
        ]

        for source in myStoreSources {
            // التحقق مما إذا كان السورس موجوداً مسبقاً لمنع التكرار
            let exists = _sources.contains { $0.sourceURL?.absoluteString.lowercased() == source.lowercased() }
            if !exists {
                FR.handleSource(source, silent: true) { }
            }
        }
    }
}
