//
//  CeresifyStore.swift
//  SY STORE
//
//  مصدر أحمد المصنّف: البنرات والفئات تجيان من لوحة تحكم Ceresify
//  (repo.json نفسه يُضاف كسورس AltStore عادي عبر AltSourceKit، هذا الملف
//  يجيب فقط قائمة الفئات المُدارة من اللوحة عشان نبني سلايدر الفئات).
//

import Foundation
import AltSourceKit

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

    // MARK: - التطبيقات المميّزة (بطاقات كبيرة بالرئيسية)

    struct Featured: Decodable, Identifiable, Hashable {
        var bundleIdentifier: String
        var title: String
        var subtitle: String
        var imageURL: URL?

        var id: String { bundleIdentifier + (imageURL?.absoluteString ?? "") }
    }

    private struct RepoFeaturedResponse: Decodable {
        var featured: [Featured]?
    }

    /// يجيب قائمة المميّزين من repo.json (مع تجاوز الكاش عشان تنعكس تعديلات اللوحة).
    static func fetchFeatured() async -> [Featured] {
        guard let url = URL(string: "\(repoURLString)?nocache=1") else { return [] }
        guard let (data, _) = try? await URLSession.shared.data(from: url) else { return [] }
        return (try? JSONDecoder().decode(RepoFeaturedResponse.self, from: data))?.featured ?? []
    }

    /// يبني سلايدر الفئات مباشرة من حقل category الموجود فعلياً على تطبيقات
    /// السورس (repo.json)، بدل الاعتماد فقط على /api/categories. تُستخدم
    /// كخطة بديلة لما اللوحة ما ترجّع فئات، وتضمن إن الفئات المعروضة تطابق
    /// تقسيمات السورس الحقيقية دايماً حتى لو تغيّرت.
    static func categories(from apps: [ASRepository.App]) -> [Category] {
        var counts: [String: Int] = [:]
        var order: [String] = []

        for app in apps {
            guard let raw = app.category?.trimmingCharacters(in: .whitespacesAndNewlines), !raw.isEmpty else { continue }
            if counts[raw] == nil { order.append(raw) }
            counts[raw, default: 0] += 1
        }

        return order
            .sorted { (counts[$0] ?? 0) > (counts[$1] ?? 0) }
            .map { raw in
                Category(originalName: raw, displayName: raw, icon: nil, isCustom: false, customApps: [])
            }
    }
}
