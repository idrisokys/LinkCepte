package com.example.linkkutusu

import android.app.Activity
import android.content.Intent
import android.os.Bundle
import android.widget.Toast

class ShareActivity : Activity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        val text = intent.getCharSequenceExtra(Intent.EXTRA_TEXT)?.toString().orEmpty()
        val subject = intent.getCharSequenceExtra(Intent.EXTRA_SUBJECT)?.toString()
        val app = applicationContext
        Thread {
            val root = Store.root(app)
            val msg = when {
                text.isBlank() -> "Paylaşılacak bir şey bulunamadı"
                root == null -> "Önce Link Cepte’yi açıp klasör seçin"
                Store.addFromText(app, root, text, subject) -> "Kaydedildi"
                else -> "Kaydedilemedi"
            }
            runOnUiThread {
                Toast.makeText(app, msg, Toast.LENGTH_SHORT).show()
                finish()
            }
        }.start()
    }
}
