//
//  AboutView.swift
//  SY STORE
//
//  Created by samara on 30.04.2025.
//  Modified for SY STORE.
//

import SwiftUI
import NimbleViews
import NimbleJSON

// MARK: - Extension: Model
extension AboutView {
	struct CreditsModel: Codable, Hashable {
		let name: String
		let desc: String
		let link: String
	}
}

// MARK: - View
struct AboutView: View {
	@State private var _credits: [CreditsModel] = [
		.init(
			name: "ايمن الناصري",
			desc: "مطور",
			link: "https://t.me/uussuu"
		)
	]

	// MARK: Body
	var body: some View {
		NBList("حول التطبيق") {
			Section {
				VStack {
					// شعار ceresify
					Image("AppLogo")
						.resizable()
						.scaledToFill()
						.frame(width: 85, height: 85)
						.clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
						.padding(.bottom, 8)

					// اسم التطبيق
					Text("ceresify")
						.font(.largeTitle)
						.bold()
						.foregroundStyle(Color.accentColor)
					
					// تثبيت رقم الإصدار
					HStack(spacing: 4) {
						Text("الإصدار")
						Text("1.0")
					}
					.font(.footnote)
					.foregroundStyle(.secondary)
				}
			}
			.frame(maxWidth: .infinity)
			.listRowBackground(EmptyView())
			
			// قسم المطورين
			NBSection("المطورين") {
				ForEach(_credits, id: \.link) { credit in
					_credit(
						name: credit.name,
						desc: credit.desc,
						link: credit.link
					)
				}
				.transition(.slide)
			}
		}
	}
}

// MARK: - Extension: view
extension AboutView {
	@ViewBuilder
	private func _credit(
		name: String,
		desc: String,
		link: String
	) -> some View {
		Button {
			UIApplication.open(link)
		} label: {
			HStack(spacing: 18) {
				Image("AppLogo")
					.appIconStyle(size: 45, isCircle: true)

				NBTitleWithSubtitleView(
					title: name,
					subtitle: desc,
					linelimit: 0
				)

				Spacer() // لدفع السهم إلى الطرف الآخر بشكل مرتب

				Image(systemName: "arrow.up.left") // استخدام سهم يناسب اللغة العربية (من اليمين لليسار)
					.foregroundColor(.secondary.opacity(0.65))
			}
		}
	}
}
