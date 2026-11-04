package io.github.idrisokys.linkcepte

import android.content.Context
import android.content.Intent
import android.net.Uri
import android.util.Base64
import org.json.JSONObject
import java.io.IOException
import java.net.HttpURLConnection
import java.net.URL
import java.net.URLEncoder
import java.security.MessageDigest
import java.security.SecureRandom

/**
 * Dropbox yedekleme: OAuth2 + PKCE (gizli anahtar gerekmez), tek dosya olarak yükleme/indirme.
 * Yedek, Dropbox'ta uygulamanın kendi klasöründe [FILE] adıyla durur.
 * Hata durumunda okunabilir mesajla IOException fırlatır.
 */
object Dropbox {
    private const val FILE = "/LinkCepte-yedek.zip"
    private const val UNSET = "YOUR_DROPBOX_APP_KEY"
    private val KEY = BuildConfig.DROPBOX_APP_KEY
    private val REDIRECT = "db-$KEY://1/connect"

    private fun prefs(ctx: Context) = ctx.getSharedPreferences("dbx", Context.MODE_PRIVATE)

    fun configured() = KEY.isNotBlank() && KEY != UNSET
    fun connected(ctx: Context) = prefs(ctx).getString("refresh", null) != null

    private fun b64(b: ByteArray) = Base64.encodeToString(b, Base64.URL_SAFE or Base64.NO_PADDING or Base64.NO_WRAP)
    private fun enc(s: String) = URLEncoder.encode(s, "UTF-8")
    private fun rnd(n: Int) = b64(ByteArray(n).also { SecureRandom().nextBytes(it) })

    /** Tarayıcıda Dropbox giriş sayfasını açar; dönüş DropboxAuthActivity'ye gelir. */
    fun startAuth(ctx: Context) {
        val verifier = rnd(48)
        val state = rnd(16)
        prefs(ctx).edit().putString("verifier", verifier).putString("state", state).apply()
        val challenge = b64(MessageDigest.getInstance("SHA-256").digest(verifier.toByteArray()))
        val url = "https://www.dropbox.com/oauth2/authorize?client_id=${enc(KEY)}&response_type=code" +
            "&code_challenge=$challenge&code_challenge_method=S256&token_access_type=offline" +
            "&redirect_uri=${enc(REDIRECT)}&state=${enc(state)}"
        ctx.startActivity(Intent(Intent.ACTION_VIEW, Uri.parse(url)))
    }

    /** Dönüş adresindeki kodu refresh token ile değiştirir ve saklar. */
    fun finishAuth(ctx: Context, data: Uri) {
        val p = prefs(ctx)
        data.getQueryParameter("error")?.let { throw IOException(data.getQueryParameter("error_description") ?: it) }
        if (data.getQueryParameter("state") != p.getString("state", null)) throw IOException("Geçersiz yanıt / Invalid response")
        val code = data.getQueryParameter("code") ?: throw IOException("Kod yok / No code")
        val verifier = p.getString("verifier", null) ?: throw IOException("Oturum bulunamadı / Session not found")
        val j = JSONObject(post("https://api.dropboxapi.com/oauth2/token",
            "grant_type=authorization_code&code=${enc(code)}&client_id=${enc(KEY)}&code_verifier=${enc(verifier)}&redirect_uri=${enc(REDIRECT)}"))
        p.edit().putString("refresh", j.getString("refresh_token")).remove("verifier").remove("state").apply()
    }

    fun disconnect(ctx: Context) {
        try { call(ctx, "https://api.dropboxapi.com/2/auth/token/revoke", null, null) } catch (e: Exception) { }
        prefs(ctx).edit().clear().apply()
    }

    private fun accessToken(ctx: Context): String {
        val refresh = prefs(ctx).getString("refresh", null) ?: throw IOException(L("Dropbox'a bağlı değil", "Not connected to Dropbox"))
        try {
            return JSONObject(post("https://api.dropboxapi.com/oauth2/token",
                "grant_type=refresh_token&refresh_token=${enc(refresh)}&client_id=${enc(KEY)}")).getString("access_token")
        } catch (e: IOException) {
            if (e.message?.contains("invalid_grant") == true) {
                prefs(ctx).edit().clear().apply()
                throw IOException(L("Dropbox oturumu sona erdi, yeniden bağlanın", "Dropbox session expired, reconnect"))
            }
            throw e
        }
    }

    fun upload(ctx: Context, bytes: ByteArray) {
        val arg = """{"path":"$FILE","mode":"overwrite","mute":true}"""
        call(ctx, "https://content.dropboxapi.com/2/files/upload", arg, bytes)
    }

    fun download(ctx: Context): ByteArray {
        val arg = """{"path":"$FILE"}"""
        return call(ctx, "https://content.dropboxapi.com/2/files/download", arg, null)
    }

    private fun call(ctx: Context, url: String, arg: String?, body: ByteArray?): ByteArray {
        val c = URL(url).openConnection() as HttpURLConnection
        try {
            c.requestMethod = "POST"
            c.connectTimeout = 15000; c.readTimeout = 60000
            c.setRequestProperty("Authorization", "Bearer " + accessToken(ctx))
            if (arg != null) c.setRequestProperty("Dropbox-API-Arg", arg)
            c.setRequestProperty("Content-Type", if (body != null) "application/octet-stream" else "")
            c.doOutput = true
            if (body != null) { c.setFixedLengthStreamingMode(body.size); c.outputStream.use { it.write(body) } }
            else c.setFixedLengthStreamingMode(0)
            if (c.responseCode !in 200..299) {
                val err = c.errorStream?.bufferedReader()?.use { it.readText() }.orEmpty()
                if (c.responseCode == 409 && err.contains("not_found"))
                    throw IOException(L("Dropbox'ta yedek bulunamadı", "No backup found in Dropbox"))
                throw IOException("Dropbox ${c.responseCode}: ${err.take(800)}")
            }
            return c.inputStream.use { it.readBytes() }
        } finally { c.disconnect() }
    }

    private fun post(url: String, form: String): String {
        val c = URL(url).openConnection() as HttpURLConnection
        try {
            c.requestMethod = "POST"
            c.connectTimeout = 15000; c.readTimeout = 30000
            c.doOutput = true
            c.setRequestProperty("Content-Type", "application/x-www-form-urlencoded")
            c.outputStream.use { it.write(form.toByteArray()) }
            if (c.responseCode !in 200..299) throw IOException(c.errorStream?.bufferedReader()?.use { it.readText() }.orEmpty().take(200).ifEmpty { "HTTP ${c.responseCode}" })
            return c.inputStream.bufferedReader().use { it.readText() }
        } finally { c.disconnect() }
    }
}
