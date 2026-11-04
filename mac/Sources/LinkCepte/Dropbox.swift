import Foundation
import AppKit
import CryptoKit
import Security

/// Okunabilir hata mesajı taşıyan basit hata türü.
struct DropboxError: LocalizedError {
    let message: String
    init(_ message: String) { self.message = message }
    var errorDescription: String? { message }
}

/// Dropbox yedekleme: OAuth2 + PKCE (gizli anahtar gerekmez), tek dosya olarak yükleme/indirme.
/// Android sürümüyle birebir aynı uygulama anahtarını, dönüş adresini ve yedek dosyasını kullanır;
/// bu yüzden Android'de alınan yedek Mac'te, Mac'te alınan yedek Android'de geri yüklenebilir.
/// Yedek, Dropbox'ta uygulamanın kendi klasöründe `/LinkCepte-yedek.zip` adıyla durur.
enum Dropbox {
    /// Android'deki gradle.properties → DROPBOX_APP_KEY ile aynı değer (App key gizli bilgi değildir).
    /// Değiştirirseniz Resources/Info.plist içindeki `db-<anahtar>` URL şemasını da değiştirin.
    static let appKey = "01a5zg8oc8aas3c"
    static let scheme = "db-\(appKey)"

    private static let file = "/LinkCepte-yedek.zip"
    private static let redirect = "db-\(appKey)://1/connect"
    private static let tokenURL = "https://api.dropboxapi.com/oauth2/token"
    private static let maxUpload = 150 * 1024 * 1024   // Dropbox tek istekte en fazla 150 MB kabul eder

    private enum K {
        static let refresh = "dbx.refresh"
        static let verifier = "dbx.verifier"
        static let state = "dbx.state"
    }
    private static var defaults: UserDefaults { .standard }

    static var connected: Bool { defaults.string(forKey: K.refresh) != nil }

    // MARK: - Yardımcılar

    private static func b64(_ data: Data) -> String {
        data.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    private static func enc(_ s: String) -> String {
        var allowed = CharacterSet.alphanumerics
        allowed.insert(charactersIn: "-._~")
        return s.addingPercentEncoding(withAllowedCharacters: allowed) ?? s
    }

    private static func rnd(_ n: Int) -> String {
        var bytes = [UInt8](repeating: 0, count: n)
        if SecRandomCopyBytes(kSecRandomDefault, n, &bytes) != errSecSuccess {
            for i in 0..<n { bytes[i] = UInt8.random(in: 0...255) }
        }
        return b64(Data(bytes))
    }

    private static func clear() {
        defaults.removeObject(forKey: K.refresh)
        defaults.removeObject(forKey: K.verifier)
        defaults.removeObject(forKey: K.state)
    }

    private static func jsonString(_ data: Data, _ key: String) -> String? {
        (try? JSONSerialization.jsonObject(with: data) as? [String: Any])?[key] as? String
    }

    // MARK: - Giriş (OAuth2 + PKCE)

    /// Tarayıcıda Dropbox giriş sayfasını açar; dönüş `db-<APP_KEY>://1/connect` adresiyle uygulamaya gelir.
    @MainActor
    static func startAuth() {
        let verifier = rnd(48)
        let state = rnd(16)
        defaults.set(verifier, forKey: K.verifier)
        defaults.set(state, forKey: K.state)
        let challenge = b64(Data(SHA256.hash(data: Data(verifier.utf8))))
        let url = "https://www.dropbox.com/oauth2/authorize?client_id=\(enc(appKey))&response_type=code"
            + "&code_challenge=\(challenge)&code_challenge_method=S256&token_access_type=offline"
            + "&redirect_uri=\(enc(redirect))&state=\(enc(state))"
        if let u = URL(string: url) { NSWorkspace.shared.open(u) }
    }

    /// Dönüş adresindeki kodu refresh token ile değiştirir ve saklar.
    static func finishAuth(_ url: URL) async throws {
        let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []
        func q(_ name: String) -> String? { items.first(where: { $0.name == name })?.value }

        if let err = q("error") { throw DropboxError(q("error_description") ?? err) }
        guard let st = q("state"), st == defaults.string(forKey: K.state) else {
            throw DropboxError(L("Geçersiz yanıt", "Invalid response"))
        }
        guard let code = q("code") else { throw DropboxError(L("Kod yok", "No code")) }
        guard let verifier = defaults.string(forKey: K.verifier) else {
            throw DropboxError(L("Oturum bulunamadı", "Session not found"))
        }
        let data = try await post(tokenURL,
            form: "grant_type=authorization_code&code=\(enc(code))&client_id=\(enc(appKey))"
                + "&code_verifier=\(enc(verifier))&redirect_uri=\(enc(redirect))")
        guard let refresh = jsonString(data, "refresh_token") else {
            throw DropboxError(L("Dropbox yanıtı anlaşılamadı", "Unexpected Dropbox response"))
        }
        defaults.set(refresh, forKey: K.refresh)
        defaults.removeObject(forKey: K.verifier)
        defaults.removeObject(forKey: K.state)
    }

    /// Erişimi iptal etmeyi dener (başarısız olsa da) ve yerel oturumu siler.
    static func disconnect() async {
        if let token = try? await accessToken() {
            var r = URLRequest(url: URL(string: "https://api.dropboxapi.com/2/auth/token/revoke")!)
            r.httpMethod = "POST"
            r.timeoutInterval = 15
            r.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            _ = try? await URLSession.shared.data(for: r)
        }
        clear()
    }

    private static func accessToken() async throws -> String {
        guard let refresh = defaults.string(forKey: K.refresh) else {
            throw DropboxError(L("Dropbox'a bağlı değil", "Not connected to Dropbox"))
        }
        do {
            let data = try await post(tokenURL,
                form: "grant_type=refresh_token&refresh_token=\(enc(refresh))&client_id=\(enc(appKey))")
            guard let t = jsonString(data, "access_token") else {
                throw DropboxError(L("Dropbox yanıtı anlaşılamadı", "Unexpected Dropbox response"))
            }
            return t
        } catch let e as DropboxError {
            if e.message.contains("invalid_grant") {
                clear()
                throw DropboxError(L("Dropbox oturumu sona erdi, yeniden bağlanın", "Dropbox session expired, reconnect"))
            }
            throw e
        }
    }

    // MARK: - Yükleme / indirme

    static func upload(_ bytes: Data) async throws {
        if bytes.count > maxUpload {
            throw DropboxError(L("Yedek 150 MB sınırını aşıyor", "The backup exceeds the 150 MB limit"))
        }
        let arg = "{\"path\":\"\(file)\",\"mode\":\"overwrite\",\"mute\":true}"
        _ = try await content("https://content.dropboxapi.com/2/files/upload", arg: arg, body: bytes)
    }

    static func download() async throws -> Data {
        let arg = "{\"path\":\"\(file)\"}"
        return try await content("https://content.dropboxapi.com/2/files/download", arg: arg, body: nil)
    }

    private static func content(_ url: String, arg: String, body: Data?) async throws -> Data {
        let token = try await accessToken()
        var r = URLRequest(url: URL(string: url)!)
        r.httpMethod = "POST"
        r.timeoutInterval = 120
        r.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        r.setValue(arg, forHTTPHeaderField: "Dropbox-API-Arg")
        r.setValue("application/octet-stream", forHTTPHeaderField: "Content-Type")

        let result: (Data, URLResponse)
        if let b = body { result = try await URLSession.shared.upload(for: r, from: b) }
        else { result = try await URLSession.shared.data(for: r) }

        guard let http = result.1 as? HTTPURLResponse else {
            throw DropboxError(L("Geçersiz yanıt", "Invalid response"))
        }
        if !(200..<300).contains(http.statusCode) {
            let err = String(decoding: result.0, as: UTF8.self)
            if http.statusCode == 409 && err.contains("not_found") {
                throw DropboxError(L("Dropbox'ta yedek bulunamadı", "No backup found in Dropbox"))
            }
            throw DropboxError("Dropbox \(http.statusCode): \(String(err.prefix(800)))")
        }
        return result.0
    }

    private static func post(_ url: String, form: String) async throws -> Data {
        var r = URLRequest(url: URL(string: url)!)
        r.httpMethod = "POST"
        r.timeoutInterval = 30
        r.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        r.httpBody = Data(form.utf8)
        let (data, resp) = try await URLSession.shared.data(for: r)
        guard let http = resp as? HTTPURLResponse else {
            throw DropboxError(L("Geçersiz yanıt", "Invalid response"))
        }
        if !(200..<300).contains(http.statusCode) {
            let t = String(String(decoding: data, as: UTF8.self).prefix(200))
            throw DropboxError(t.isEmpty ? "HTTP \(http.statusCode)" : t)
        }
        return data
    }
}
