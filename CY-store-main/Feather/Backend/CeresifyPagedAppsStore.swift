//
//  CeresifyPagedAppsStore.swift
//  SY STORE
//
//  يدير تحميل تطبيقات مصدر أحمد صفحة صفحة عبر /api/apps/paged بدل تنزيل
//  repo.json كامل (12 ميجا / 8500 تطبيق) دفعة وحدة. نسخة مشتركة وحدة
//  (shared) تُستخدم من تبويب الرئيسية وتبويب التطبيقات مع بعض، عشان
//  التحميل يصير مرة وحدة والتبديل بين التبويبات ما يعيد الجلب.
//

import Foundation
import AltSourceKit

@MainActor
final class CeresifyPagedAppsStore: ObservableObject {
    static let shared = CeresifyPagedAppsStore()

    @Published private(set) var apps: [ASRepository.App] = []
    @Published private(set) var featured: [CeresifyStore.Featured] = []
    @Published private(set) var news: [ASRepository.News] = []
    @Published private(set) var isLoading = false
    @Published private(set) var isLoadingMore = false
    @Published private(set) var hasMore = true
    /// صار true إذا فشل أول تحميل (مثلاً endpoint الـ pagination غير متاح) —
    /// تُستخدم كإشارة للرجوع لمسار التحميل الكامل القديم كخطة بديلة آمنة.
    @Published private(set) var failedInitialLoad = false

    private let _pageSize = 100
    private var _currentPage = 0
    /// الفئة الحالية المرسلة للسيرفر (originalName). nil = بدون فلترة (الكل).
    private var _currentCategory: String?
    private var _hasLoadedOnce = false

    private init() {}

    /// التحميل الأول — مرة وحدة بس طول عمر الجلسة، إلا إذا انطلب refresh صريح.
    func loadInitialIfNeeded() async {
        guard !_hasLoadedOnce else { return }
        await _loadFirstPage(category: _currentCategory)
    }

    /// سحب للتحديث: يجبر إعادة تحميل طازجة من الصفحة الأولى بنفس الفئة الحالية.
    func refresh() async {
        await _loadFirstPage(category: _currentCategory)
    }

    /// تبديل الفئة (أو الرجوع لـ "الكل" بتمرير nil): يعيد من page=1 مع
    /// الفئة الجديدة. لا شيء يصير إذا الفئة نفسها المختارة أصلاً.
    func setCategory(_ category: String?) async {
        guard category != _currentCategory else { return }
        await _loadFirstPage(category: category)
    }

    /// يجيب الصفحة التالية ويلحقها بالقائمة الحالية (infinite scroll).
    func loadNextPageIfNeeded() async {
        guard hasMore, !isLoading, !isLoadingMore else { return }
        isLoadingMore = true
        defer { isLoadingMore = false }

        let nextPage = _currentPage + 1
        guard let result = await CeresifyStore.fetchPagedApps(
            page: nextPage,
            limit: _pageSize,
            category: _currentCategory
        ) else { return }

        _currentPage = nextPage
        apps.append(contentsOf: result.apps)
        hasMore = result.hasMore
    }

    private func _loadFirstPage(category: String?) async {
        guard !isLoading else { return }
        isLoading = true
        defer { isLoading = false }

        guard let result = await CeresifyStore.fetchPagedApps(
            page: 1,
            limit: _pageSize,
            category: category
        ) else {
            if !_hasLoadedOnce { failedInitialLoad = true }
            return
        }

        failedInitialLoad = false
        _currentCategory = category
        _currentPage = 1
        apps = result.apps
        hasMore = result.hasMore
        if let pageFeatured = result.featured {
            featured = pageFeatured
        }
        if let pageNews = result.news {
            news = pageNews
        }
        _hasLoadedOnce = true
    }
}
