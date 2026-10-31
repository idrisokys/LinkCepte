package com.example.linkkutusu

import java.util.Locale

/** Cihaz dili Türkçe ise Türkçe, değilse İngilizce metin döndürür (Mac sürümündeki L ile aynı). */
fun L(tr: String, en: String): String = if (Locale.getDefault().language == "tr") tr else en
