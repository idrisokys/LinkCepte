package io.github.idrisokys.linkcepte

import android.app.Activity
import android.os.Bundle
import android.widget.Toast

/** Dropbox giriş sayfasından db-<APP_KEY>://1/connect adresiyle dönüşü karşılar. */
class DropboxAuthActivity : Activity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        val data = intent?.data
        if (data == null) { finish(); return }
        val app = applicationContext
        Thread {
            val msg = try {
                Dropbox.finishAuth(app, data)
                L("Dropbox'a bağlandı", "Connected to Dropbox")
            } catch (e: Exception) { L("Dropbox bağlantısı başarısız: ", "Dropbox connection failed: ") + e.message }
            runOnUiThread { Toast.makeText(app, msg, Toast.LENGTH_LONG).show(); finish() }
        }.start()
    }
}
