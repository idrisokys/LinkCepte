package com.example.linkkutusu

import android.app.Activity
import android.content.Intent
import android.os.Bundle
import android.widget.Toast
import java.net.URI

class ShareActivity : Activity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        val text = intent.getStringExtra(Intent.EXTRA_TEXT).orEmpty()
        val subject = intent.getStringExtra(Intent.EXTRA_SUBJECT)
        val app = applicationContext
        Thread {
            val url = Regex("https?://\\S+").find(text)?.value
            val root = Store.root(app)
            val msg = when {
                url == null -> "Link bulunamadı"
                root == null -> "Önce Link Cepte’yi açıp klasör seçin"
                else -> {
                    val title = Store.fetchTitle(url)
                        ?: subject?.lines()?.firstOrNull { it.isNotBlank() }
                        ?: text.replace(url, "").lines().firstOrNull { it.isNotBlank() }
                        ?: runCatching { URI(url).host }.getOrNull() ?: "link"
                    if (Store.addLink(app, root, title, url)) "Link kaydedildi" else "Kaydedilemedi"
                }
            }
            runOnUiThread {
                Toast.makeText(app, msg, Toast.LENGTH_SHORT).show()
                finish()
            }
        }.start()
    }
}
