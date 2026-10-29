package com.example.linkkutusu

import android.content.Context
import android.content.Intent
import android.net.Uri
import android.provider.DocumentsContract as DC

data class Entry(val name: String, val uri: Uri, val isDir: Boolean)

object Store {
    private const val ORDER = ".order.txt"
    private const val OCTET = "application/octet-stream"
    private const val FLAGS = Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_GRANT_WRITE_URI_PERMISSION

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

    private fun clean(s: String): String =
        s.replace(Regex("[\\\\/:*?\"<>|\\n\\r]"), "_").trim().trimStart('.').take(80).ifBlank { "link" }

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

    fun list(ctx: Context, dir: Uri): List<Entry> {
        val all = children(ctx, dir)
        val files = all.filter { !it.name.startsWith(".") && (it.isDir || it.name.endsWith(".url", true)) }
        val byName = files.associateBy { it.name }
        val ordered = readOrder(ctx, all).distinct().mapNotNull { byName[it] }
        val seen = ordered.map { it.name }.toSet()
        val rest = files.filter { it.name !in seen }.sortedWith(compareBy({ !it.isDir }, { it.name.lowercase() }))
        return ordered + rest
    }

    private fun readOrder(ctx: Context, all: List<Entry>): List<String> {
        val f = all.firstOrNull { it.name == ORDER } ?: return emptyList()
        return try {
            ctx.contentResolver.openInputStream(f.uri)?.bufferedReader()?.use { r -> r.readLines().filter { it.isNotBlank() } } ?: emptyList()
        } catch (e: Exception) { emptyList() }
    }

    fun saveOrder(ctx: Context, dir: Uri, names: List<String>) {
        try {
            val f = children(ctx, dir).firstOrNull { it.name == ORDER }?.uri
                ?: DC.createDocument(ctx.contentResolver, dir, "text/plain", ORDER) ?: return
            ctx.contentResolver.openOutputStream(f, "wt")?.use { it.write(names.joinToString("\n").toByteArray()) }
        } catch (e: Exception) { }
    }

    private fun write(ctx: Context, dir: Uri, base: String, bytes: ByteArray): Boolean {
        try {
            val taken = children(ctx, dir).map { it.name.lowercase() }.toSet()
            val b = clean(base)
            var name = "$b.url"; var i = 2
            while (name.lowercase() in taken) { name = "$b ($i).url"; i++ }
            val f = DC.createDocument(ctx.contentResolver, dir, OCTET, name) ?: return false
            ctx.contentResolver.openOutputStream(f, "w")?.use { it.write(bytes) } ?: return false
            saveOrder(ctx, dir, list(ctx, dir).map { it.name })
            return true
        } catch (e: Exception) { return false }
    }

    fun addLink(ctx: Context, dir: Uri, title: String, url: String): Boolean =
        write(ctx, dir, title, "[InternetShortcut]\r\nURL=$url\r\n".toByteArray())

    fun moveLink(ctx: Context, e: Entry, target: Uri): Boolean {
        try {
            val bytes = ctx.contentResolver.openInputStream(e.uri)?.use { it.readBytes() } ?: return false
            if (!write(ctx, target, e.name.removeSuffix(".url"), bytes)) return false
            return DC.deleteDocument(ctx.contentResolver, e.uri)
        } catch (ex: Exception) { return false }
    }

    fun addFolder(ctx: Context, dir: Uri, name: String) {
        try { DC.createDocument(ctx.contentResolver, dir, DC.Document.MIME_TYPE_DIR, clean(name)) } catch (e: Exception) { }
    }

    /** Link (.url) veya klasör adını değiştirir; sıralamayı korur. */
    fun rename(ctx: Context, dir: Uri, e: Entry, title: String): Boolean {
        try {
            val base = clean(title)
            val newName = if (e.isDir) base else "$base.url"
            if (newName == e.name) return true
            if (children(ctx, dir).any { it.name.equals(newName, true) && it.uri != e.uri }) return false
            val order = list(ctx, dir).map { it.name }
            DC.renameDocument(ctx.contentResolver, e.uri, newName) ?: return false
            saveOrder(ctx, dir, order.map { if (it == e.name) newName else it })
            return true
        } catch (ex: Exception) { return false }
    }

    fun delete(ctx: Context, uri: Uri) {
        try { DC.deleteDocument(ctx.contentResolver, uri) } catch (e: Exception) { }
    }

    fun readUrl(ctx: Context, uri: Uri): String? = try {
        ctx.contentResolver.openInputStream(uri)?.bufferedReader()?.use { r ->
            r.readLines().map { it.trim().removePrefix("\uFEFF") }.firstOrNull { it.startsWith("URL=", true) }?.substring(4)?.trim()
        }
    } catch (e: Exception) { null }

    /** Düz metni de kaydeder (URL olmayan kayıt). */
    fun addNote(ctx: Context, dir: Uri, text: String): Boolean {
        val title = text.lines().firstOrNull { it.isNotBlank() }?.trim() ?: "not"
        val enc = text.replace("\\", "\\\\").replace("\r", "").replace("\n", "\\n")
        return write(ctx, dir, title, "[InternetShortcut]\r\nTEXT=$enc\r\n".toByteArray())
    }

    fun readText(ctx: Context, uri: Uri): String? = try {
        ctx.contentResolver.openInputStream(uri)?.bufferedReader()?.use { r ->
            r.readLines().map { it.trim().removePrefix("\uFEFF") }.firstOrNull { it.startsWith("TEXT=", true) }?.substring(5)?.let { dec ->
                val sb = StringBuilder(); var i = 0
                while (i < dec.length) {
                    val c = dec[i]
                    if (c == '\\' && i + 1 < dec.length) { sb.append(if (dec[i + 1] == 'n') '\n' else dec[i + 1]); i += 2 }
                    else { sb.append(c); i++ }
                }
                sb.toString()
            }
        }
    } catch (e: Exception) { null }

    /** Sayfanın <title> değerini getirir; olmazsa null. Arka plan thread'inde çağrılmalı. */
    fun fetchTitle(url: String): String? {
        var conn: java.net.HttpURLConnection? = null
        return try {
            conn = (java.net.URL(url).openConnection() as java.net.HttpURLConnection).apply {
                connectTimeout = 5000; readTimeout = 5000; instanceFollowRedirects = true
                setRequestProperty("User-Agent", "Mozilla/5.0 (Linux; Android 13) AppleWebKit/537.36 Chrome/120 Mobile Safari/537.36")
                setRequestProperty("Accept-Language", "tr,en;q=0.8")
            }
            if (conn.responseCode !in 200..299) return null
            val buf = ByteArray(200_000)
            var n = 0
            conn.inputStream.use { ins ->
                while (n < buf.size) { val r = ins.read(buf, n, buf.size - n); if (r < 0) break; n += r }
            }
            val head = String(buf, 0, n, Charsets.ISO_8859_1)
            val cs = Regex("charset=([\\w-]+)", RegexOption.IGNORE_CASE).find(conn.contentType ?: "")?.groupValues?.get(1)
                ?: Regex("<meta[^>]+charset=[\"']?([\\w-]+)", RegexOption.IGNORE_CASE).find(head)?.groupValues?.get(1)
            val charset = try { java.nio.charset.Charset.forName(cs ?: "UTF-8") } catch (e: Exception) { Charsets.UTF_8 }
            val html = String(buf, 0, n, charset)
            val raw = Regex("<title[^>]*>(.*?)</title>", setOf(RegexOption.IGNORE_CASE, RegexOption.DOT_MATCHES_ALL)).find(html)?.groupValues?.get(1)
                ?: return null
            val t = android.text.Html.fromHtml(raw, android.text.Html.FROM_HTML_MODE_LEGACY).toString().replace(Regex("\\s+"), " ").trim()
            t.ifBlank { null }
        } catch (e: Exception) { null } finally { conn?.disconnect() }
    }
}
