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
                    SourceAppsView(object: [ahmad], categories: _categories, viewModel: viewModel)
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
            await viewModel.fetchSources(_sources)
            _importDefaultSources() // جلب المصادر تلقائياً
            if !_didLoadCategories {
                await _loadCategories()
                _didLoadCategories = true
            }
        }
        .refreshable {
            await viewModel.fetchSources(_sources, refresh: true)
            await _loadCategories()
            _didLoadCategories = true
        }
        .sheet(isPresented: $_isOtherSourcesPresenting) {
            OtherSourcesListView(sources: _otherSources, viewModel: viewModel)
        }
    }

    /// يجيب فئات لوحة التحكم أولاً، وإذا رجّعت فاضية (اللوحة ما فيها فئات
    /// مُدارة بعد) يبني الفئات مباشرة من تقسيمات سورس أحمد نفسه.
    private func _loadCategories() async {
        guard let ahmad = _ahmadSource, let apps = viewModel.sources[ahmad]?.apps else { return }
        let appCategories = CeresifyStore.categories(from: apps)
        guard !appCategories.isEmpty else { return }

        // نعرض الفئات المبنية محلياً فوراً بدل انتظار رد الشبكة، وبعدين نغنيها
        // بالاسم/الأيقونة من اللوحة إذا توفرت دون ما نأخر ظهور السلايدر.
        _categories = appCategories

        let panel = await CeresifyStore.fetchCategories()
        let byName = Dictionary(panel.compactMap { c in c.originalName.map { ($0, c) } },
                                uniquingKeysWith: { first, _ in first })

        _categories = appCategories.map { cat in
            guard let match = byName[cat.originalName ?? cat.displayName] else { return cat }
            var enriched = cat
            enriched.displayName = match.displayName
            enriched.icon = match.icon
            return enriched
        }
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
                FR.handleSource(source) { }
            }
        }
    }
}
