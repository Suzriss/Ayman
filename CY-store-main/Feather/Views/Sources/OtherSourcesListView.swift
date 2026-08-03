//
//  OtherSourcesListView.swift
//  SY STORE
//
//  باقي السورسات (غير مصدر أحمد المصنّف) — المستخدم يدخلها يدوياً،
//  تطبيقاتها تظهر بدون فئات ولا بانر.
//

import SwiftUI
import NimbleViews

struct OtherSourcesListView: View {
	var sources: [AltSource]
	@ObservedObject var viewModel: SourcesViewModel

	var body: some View {
		NBNavigationView("المصادر الأخرى") {
			List {
				if sources.isEmpty {
					Text("لا توجد مصادر إضافية")
						.foregroundColor(.secondary)
				} else {
					ForEach(sources, id: \.self) { source in
						NavigationLink {
							SourceAppsView(object: [source], viewModel: viewModel)
						} label: {
							SourcesCellView(source: source)
						}
					}
				}
			}
			.toolbar {
				NBToolbarButton(role: .close)
			}
		}
	}
}
