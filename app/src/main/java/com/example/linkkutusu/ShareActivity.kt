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
        val url = Regex("https?://\\S+").find(text)?.value
        val root = Store.root(this)
        val msg = when {
            url == null -> "Link bulunamadı"
            root == null -> "Önce Link Cepte’yi açıp klasör seçin"
            else -> {
                val title = intent.getStringExtra(Intent.EXTRA_SUBJECT)?.takeIf { it.isNotBlank() }
                    ?: text.replace(url, "").trim().takeIf { it.isNotBlank() }
                    ?: runCatching { URI(url).host }.getOrNull() ?: "link"
                if (Store.addLink(this, root, title, url)) "Link kaydedildi" else "Kaydedilemedi"
            }
        }
        Toast.makeText(this, msg, Toast.LENGTH_SHORT).show()
        finish()
    }
}
