package com.example.linkkutusu

import android.content.Context
import android.net.Uri
import androidx.documentfile.provider.DocumentFile
import java.io.InputStream
import java.io.OutputStream
import java.util.zip.ZipEntry
import java.util.zip.ZipInputStream
import java.util.zip.ZipOutputStream

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

    /** Klasör içeriği: kayıtlı sıraya göre; sırada olmayanlar sona (klasörler önce). */
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

    fun saveOrder(ctx: Context, dir: DocumentFile, names: List<String>) {
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

    fun addLink(ctx: Context, dir: DocumentFile, title: String, url: String): Boolean {
        val base = clean(title)
        var name = "$base.url"; var n = 2
        while (dir.findFile(name) != null) { name = "$base ($n).url"; n++ }
        val f = dir.createFile("application/octet-stream", name) ?: return false
        ctx.contentResolver.openOutputStream(f.uri)?.use { it.write("[InternetShortcut]\r\nURL=$url\r\n".toByteArray()) } ?: return false
        val names = list(ctx, dir).map { it.name!! }.filter { it != f.name } + (f.name ?: name)
        saveOrder(ctx, dir, names)
        return true
    }

    fun addFolder(dir: DocumentFile, name: String) = dir.createDirectory(clean(name))

    fun readUrl(ctx: Context, f: DocumentFile): String? = try {
        ctx.contentResolver.openInputStream(f.uri)!!.bufferedReader().readLines()
            .firstOrNull { it.startsWith("URL=", true) }?.substring(4)?.trim()
    } catch (e: Exception) { null }

    // ---- Yedekleme / geri yükleme (zip) ----
    fun backup(ctx: Context, root: DocumentFile, out: OutputStream) {
        ZipOutputStream(out).use { z -> zipDir(ctx, root, "", z) }
    }

    private fun zipDir(ctx: Context, dir: DocumentFile, prefix: String, z: ZipOutputStream) {
        for (f in dir.listFiles()) {
            val name = f.name ?: continue
            if (f.isDirectory) { zipDir(ctx, f, "$prefix$name/", z) }
            else {
                z.putNextEntry(ZipEntry(prefix + name))
                ctx.contentResolver.openInputStream(f.uri)?.use { it.copyTo(z) }
                z.closeEntry()
            }
        }
    }

    fun restore(ctx: Context, root: DocumentFile, input: InputStream) {
        ZipInputStream(input).use { z ->
            var e = z.nextEntry
            while (e != null) {
                if (!e.isDirectory && !e.name.contains("..")) {
                    val parts = e.name.split("/")
                    var d = root
                    for (p in parts.dropLast(1)) d = d.findFile(p)?.takeIf { it.isDirectory } ?: d.createDirectory(p) ?: return
                    val fname = parts.last()
                    d.findFile(fname)?.delete()
                    val f = d.createFile(if (fname.endsWith(".txt")) "text/plain" else "application/octet-stream", fname)
                    if (f != null) ctx.contentResolver.openOutputStream(f.uri)?.let { o -> o.use { z.copyTo(it) } }
                }
                e = z.nextEntry
            }
        }
    }
}
