//
//  SourceAppsView.swift
//  SY STORE
//
//  Created by samara on 1.05.2025.
//  Modified for SY STORE - Unified Store.
//

import SwiftUI
import AltSourceKit
import NimbleViews
import UIKit

// MARK: - Extension: View (Sort)
extension SourceAppsView {
	enum SortOption: String, CaseIterable {
		case `default` = "default"
		case name
		case date

		var displayName: String {
			switch self {
			case .default:  return "الافتراضي"
			case .name: 	return "الاسم"
			case .date: 	return "التاريخ"
			}
		}
	}
}

// MARK: - View
struct SourceAppsView: View {
	@AppStorage("SYStore.sortOptionRawValue") private var _sortOptionRawValue: String = SortOption.default.rawValue
	@AppStorage("SYStore.sortAscending") private var _sortAscending: Bool = true

	@State private var _sortOption: SortOption = .default
	@State private var _selectedRoute: SourceAppRoute?
    @State private var _selectedCategory: CeresifyStore.Category?

	@State var isLoading = true
	@State var hasLoadedOnce = false
	@State private var _searchText = ""

	var object: [AltSource]
	/// فئات مصدر أحمد المُدارة من لوحة التحكم (سلايدر). فاضية = بدون فئات (باقي السورسات).
	var categories: [CeresifyStore.Category] = []
	/// true لمصدر أحمد المصنّف — يفعّل التحميل المجزّأ (pagination) بدل انتظار
	/// تنزيل السورس كامل. أي سورس ثاني يبقى على المسار القديم.
	var isCeresifySource: Bool = false
	@ObservedObject var viewModel: SourcesViewModel
	@ObservedObject private var _pagedStore = CeresifyPagedAppsStore.shared
	@State private var _sources: [ASRepository]?

	// MARK: Body
	var body: some View {
		ZStack {
			if isCeresifySource {
				_pagedContent
			} else if
				let _sources,
				!_sources.isEmpty
			{
				SourceAppsTableRepresentableView(
					sources: _sources,
					searchText: $_searchText,
					sortOption: $_sortOption,
					sortAscending: $_sortAscending,
					categories: categories,
					selectedCategory: $_selectedCategory,
					onSelect: {self._selectedRoute = $0}
				)
				.ignoresSafeArea()
			} else {
				CeresifyLoaderView()
			}
		}
        // تثبيت العنوان ليكون "التطبيقات" دائماً بدلاً من عرض عدد المصادر
		.navigationTitle("التطبيقات")
		.searchable(text: $_searchText, placement: .platform(), prompt: "ابحث في التطبيقات...")
		.toolbar {
			NBToolbarMenu(
				systemImage: "arrow.up.arrow.down.circle",
				style: .icon,
				placement: .topBarTrailing
			) {
				_sortActions()
			}
		}
		.onAppear {
			if isCeresifySource {
				Task { await _pagedStore.loadInitialIfNeeded() }
			}
			if !hasLoadedOnce, viewModel.isFinished {
				_load()
				hasLoadedOnce = true
			}
			_sortOption = SortOption(rawValue: _sortOptionRawValue) ?? .default
		}
		.onChange(of: viewModel.isFinished) { _ in
			_load()
		}
		.onChange(of: _sortOption) { newValue in
			_sortOptionRawValue = newValue.rawValue
		}
        .onChange(of: _selectedCategory) { newValue in
            guard isCeresifySource else { return }
            // الفئات المخصّصة (isCustom) مبنية على قائمة bundleId يدوية، والسيرفر
            // ما يعرف يفلترها — نرجّع فلتر السيرفر لـ "الكل" ونخلي الفلترة
            // المحلية بـ SourceAppsTableRepresentableView تسوي الشغل.
            let serverCategory = (newValue?.isCustom == true) ? nil : newValue?.originalName
            Task { await _pagedStore.setCategory(serverCategory) }
        }
		.navigationDestinationIfAvailable(item: $_selectedRoute) { route in
			SourceAppsDetailView(source: route.source, app: route.app)
		}
	}

	/// محتوى مصدر أحمد المصنّف — مبني من التحميل المجزّأ. لو فشل (مثلاً السيرفر
	/// مو جاهز بعد)، نرجع تلقائياً لمسار التحميل الكامل القديم كخطة بديلة آمنة.
	@ViewBuilder
	private var _pagedContent: some View {
		if !_pagedStore.apps.isEmpty {
			SourceAppsTableRepresentableView(
				sources: [_pagedRepository],
				searchText: $_searchText,
				sortOption: $_sortOption,
				sortAscending: $_sortAscending,
				categories: categories,
				selectedCategory: $_selectedCategory,
				onSelect: { self._selectedRoute = $0 },
				onLoadMore: { Task { await _pagedStore.loadNextPageIfNeeded() } },
				onRefresh: { Task { await _pagedStore.refresh() } },
				isRefreshing: _pagedStore.isLoading,
				totalCount: _pagedStore.totalApps
			)
			.ignoresSafeArea()
		} else if _pagedStore.failedInitialLoad, let _sources, !_sources.isEmpty {
			SourceAppsTableRepresentableView(
				sources: _sources,
				searchText: $_searchText,
				sortOption: $_sortOption,
				sortAscending: $_sortAscending,
				categories: categories,
				selectedCategory: $_selectedCategory,
				onSelect: { self._selectedRoute = $0 }
			)
			.ignoresSafeArea()
		} else {
			CeresifyLoaderView()
		}
	}

	private var _pagedRepository: ASRepository {
		ASRepository(
			id: object.first?.identifier,
			name: object.first?.name,
			apps: _pagedStore.apps
		)
	}

	private func _load() {
		isLoading = true

		Task {
			let loadedSources = object.compactMap { viewModel.sources[$0] }
			_sources = loadedSources
			withAnimation(.easeIn(duration: 0.2)) {
				isLoading = false
			}
		}
	}

	struct SourceAppRoute: Identifiable, Hashable {
		let source: ASRepository
		let app: ASRepository.App
		let id: String = UUID().uuidString
	}
}

// MARK: - Extension: View (Sort)
extension SourceAppsView {
	@ViewBuilder
	private func _sortActions() -> some View {
		Section("ترتيب حسب") {
			ForEach(SortOption.allCases, id: \.displayName) { opt in
				_sortButton(for: opt)
			}
		}
	}

	private func _sortButton(for option: SortOption) -> some View {
		Button {
			if _sortOption == option {
				_sortAscending.toggle()
			} else {
				_sortOption = option
				_sortAscending = true
			}
		} label: {
			HStack {
				Text(option.displayName)
				Spacer()
				if _sortOption == option {
					Image(systemName: _sortAscending ? "chevron.up" : "chevron.down")
				}
			}
		}
	}
}

extension View {
	@ViewBuilder
	func navigationDestinationIfAvailable<Item: Identifiable & Hashable, Destination: View>(
		item: Binding<Item?>,
		@ViewBuilder destination: @escaping (Item) -> Destination
	) -> some View {
		if #available(iOS 17, *) {
			self.navigationDestination(item: item, destination: destination)
		} else {
			self
		}
	}
}
