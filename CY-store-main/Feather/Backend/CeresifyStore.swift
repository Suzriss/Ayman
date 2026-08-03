//
//  CeresifyStore.swift
//  SY STORE
//
//  مصدر أحمد المصنّف: البنرات والفئات تجيان من لوحة تحكم Ceresify
//  (repo.json نفسه يُضاف كسورس AltStore عادي عبر AltSourceKit، هذا الملف
//  يجيب فقط قائمة الفئات المُدارة من اللوحة عشان نبني سلايدر الفئات).
//

import Foundation

enum CeresifyStore {
    /// سورس أحمد المصنّف — نفس الرابط المطلوب إضافته كمصدر افتراضي.
    static let repoURLString = "\(Ceresify.baseURL)/api/repo.json"

    struct Category: Decodable, Identifiable, Hashable {
        var originalName: String?
        var displayName: String
        var icon: String?
        var isCustom: Bool
        var customApps: [String]

        var id: String { originalName ?? displayName }

        /// هل التطبيق (عبر bundleIdentifier أو حقل category) يتبع لهذه الفئة؟
        func matches(bundleId: String?, category: String?) -> Bool {
            if isCustom {
                guard let bundleId else { return false }
                return customApps.contains(bundleId)
            }
            return category == originalName
        }
    }

    private struct CategoriesResponse: Decodable {
        var categories: [Category]
    }

    static func fetchCategories() async -> [Category] {
        guard let url = URL(string: "\(Ceresify.baseURL)/api/categories") else { return [] }
        guard let (data, _) = try? await URLSession.shared.data(from: url) else { return [] }
        return (try? JSONDecoder().decode(CategoriesResponse.self, from: data))?.categories ?? []
    }
}
