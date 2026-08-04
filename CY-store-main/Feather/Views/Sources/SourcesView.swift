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

    /// يجيب فئات لوحة التحكم أولاً — رد صغير وسريع مستقل عن تنزيل السورسات
    /// كاملة، عشان السلايدر يظهر قبل ما تجهز التطبيقات. إذا اللوحة رجّعت
    /// فاضية (ما فيها فئات مُدارة بعد) نبنيها من التطبيقات المحمّلة عبر
    /// المسار المجزّأ السريع (بدون انتظار تنزيل ريبو أحمد كامل).
    private func _loadCategories() async {
        guard _ahmadSource != nil else { return }

        let panel = await CeresifyStore.fetchCategories()
        if !panel.isEmpty {
            _categories = panel
            return
        }

        await CeresifyPagedAppsStore.shared.loadInitialIfNeeded()
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
