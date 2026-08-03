//
//  FeaturedCardView.swift
//  CY STORE
//

import SwiftUI

struct FeaturedCardView: View {
    let item: CeresifyStore.Featured

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            AsyncImage(url: item.imageURL) { phase in
                if let image = phase.image {
                    image.resizable().aspectRatio(contentMode: .fill)
                } else if phase.error != nil {
                    Rectangle().fill(Color(uiColor: .secondarySystemBackground))
                        .overlay(Image(systemName: "photo.fill").foregroundColor(.secondary))
                } else {
                    Rectangle().fill(Color(uiColor: .secondarySystemBackground))
                        .overlay(ProgressView())
                }
            }
            .frame(height: 200).frame(maxWidth: .infinity).clipped()

            if !item.title.isEmpty || !item.subtitle.isEmpty {
                LinearGradient(colors: [.black.opacity(0.0), .black.opacity(0.65)],
                               startPoint: .center, endPoint: .bottom)
                VStack(alignment: .leading, spacing: 2) {
                    if !item.title.isEmpty {
                        Text(item.title).font(.title3.bold()).foregroundColor(.white)
                    }
                    if !item.subtitle.isEmpty {
                        Text(item.subtitle).font(.subheadline).foregroundColor(.white.opacity(0.85))
                    }
                }.padding(14)
            }
        }
        .frame(height: 200)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}
