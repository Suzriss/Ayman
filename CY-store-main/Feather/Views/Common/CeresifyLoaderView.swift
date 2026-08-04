//
//  CeresifyLoaderView.swift
//  SY STORE
//
//  لودر بألوان الهوية (ذهبي على خلفية غامقة) يظهر طول مدة التحميل الفعلية
//  ويختفي لحظة ما تجهز البيانات — بدل شاشة سوداء فاضية أو ProgressView افتراضي.
//

import SwiftUI

struct CeresifyLoaderView: View {
    var message: String = "جاري تحميل التطبيقات..."

    private let gold = Color(hex: "#B28231")
    private let darkBackground = Color(hex: "#0E0D0B")

    var body: some View {
        ZStack {
            darkBackground.ignoresSafeArea()

            VStack(spacing: 16) {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: gold))
                    .scaleEffect(1.4)

                Text(message)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(gold)
            }
        }
        .transition(.opacity)
    }
}
