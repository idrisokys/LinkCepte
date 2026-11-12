import Foundation

enum Lang {
    /// Cihazın birinci dili Türkçe ise true; aksi halde uygulama İngilizce çalışır.
    static let isTurkish: Bool = (Locale.preferredLanguages.first ?? "en").lowercased().hasPrefix("tr")
}

/// Metnin Türkçe ve İngilizce karşılığı; cihaz diline göre uygun olanı döndürür.
func L(_ turkish: String, _ english: String) -> String {
    Lang.isTurkish ? turkish : english
}
