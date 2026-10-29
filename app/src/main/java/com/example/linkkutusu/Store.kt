package com.example.linkkutusu

import android.content.Context
import android.net.Uri
import androidx.documentfile.provider.DocumentFile

object Store {
    private const val ORDER = ".order.txt"

    fun root(ctx: Context): DocumentFile? {
        val s = ctx.getSharedPreferences("p", 0).getString("root", null) ?: return null
        val d = DocumentFile.fromTreeUri(ctx, Uri.parse(s))
        return if (d != null && d.canWrite()) d else null
    }

    fun setRoot(ctx: Context, uri: Uri) {
        ctx.contentResolver.takePersistableUriPermission(
            uri, android.content.Intent.FLAG_GRANT_READ_URI_PERMISSION or android.content.Intent.FLAG_GRANT_WRITE_URI_PERMISSION)
        ctx.getSharedPreferences("p", 0).edit().putString("root", uri.toString()).apply()
    }

    private fun clean(s: String) = s.replace(Regex("[\\\\/:*?\"<>|\\n\\r]"), "_").trim().take(80).ifBlank { "link" }

    private fun uniqueName(dir: DocumentFile, base: String): String {
        var name = "$base.url"; var n = 2
        while (dir.findFile(name) != null) { name = "$base ($n).url"; n++ }
        return name
    }

    fun list(ctx: Context, dir: DocumentFile): List<DocumentFile> {
        val files = dir.listFiles().filter { it.name != null && !it.name!!.startsWith(".") && (it.isDirectory || it.name!!.endsWith(".url")) }
        val order = readOrder(ctx, dir)
        val byName = files.associateBy { it.name!! }
        val ordered = order.mapNotNull { byName[it] }
        val rest = files.filter { it.name !in order }.sortedWith(compareBy({ !it.isDirectory }, { it.name }))
        return ordered + rest
    }

    private fun readOrder(ctx: Context, dir: DocumentFile): List<String> {
        val f = dir.findFile(ORDER) ?: return emptyList()
        return try { ctx.contentResolver.openInputStream(f.uri)!!.bufferedReader().readLines().filter { it.isNotBlank() } } catch (e: Exception) { emptyList() }
    }

    private fun saveOrder(ctx: Context, dir: DocumentFile, names: List<String>) {
        val f = dir.findFile(ORDER) ?: dir.createFile("text/plain", ORDER) ?: return
        ctx.contentResolver.openOutputStream(f.uri, "wt")?.use { it.write(names.joinToString("\n").toByteArray()) }
    }

    fun move(ctx: Context, dir: DocumentFile, index: Int, delta: Int) {
        val names = list(ctx, dir).map { it.name!! }.toMutableList()
        val j = index + delta
        if (j !in names.indices) return
        names.add(j, names.removeAt(index))
        saveOrder(ctx, dir, names)
    }

    private fun write(ctx: Context, dir: DocumentFile, baseTitle: String, content: ByteArray): DocumentFile? {
        val f = dir.createFile("application/octet-stream", uniqueName(dir, clean(baseTitle))) ?: return null
        ctx.contentResolver.openOutputStream(f.uri)?.use { it.write(content) } ?: return null
        saveOrder(ctx, dir, list(ctx, dir).map { it.name!! }.filter { it != f.name } + f.name!!)
        return f
    }

    fun addLink(ctx: Context, dir: DocumentFile, title: String, url: String) =
        write(ctx, dir, title, "[InternetShortcut]\r\nURL=$url\r\n".toByteArray()) != null

    /** Linki başka klasöre taşır (kopyala + sil). */
    fun moveLink(ctx: Context, file: DocumentFile, target: DocumentFile): Boolean {
        val bytes = ctx.contentResolver.openInputStream(file.uri)?.use { it.readBytes() } ?: return false
        if (write(ctx, target, file.name!!.removeSuffix(".url"), bytes) == null) return false
        return file.delete()
    }

    fun addFolder(dir: DocumentFile, name: String) = dir.createDirectory(clean(name))

    fun readUrl(ctx: Context, f: DocumentFile): String? = try {
        ctx.contentResolver.openInputStream(f.uri)!!.bufferedReader().readLines()
            .firstOrNull { it.startsWith("URL=", true) }?.substring(4)?.trim()
    } catch (e: Exception) { null }
}
