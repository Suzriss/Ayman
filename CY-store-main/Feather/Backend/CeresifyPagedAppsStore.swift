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
    /// العدد الحقيقي الكامل من السيرفر (total) — يخالف apps.count اللي هو
    /// بس عدد الصفحات المحمّلة لحد الآن بالذاكرة. يُستخدم لعرض العداد.
    @Published private(set) var totalApps: Int = 0
    /// قائمة الفئات الكاملة من السيرفر (من ردّ أول صفحة) — بعكس
    /// categories(from:) اللي تبنى من التطبيقات المحمّلة بالذاكرة بس.
    @Published private(set) var categories: [CeresifyStore.Category] = []
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
    /// رقم جيل كل طلب صفحة أولى — يمنع نتيجة قديمة (مثلاً فئة انستبدلت بسرعة)
    /// من الكتابة فوق نتيجة أحدث لما الطلبات تترتب بشكل مختلف عن الشبكة.
    private var _loadGeneration = 0

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
        // تفريغ القائمة الحالية فوراً عشان ما تظهر تطبيقات الفئة القديمة
        // وهي متلبسة على أنها تطبيقات الفئة الجديدة أثناء التحميل.
        apps = []
        hasMore = true
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

    /// يحمّل الصفحة الأولى لفئة معيّنة. عمداً بدون guard على isLoading —
    /// لو انحظر على isLoading == true، طلب تبديل فئة يوصل أثناء تحميل سابق
    /// كان ينرفض بصمت وتضل الفئة الجديدة بدون تطبيقات لين يسوي المستخدم
    /// ريفريش يدوي. بدالها نستخدم رقم جيل: كل نداء ياخذ رقم جيل جديد، وبس
    /// أحدث نتيجة توصل هي اللي تُطبّق — أي نتيجة قديمة متأخرة تُرمى.
    private func _loadFirstPage(category: String?) async {
        _loadGeneration += 1
        let generation = _loadGeneration
        isLoading = true
        defer {
            // ما نطفي isLoading إلا إذا لسه إحنا أحدث طلب — طلب أحدث لاحق
            // هو المسؤول عن إطفائها لما يخلص هو.
            if generation == _loadGeneration { isLoading = false }
        }

        guard let result = await CeresifyStore.fetchPagedApps(
            page: 1,
            limit: _pageSize,
            category: category
        ) else {
            if generation == _loadGeneration, !_hasLoadedOnce { failedInitialLoad = true }
            return
        }

        // نتيجة تحميل قديم انلغى بتبديل فئة أحدث أثناء الانتظار — تجاهلها.
        guard generation == _loadGeneration else { return }

        failedInitialLoad = false
        _currentCategory = category
        _currentPage = 1
        apps = result.apps
        hasMore = result.hasMore
        totalApps = result.total
        if let pageFeatured = result.featured {
            featured = pageFeatured
        }
        if let pageNews = result.news {
            news = pageNews
        }
        if let pageCategories = result.categories, !pageCategories.isEmpty {
            categories = pageCategories
        }
        _hasLoadedOnce = true
    }
}
