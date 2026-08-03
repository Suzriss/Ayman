//
//  CeresifyAuthView.swift
//  SY STORE
//
//  شاشة توثيق الجهاز — تجيب الـ UDID الحقيقي عبر بروفايل nekoo، وتتحقق منه
//  عبر لوحة Ceresify.
//

import SwiftUI

struct CeresifyAuthView: View {
    @ObservedObject private var auth = CeresifyAuth.shared

    private var accent: Color { Color(hex: "#00FF9D") }

    var body: some View {
        ZStack {
            RadialGradient(
                gradient: Gradient(colors: [Color(hex: "#052e16"), .black]),
                center: .bottom, startRadius: 0, endRadius: 600
            ).ignoresSafeArea()

            VStack(spacing: 30) {
                Spacer()

                VStack(spacing: 15) {
                    Image(systemName: "shield.checkered")
                        .font(.system(size: 80, weight: .light))
                        .foregroundColor(accent)
                        .shadow(color: accent.opacity(0.5), radius: 10)
                    Text("SY STORE")
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .tracking(2)
                    Text("بوابة الوصول الآمن لتطبيقات الـ VIP")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                }

                VStack(spacing: 14) {
                    switch auth.flowState {
                    case .idle:
                        Text("اضغط الزر تحت لتوثيق جهازك، راح ينفتح المتصفح لتثبيت بروفايل تحقق صغير.")
                            .font(.footnote)
                            .foregroundColor(.gray)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 30)

                    case .waitingForProfile:
                        VStack(spacing: 10) {
                            Text("ثبّت البروفايل من الصفحة المفتوحة بالمتصفح (من إعدادات الجهاز)، وبعدها ارجع هنا.")
                                .font(.footnote)
                                .foregroundColor(.gray)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 30)

                            HStack(spacing: 10) {
                                ProgressView().tint(accent)
                                Text("بانتظار تثبيت البروفايل...")
                                    .font(.caption)
                                    .foregroundColor(accent)
                            }

                            Button("افتح صفحة التثبيت مرة ثانية") { auth.reopenProfilePage() }
                                .font(.footnote)
                                .foregroundColor(accent)

                            Button("ثبّتها، افحص الآن") { auth.checkNow() }
                                .font(.footnote.bold())
                                .foregroundColor(accent)
                        }

                    case .verifying:
                        HStack(spacing: 10) {
                            ProgressView().tint(accent)
                            Text("جاري التحقق من الاشتراك...")
                                .font(.caption)
                                .foregroundColor(accent)
                        }
                    }

                    if let error = auth.errorMessage {
                        Text(error)
                            .font(.caption)
                            .foregroundColor(.red)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                }

                if auth.flowState == .idle {
                    Button(action: { auth.beginDeviceVerification() }) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 15)
                                .fill(accent)
                                .shadow(color: accent.opacity(0.4), radius: 10, y: 5)
                            Text("توثيق الجهاز")
                                .font(.headline).bold()
                                .foregroundColor(.black)
                        }
                        .frame(height: 55)
                        .padding(.horizontal, 30)
                    }
                }

                Spacer()

                Button {
                    if let url = URL(string: "https://t.me/ipa_black") { UIApplication.shared.open(url) }
                } label: {
                    Text("جهازك مو مسجل كمشترك؟ تواصل معنا")
                        .font(.footnote)
                        .foregroundColor(.gray)
                        .underline()
                }
                .padding(.bottom, 20)
            }
        }
        .environment(\.colorScheme, .dark)
    }
}
