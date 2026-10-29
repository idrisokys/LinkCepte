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

    fun delete(ctx: Context, uri: Uri) {
        try { DC.deleteDocument(ctx.contentResolver, uri) } catch (e: Exception) { }
    }

    fun readUrl(ctx: Context, uri: Uri): String? = try {
        ctx.contentResolver.openInputStream(uri)?.bufferedReader()?.use { r ->
            r.readLines().map { it.trim().removePrefix("\uFEFF") }.firstOrNull { it.startsWith("URL=", true) }?.substring(4)?.trim()
        }
    } catch (e: Exception) { null }
}
