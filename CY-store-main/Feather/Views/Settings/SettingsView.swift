//
//  SettingsView.swift
//  SY STORE
//
//  Created by samara on 10.04.2025.
//

import SwiftUI
import NimbleViews
import UIKit
import Darwin
import IDeviceSwift

// MARK: - جلب الرقم المصنعي الدقيق للجهاز
extension UIDevice {
    var exactModelName: String {
        var systemInfo = utsname()
        uname(&systemInfo)
        let machineMirror = Mirror(reflecting: systemInfo.machine)
        let identifier = machineMirror.children.reduce("") { identifier, element in
            guard let value = element.value as? Int8, value != 0 else { return identifier }
            return identifier + String(UnicodeScalar(UInt8(value)))
        }
        return identifier
    }
}

// MARK: - View
struct SettingsView: View {
    @AppStorage("systore.selectedCert") private var _storedSelectedCert: Int = 0
    
    @FetchRequest(
        entity: CertificatePair.entity(),
        sortDescriptors: [NSSortDescriptor(keyPath: \CertificatePair.date, ascending: false)],
        animation: .snappy
    ) private var _certificates: FetchedResults<CertificatePair>
    
    private var selectedCertificate: CertificatePair? {
        guard _storedSelectedCert >= 0, _storedSelectedCert < _certificates.count else { return nil }
        return _certificates[_storedSelectedCert]
    }

    var body: some View {
        NBNavigationView("الإعدادات") {
            Form {
                _aboutSection()
                
                Section {
                    NavigationLink(destination: AppearanceView()) {
                        Label("المظهر", systemImage: "paintbrush")
                    }
                }
                
                NBSection("الشهادات") {
                    if let cert = selectedCertificate {
                        CertificatesCellView(cert: cert)
                    } else {
                        Text("لا توجد شهادة")
                            .font(.footnote)
                            .foregroundColor(.disabled())
                    }
                    NavigationLink(destination: CertificatesView()) {
                        Label("الشهادات", systemImage: "checkmark.seal")
                    }
                } footer: {
                    Text("أضف وأدر الشهادات المستخدمة لتوقيع التطبيقات.")
                }
                
                NBSection("الميزات") {
                    NavigationLink(destination: ConfigurationView()) {
                        Label("خيارات التوقيع", systemImage: "signature")
                    }
                    NavigationLink(destination: InstallationView()) {
                        Label("التثبيت", systemImage: "arrow.down.circle")
                    }
                } footer: {
                    Text("تكوين طريقة التثبيت والتعديلات المخصصة على التطبيقات.")
                }
                
                Section {
                    NavigationLink(destination: ResetView()) {
                        Label("إعادة تعيين", systemImage: "trash")
                    }
                } footer: {
                    Text("إعادة تعيين الشهادات والتطبيقات والمحتويات العامة.")
                }
            }
        }
    }
}

extension SettingsView {
    @ViewBuilder
    private func _aboutSection() -> some View {
        Section {
            NavigationLink(destination: AboutView()) {
                Label {
                    Text("حول التطبيق")
                } icon: {
                    // تم تغيير رابط الصورة إلى الرابط الجديد الخاص بك هنا
                    AsyncImage(url: URL(string: "https://up6.cc/2026/06/178283567306191.png")) { phase in
                        if let image = phase.image {
                            image.resizable().scaledToFill().frame(width: 26, height: 26).clipShape(RoundedRectangle(cornerRadius: 6))
                        } else if phase.error != nil {
                            Image(systemName: "info.circle.fill").resizable().frame(width: 26, height: 26).foregroundColor(.gray)
                        } else {
                            ProgressView().frame(width: 26, height: 26)
                        }
                    }
                }
            }
        }
    }
}
