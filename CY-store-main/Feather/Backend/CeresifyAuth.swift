//
//  CeresifyAuth.swift
//  SY STORE
//
//  التحقق من الاشتراك عبر UDID الجهاز الحقيقي.
//  iOS ما يخلي التطبيق يقرا الـ UDID الحقيقي مباشرة، فنجيبه عبر تسجيل جهاز
//  بواسطة سيرفر Ceresify نفسه (يتوسط بينا وبين خدمة nekoo لتثبيت بروفايل
//  توقيع يقرا الـ UDID)، وبعدها نتحقق منه بقاعدة بيانات مشتركين Ceresify.
//
//  نفس فكرة نظام كود التفعيل القديم، بس بالـ UDID الحقيقي بدل الكود كجسر
//  هوية — و"جسر" التسجيل هنا هو deviceToken عشوائي نولّده ونربطه بالـ UDID
//  عبر endpoint التسجيل، بدل ما ندخل كود يدوياً.
//
//  هذه المسارات مأخوذة من كود سيرفر Ceresify الفعلي (src/routes/device.js)،
//  ولا واحد منها يحتاج مفتاح API — التحقق بيصير بالـ UDID/token نفسه.
//

import SwiftUI
import UIKit

enum Ceresify {
    static let baseURL = "https://dev.ceresify.com"
}

enum CeresifyFlowState: Equatable {
    case idle
    case waitingForProfile
    case verifying
}

@MainActor
final class CeresifyAuth: ObservableObject {
    static let shared = CeresifyAuth()

    @Published var isAuthorized = false
    @Published var isChecking = true
    @Published var errorMessage: String?
    @Published var expiresAt: Date?
    @Published var flowState: CeresifyFlowState = .idle

    private var pollTimer: Timer?       // إعادة تحقق دورية من حالة الاشتراك
    private var tokenPollTimer: Timer?  // انتظار ربط الـ UDID بالـ deviceToken

    private let deviceTokenKey = "ceresify.deviceToken"
    private let udidKey = "ceresify.udid"
    private let certKey = "ceresify.didImportCert"

    var savedUDID: String? { UserDefaults.standard.string(forKey: udidKey) }

    /// معرّف عشوائي ثابت للجهاز، يربط جلسة تثبيت البروفايل بالـ UDID اللي يرجع من nekoo.
    /// يبقى ثابت طول ما التطبيق منصّب (نخزنه بالـ UserDefaults).
    private var deviceToken: String {
        if let saved = UserDefaults.standard.string(forKey: deviceTokenKey) { return saved }
        let token = (0..<16).map { _ in String(format: "%02x", UInt8.random(in: 0...255)) }.joined()
        UserDefaults.standard.set(token, forKey: deviceTokenKey)
        return token
    }

    private init() {
        NotificationCenter.default.addObserver(
            self, selector: #selector(_appWillEnterForeground),
            name: UIApplication.willEnterForegroundNotification, object: nil
        )
    }

    func start() {
        guard let udid = savedUDID else {
            isChecking = false
            isAuthorized = false
            return
        }
        Task { await verify(udid: udid, silent: true) }
    }

    // MARK: - تسجيل الجهاز عبر Ceresify (يتوسط لـ nekoo)

    private var enrollURL: URL? {
        URL(string: "\(Ceresify.baseURL)/api/device/nekoo-enroll?token=\(deviceToken)&from=settings")
    }

    func beginDeviceVerification() {
        guard flowState == .idle, let url = enrollURL else { return }
        errorMessage = nil
        flowState = .waitingForProfile
        UIApplication.shared.open(url)
        _startTokenPolling()
    }

    /// يفتح صفحة تثبيت البروفايل مرة ثانية بنفس الـ deviceToken
    func reopenProfilePage() {
        guard let url = enrollURL else { return }
        UIApplication.shared.open(url)
    }

    /// فحص فوري بضغطة المستخدم بدل انتظار التايمر
    func checkNow() {
        guard flowState == .waitingForProfile else { return }
        Task { await _pollResolve() }
    }

    @objc private func _appWillEnterForeground() {
        guard flowState == .waitingForProfile else { return }
        Task { await _pollResolve() }
    }

    private func _startTokenPolling() {
        tokenPollTimer?.invalidate()
        tokenPollTimer = Timer.scheduledTimer(withTimeInterval: 4, repeats: true) { [weak self] _ in
            Task { @MainActor in await self?._pollResolve() }
        }
    }

    private func _pollResolve() async {
        guard flowState == .waitingForProfile else { return }
        guard let url = URL(string: "\(Ceresify.baseURL)/api/device/resolve?token=\(deviceToken)") else { return }

        guard let (data, _) = try? await URLSession.shared.data(from: url),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              json["ok"] as? Bool == true,
              let udid = json["udid"] as? String
        else { return } // لسه ما ربط — نستمر بالانتظار

        tokenPollTimer?.invalidate()
        tokenPollTimer = nil
        flowState = .verifying
        await verify(udid: udid, silent: false)
    }

    // MARK: - التحقق من الاشتراك

    func verify(udid: String, silent: Bool = false) async {
        isChecking = true
        if !silent { errorMessage = nil }

        guard let url = URL(string: "\(Ceresify.baseURL)/api/device/info/\(udid)") else { return }

        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0

            if statusCode == 404 {
                signOut(message: "جهازك غير مسجل كمشترك. تواصل معنا للتفعيل.", clearUDID: true)
                isChecking = false
                return
            }

            guard
                let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                json["ok"] as? Bool == true,
                let device = json["device"] as? [String: Any]
            else { throw URLError(.cannotParseResponse) }

            let isSubscribed = device["isSubscribed"] as? Bool ?? false
            let expiry = (device["subscriptionExpiry"] as? String).flatMap(Self.parseDate)
            let notExpired = expiry == nil || expiry! > Date()

            if isSubscribed && notExpired {
                UserDefaults.standard.set(udid, forKey: udidKey)
                expiresAt = expiry
                isAuthorized = true
                errorMessage = nil
                flowState = .idle
                startPolling(udid: udid)
                await importCert(udid: udid)
            } else {
                signOut(message: "انتهى اشتراكك أو جهازك غير مفعّل. تواصل معنا للتجديد.")
            }
        } catch {
            // فشل شبكة — ما نطرد مشترك داخل أصلاً، بس ما نخلي أحد جديد يدخل
            if !isAuthorized {
                errorMessage = "تعذر الاتصال بالخادم — تأكد من الإنترنت."
                flowState = .idle
            }
        }

        isChecking = false
    }

    /// فحص دوري خفيف: يمسك التجميد وانتهاء الاشتراك
    private func startPolling(udid: String) {
        pollTimer?.invalidate()
        pollTimer = Timer.scheduledTimer(withTimeInterval: 300, repeats: true) { [weak self] _ in
            Task { @MainActor in await self?.pollStatus(udid: udid) }
        }
    }

    private func pollStatus(udid: String) async {
        guard let url = URL(string: "\(Ceresify.baseURL)/api/device/info/\(udid)") else { return }

        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0
            // خطأ سيرفر ما يطرد أحد
            if statusCode >= 500 { return }
            if statusCode == 404 {
                signOut(message: "جهازك غير مسجل كمشترك بعد الآن", clearUDID: true)
                return
            }

            guard
                let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                json["ok"] as? Bool == true,
                let device = json["device"] as? [String: Any]
            else { return }

            let isSubscribed = device["isSubscribed"] as? Bool ?? false
            let expiry = (device["subscriptionExpiry"] as? String).flatMap(Self.parseDate)
            let notExpired = expiry == nil || expiry! > Date()

            if isSubscribed && notExpired {
                expiresAt = expiry
            } else {
                signOut(message: "انتهى اشتراكك. تواصل معنا للتجديد.")
            }
        } catch {
            // انقطاع إنترنت مؤقت — نتجاهله
        }
    }

    /// - Parameter clearUDID: نمسح الـ UDID المحفوظ بس إذا تأكدنا إنه مو موجود بقاعدة البيانات
    ///   أصلاً (404). لو السبب انتهاء اشتراك مؤقت، نخليه محفوظ حتى تصير إعادة التحقق
    ///   بالتشغيلة الجاية صامتة (تفتح تلقائي إذا جدد اشتراكه بدون إعادة تثبيت بروفايل).
    func signOut(message: String?, clearUDID: Bool = false) {
        pollTimer?.invalidate(); pollTimer = nil
        tokenPollTimer?.invalidate(); tokenPollTimer = nil
        if clearUDID { UserDefaults.standard.removeObject(forKey: udidKey) }
        isAuthorized = false
        expiresAt = nil
        errorMessage = message
        isChecking = false
        flowState = .idle
    }

    // MARK: - الشهادة

    /// يسحب شهادة توقيع المشترك من اللوحة وينصبها (مرة وحدة لكل UDID).
    private func importCert(udid: String) async {
        let marker = "\(certKey).\(udid)"
        guard !UserDefaults.standard.bool(forKey: marker) else { return }

        guard let infoURL = URL(string: "\(Ceresify.baseURL)/api/device/my-cert/info?udid=\(udid)"),
              let (infoData, _) = try? await URLSession.shared.data(from: infoURL),
              let infoJson = try? JSONSerialization.jsonObject(with: infoData) as? [String: Any],
              infoJson["hasCert"] as? Bool == true
        else { return }

        let password = infoJson["password"] as? String ?? ""

        func download(_ kind: String) async -> URL? {
            guard let url = URL(string: "\(Ceresify.baseURL)/api/device/my-cert/\(kind)?udid=\(udid)") else { return nil }
            guard let (data, response) = try? await URLSession.shared.data(from: url),
                  let http = response as? HTTPURLResponse, http.statusCode == 200 else { return nil }
            let dest = FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString)
                .appendingPathExtension(kind == "p12" ? "p12" : "mobileprovision")
            do { try data.write(to: dest); return dest } catch { return nil }
        }

        guard let p12 = await download("p12"),
              let prov = await download("mobileprovision") else { return }

        guard FR.checkPasswordForCertificate(for: p12, with: password, using: prov) else { return }

        FR.handleCertificateFiles(
            p12URL: p12,
            provisionURL: prov,
            p12Password: password,
            certificateName: "Ceresify",
            isDefault: true
        ) { error in
            if error == nil { UserDefaults.standard.set(true, forKey: marker) }
        }
    }

    private static func parseDate(_ string: String) -> Date? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.date(from: string) ?? ISO8601DateFormatter().date(from: string)
    }
}
