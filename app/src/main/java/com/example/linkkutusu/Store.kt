package com.example.linkkutusu

import android.content.Context
import android.content.Intent
import android.net.Uri
import android.provider.DocumentsContract as DC
import java.net.HttpURLConnection
import java.net.URL

data class Entry(val name: String, val uri: Uri, val isDir: Boolean) {
    /** Liste anahtarı; her seferinde yeniden hesaplanmasın diye bir kez üretilir. */
    val key: String = uri.toString()
}

/** Arama sonucu: bulunan öğe, bulunduğu klasör zinciri ve gösterilecek özet. */
data class Hit(val entry: Entry, val path: List<Entry>, val detail: String, val isNote: Boolean, val titleMatch: Boolean)

object Store {
    private const val ORDER = ".order.txt"
    private const val OCTET = "application/octet-stream"
    private const val FLAGS = Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_GRANT_WRITE_URI_PERMISSION

    /** Tüm yazma/okuma işlemleri (uygulama + paylaşım ekranı) bu kilitle sıralanır. */
    private val mutex = Any()

    private fun tree(ctx: Context): Uri? =
        ctx.getSharedPreferences("p", 0).getString("root", null)?.let { Uri.parse(it) }

    /** Seçili kök klasörün belge Uri'si; izin yoksa null. */
    fun root(ctx: Context): Uri? {
        val t = tree(ctx) ?: return null
        val ok = ctx.contentResolver.persistedUriPermissions.any { it.uri == t && it.isWritePermission }
        return if (ok) DC.buildDocumentUriUsingTree(t, DC.getTreeDocumentId(t)) else null
    }

    fun setRoot(ctx: Context, uri: Uri): Boolean {
        val old = tree(ctx)
        try { ctx.contentResolver.takePersistableUriPermission(uri, FLAGS) } catch (e: Exception) { return false }
        ctx.getSharedPreferences("p", 0).edit().putString("root", uri.toString()).apply()
        if (old != null && old != uri) {
            try { ctx.contentResolver.releasePersistableUriPermission(old, FLAGS) } catch (e: Exception) { }
        }
        return root(ctx) != null
    }

    /** Dosya adında sorun çıkaran karakterleri düzgünce temizler. */
    private fun clean(s: String, max: Int = 80): String =
        s.replace(Regex("[\\r\\n\\t]+"), " ")
            .replace(Regex("\\s*[:|/\\\\]\\s*"), " - ")
            .replace(Regex("[*?\"<>]"), "")
            .replace(Regex("\\s+"), " ")
            .trim().trimStart('.', ' ', '-').take(max).let { fitBytes(it) }.trim().ifBlank { "link" }

    /** Dosya sistemi adı ~255 bayt ile sınırlı; ".url" ve " (2)" payı bırakarak bayt cinsinden kısaltır. */
    private fun fitBytes(s: String, limit: Int = 240): String {
        var t = s
        while (t.toByteArray(Charsets.UTF_8).size > limit) t = t.dropLast(1)
        return t
    }

    /** Tek sorguyla klasörün tüm içeriği. */
    private fun children(ctx: Context, dir: Uri): List<Entry> {
        val t = tree(ctx) ?: return emptyList()
        val q = DC.buildChildDocumentsUriUsingTree(t, DC.getDocumentId(dir))
        val out = ArrayList<Entry>()
        try {
            val cols = arrayOf(DC.Document.COLUMN_DOCUMENT_ID, DC.Document.COLUMN_DISPLAY_NAME, DC.Document.COLUMN_MIME_TYPE)
            ctx.contentResolver.query(q, cols, null, null, null)?.use { c ->
                while (c.moveToNext()) {
                    val id = c.getString(0) ?: continue
                    val name = c.getString(1) ?: continue
                    out.add(Entry(name, DC.buildDocumentUriUsingTree(t, id), c.getString(2) == DC.Document.MIME_TYPE_DIR))
                }
            }
        } catch (e: Exception) { }
        return out
    }

    private fun ordered(ctx: Context, all: List<Entry>): List<Entry> {
        val files = all.filter { !it.name.startsWith(".") && (it.isDir || it.name.endsWith(".url", true)) }
        val byName = files.associateBy { it.name }
        val ord = readOrder(ctx, all).distinct().mapNotNull { byName[it] }
        val seen = ord.mapTo(HashSet()) { it.name }
        val rest = files.filter { it.name !in seen }.sortedWith(compareBy({ !it.isDir }, { it.name.lowercase() }))
        return ord + rest
    }

    fun list(ctx: Context, dir: Uri): List<Entry> = synchronized(mutex) { ordered(ctx, children(ctx, dir)) }

    private fun readOrder(ctx: Context, all: List<Entry>): List<String> {
        val f = all.firstOrNull { it.name == ORDER } ?: return emptyList()
        return try {
            ctx.contentResolver.openInputStream(f.uri)?.bufferedReader()?.use { r -> r.readLines().filter { it.isNotBlank() } } ?: emptyList()
        } catch (e: Exception) { emptyList() }
    }

    private fun saveOrderIn(ctx: Context, dir: Uri, names: List<String>, all: List<Entry>) {
        try {
            val f = all.firstOrNull { it.name == ORDER }?.uri
                ?: DC.createDocument(ctx.contentResolver, dir, "text/plain", ORDER) ?: return
            ctx.contentResolver.openOutputStream(f, "wt")?.use { it.write(names.joinToString("\n").toByteArray()) }
        } catch (e: Exception) { }
    }

    fun saveOrder(ctx: Context, dir: Uri, names: List<String>) = synchronized(mutex) {
        saveOrderIn(ctx, dir, names, children(ctx, dir))
    }

    private fun write(ctx: Context, dir: Uri, base: String, bytes: ByteArray): Boolean = synchronized(mutex) {
        try {
            val all = children(ctx, dir)
            val taken = all.mapTo(HashSet()) { it.name.lowercase() }
            val b = clean(base)
            var name = "$b.url"; var i = 2
            while (name.lowercase() in taken) { name = "$b ($i).url"; i++ }
            val f = DC.createDocument(ctx.contentResolver, dir, OCTET, name) ?: return false
            ctx.contentResolver.openOutputStream(f, "w")?.use { it.write(bytes) } ?: return false
            // Yeni öğe listenin sonuna eklenir; mevcut sıra korunur.
            val names = ordered(ctx, all).map { it.name } + name
            saveOrderIn(ctx, dir, names, all)
            true
        } catch (e: Exception) { false }
    }

    fun addLink(ctx: Context, dir: Uri, title: String, url: String): Boolean =
        write(ctx, dir, title, "[InternetShortcut]\r\nURL=$url\r\n".toByteArray())

    /** Düz metni de kaydeder (URL olmayan kayıt). */
    fun addNote(ctx: Context, dir: Uri, text: String): Boolean {
        val title = text.lines().firstOrNull { it.isNotBlank() }?.trim() ?: "not"
        val enc = text.replace("\\", "\\\\").replace("\r", "").replace("\n", "\\n")
        return write(ctx, dir, title, "[InternetShortcut]\r\nTEXT=$enc\r\n".toByteArray())
    }

    /** Metindeki ilk linki bulur; sondaki noktalama işaretlerini atar. */
    fun extractUrl(text: String): String? {
        var u = Regex("https?://\\S+", RegexOption.IGNORE_CASE).find(text)?.value ?: return null
        while (u.isNotEmpty()) {
            val last = u.last()
            val strip = last in ".,;:!?\"'>]}" || (last == ')' && '(' !in u)
            if (strip) u = u.dropLast(1) else break
        }
        return if (u.length > 8) u else null
    }

    /** Link veya metni uygun şekilde kaydeder. Ağ erişimi yaptığı için arka planda çağrılmalı. */
    fun addFromText(ctx: Context, dir: Uri, text: String, subject: String? = null): Boolean {
        val t = text.trim()
        if (t.isEmpty()) return false
        val url = extractUrl(t) ?: return addNote(ctx, dir, t)
        val title = fetchTitle(url)
            ?: subject?.lines()?.firstOrNull { it.isNotBlank() }?.trim()
            ?: t.replace(url, "").lines().firstOrNull { it.isNotBlank() }?.trim()
            ?: runCatching { java.net.URI(url).host }.getOrNull()
            ?: "link"
        return addLink(ctx, dir, title, url)
    }

    fun moveLink(ctx: Context, e: Entry, target: Uri): Boolean = synchronized(mutex) {
        try {
            val bytes = ctx.contentResolver.openInputStream(e.uri)?.use { it.readBytes() } ?: return false
            if (!write(ctx, target, e.name.removeSuffix(".url"), bytes)) return false
            DC.deleteDocument(ctx.contentResolver, e.uri)
        } catch (ex: Exception) { false }
    }

    /** Klasörü (içindekilerle birlikte) kopyalar. */
    private fun copyTree(ctx: Context, src: Entry, targetDir: Uri, newName: String): Boolean {
        val dst = DC.createDocument(ctx.contentResolver, targetDir, DC.Document.MIME_TYPE_DIR, newName) ?: return false
        for (c in children(ctx, src.uri)) {
            if (c.isDir) { if (!copyTree(ctx, c, dst, c.name)) return false; continue }
            val bytes = ctx.contentResolver.openInputStream(c.uri)?.use { it.readBytes() } ?: return false
            val f = DC.createDocument(ctx.contentResolver, dst, if (c.name == ORDER) "text/plain" else OCTET, c.name) ?: return false
            ctx.contentResolver.openOutputStream(f, "w")?.use { it.write(bytes) } ?: return false
        }
        return true
    }

    /** Link ya da klasörü başka klasöre taşır. [from] öğenin şu an bulunduğu klasördür. */
    fun moveEntry(ctx: Context, e: Entry, from: Uri, target: Uri): Boolean = synchronized(mutex) {
        if (!e.isDir) return moveLink(ctx, e, target)
        try {
            val all = children(ctx, target)
            val taken = all.mapTo(HashSet()) { it.name.lowercase() }
            var name = e.name
            var moved = false
            if (name.lowercase() !in taken) {
                moved = try { DC.moveDocument(ctx.contentResolver, e.uri, from, target) != null } catch (ex: Exception) { false }
            }
            if (!moved) {
                var i = 2
                while (name.lowercase() in taken) { name = "${e.name} ($i)"; i++ }
                if (!copyTree(ctx, e, target, name)) return false
                DC.deleteDocument(ctx.contentResolver, e.uri)
            }
            saveOrderIn(ctx, target, ordered(ctx, all).map { it.name } + name, children(ctx, target))
            true
        } catch (ex: Exception) { false }
    }

    fun addFolder(ctx: Context, dir: Uri, name: String) = synchronized(mutex) {
        try {
            val all = children(ctx, dir)
            val base = clean(name)
            var n = base; var i = 2
            while (all.any { it.name.equals(n, true) }) { n = "$base ($i)"; i++ }
            DC.createDocument(ctx.contentResolver, dir, DC.Document.MIME_TYPE_DIR, n)
            Unit
        } catch (e: Exception) { }
    }

    /** Link (.url) veya klasör adını değiştirir; sıralamayı korur. */
    fun rename(ctx: Context, dir: Uri, e: Entry, title: String): Boolean = synchronized(mutex) {
        try {
            val base = clean(title, 250)
            val newName = if (e.isDir) base else "$base.url"
            if (newName == e.name) return true
            val all = children(ctx, dir)
            if (all.any { it.name.equals(newName, true) && it.uri != e.uri }) return false
            val order = ordered(ctx, all).map { it.name }
            DC.renameDocument(ctx.contentResolver, e.uri, newName) ?: return false
            saveOrderIn(ctx, dir, order.map { if (it == e.name) newName else it }, all)
            true
        } catch (ex: Exception) { false }
    }

    fun delete(ctx: Context, uri: Uri) = synchronized(mutex) {
        try { DC.deleteDocument(ctx.contentResolver, uri); Unit } catch (e: Exception) { }
    }

    private fun lines(ctx: Context, uri: Uri): List<String> = try {
        ctx.contentResolver.openInputStream(uri)?.bufferedReader()?.use { r ->
            r.readLines().map { it.trim().removePrefix("\uFEFF") }
        } ?: emptyList()
    } catch (e: Exception) { emptyList() }

    fun readUrl(ctx: Context, uri: Uri): String? =
        lines(ctx, uri).firstOrNull { it.startsWith("URL=", true) }?.substring(4)?.trim()?.ifBlank { null }

    private fun unescape(dec: String): String {
        val sb = StringBuilder(); var i = 0
        while (i < dec.length) {
            val c = dec[i]
            if (c == '\\' && i + 1 < dec.length) { sb.append(if (dec[i + 1] == 'n') '\n' else dec[i + 1]); i += 2 }
            else { sb.append(c); i++ }
        }
        return sb.toString()
    }

    fun readText(ctx: Context, uri: Uri): String? =
        lines(ctx, uri).firstOrNull { it.startsWith("TEXT=", true) }?.let { unescape(it.substring(5)) }

    /** Büyük/küçük harf, Türkçe i/ı/İ/I ve aksan (ş→s, ğ→g...) farkını yok sayar; uzunluğu korur. */
    fun fold(s: String): String {
        val sb = StringBuilder(s.length)
        for (c in s) sb.append(when {
            c.code < 128 -> c.lowercaseChar()
            c == 'İ' || c == 'ı' -> 'i'
            else -> java.text.Normalizer.normalize(c.toString(), java.text.Normalizer.Form.NFD).first().lowercaseChar()
        })
        return sb.toString()
    }

    /** Tüm klasörlerde; başlık, link adresi ve not metninde arar. Yazılan her kelime bulunmalıdır. */
    fun search(ctx: Context, root: Uri, query: String, alive: () -> Boolean = { true }): List<Hit> {
        val terms = fold(query).split(Regex("\\s+")).filter { it.isNotEmpty() }
        if (terms.isEmpty()) return emptyList()
        val out = ArrayList<Hit>()
        fun walk(dir: Uri, path: List<Entry>) {
            for (e in list(ctx, dir)) {
                if (!alive() || out.size >= 500) return
                if (e.isDir) { walk(e.uri, path + e); continue }
                val ls = lines(ctx, e.uri)
                val url = ls.firstOrNull { it.startsWith("URL=", true) }?.substring(4)?.trim()?.ifBlank { null }
                val text = ls.firstOrNull { it.startsWith("TEXT=", true) }?.let { unescape(it.substring(5)) } ?: ""
                val title = e.name.removeSuffix(".url")
                val ft = fold(title)
                val body = url ?: text
                val fb = fold(body)
                val all = ft + "\n" + fb
                if (!terms.all { all.contains(it) }) continue
                val detail = if (url != null) url else {
                    val i = terms.map { fb.indexOf(it) }.filter { it >= 0 }.minOrNull() ?: 0
                    val st = maxOf(0, i - 30)
                    (if (st > 0) "…" else "") + text.substring(st, minOf(text.length, st + 120)).replace(Regex("\\s+"), " ")
                }
                out.add(Hit(e, path, detail, url == null, terms.all { ft.contains(it) }))
            }
        }
        walk(root, emptyList())
        return out.sortedBy { !it.titleMatch }   // başlıkta geçenler önce
    }

    private val badTitles = listOf("just a moment", "access denied", "attention required", "403 forbidden",
        "robot check", "are you a robot", "verifying you are human", "bir dakika", "erişim engellendi")

    /** Sayfanın <title> değerini getirir; olmazsa null. Arka plan thread'inde çağrılmalı. */
    fun fetchTitle(url: String): String? {
        var target = if (url.startsWith("http://", true)) "https://" + url.substring(7) else url
        repeat(5) {
            var conn: HttpURLConnection? = null
            try {
                val c = URL(target).openConnection() as HttpURLConnection
                conn = c
                c.connectTimeout = 4000; c.readTimeout = 4000; c.instanceFollowRedirects = false
                c.setRequestProperty("User-Agent", "Mozilla/5.0 (Linux; Android 13) AppleWebKit/537.36 Chrome/120 Mobile Safari/537.36")
                c.setRequestProperty("Accept-Language", "tr,en;q=0.8")
                val code = c.responseCode
                if (code in 300..399) {
                    val loc = c.getHeaderField("Location") ?: return null
                    target = URL(URL(target), loc).toString()
                    if (target.startsWith("http://", true)) target = "https://" + target.substring(7)
                    return@repeat
                }
                if (code !in 200..299) return null
                return readTitle(c)
            } catch (e: Exception) {
                return null
            } finally { conn?.disconnect() }
        }
        return null
    }

    private fun readTitle(c: HttpURLConnection): String? {
        val buf = ByteArray(160_000)
        var n = 0
        c.inputStream.use { ins ->
            while (n < buf.size) {
                val r = ins.read(buf, n, buf.size - n)
                if (r < 0) break
                n += r
                // </title> görüldüyse fazlasını indirme
                if (String(buf, maxOf(0, n - r - 8), minOf(n, r + 8), Charsets.ISO_8859_1).contains("</title>", true)) break
            }
        }
        val head = String(buf, 0, n, Charsets.ISO_8859_1)
        val cs = Regex("charset=([\\w-]+)", RegexOption.IGNORE_CASE).find(c.contentType ?: "")?.groupValues?.get(1)
            ?: Regex("<meta[^>]+charset=[\"']?([\\w-]+)", RegexOption.IGNORE_CASE).find(head)?.groupValues?.get(1)
        val charset = try { java.nio.charset.Charset.forName(cs ?: "UTF-8") } catch (e: Exception) { Charsets.UTF_8 }
        val html = String(buf, 0, n, charset)
        val raw = Regex("<title[^>]*>(.*?)</title>", setOf(RegexOption.IGNORE_CASE, RegexOption.DOT_MATCHES_ALL))
            .find(html)?.groupValues?.get(1) ?: return null
        val t = android.text.Html.fromHtml(raw, android.text.Html.FROM_HTML_MODE_LEGACY).toString()
            .replace(Regex("\\s+"), " ").trim()
        if (t.isBlank() || badTitles.any { t.startsWith(it, true) }) return null
        return t
    }
}
