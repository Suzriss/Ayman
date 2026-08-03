//
//  CategoryChipsBar.swift
//  SY STORE
//
//  سلايدر أفقي لفئات مصدر أحمد، تُدار من لوحة تحكم Ceresify.
//

import SwiftUI

struct CategoryChipsBar: View {
    var categories: [CeresifyStore.Category]
    var selected: CeresifyStore.Category?
    var onSelect: (CeresifyStore.Category?) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                _chip(title: "الكل", isSelected: selected == nil) {
                    onSelect(nil)
                }
                ForEach(categories) { category in
                    let icon = category.icon?.trimmingCharacters(in: .whitespaces)
                    let title = (icon?.isEmpty == false) ? "\(icon!) \(category.displayName)" : category.displayName
                    _chip(title: title, isSelected: selected == category) {
                        onSelect(category)
                    }
                }
            }
            .padding(.horizontal, 16)
        }
    }

    @ViewBuilder
    private func _chip(title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline.weight(.medium))
                .lineLimit(1)
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .background(isSelected ? Color.accentColor : Color(uiColor: .secondarySystemBackground))
                .foregroundColor(isSelected ? .white : .primary)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}
