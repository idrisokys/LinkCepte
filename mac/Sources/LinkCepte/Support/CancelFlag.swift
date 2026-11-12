import Foundation

/// İptal edilebilir arka plan işleri (arama) için iş parçacığı güvenli bayrak.
final class CancelFlag: @unchecked Sendable {
    private let l = NSLock()
    private var v = false
    func cancel() { l.lock(); v = true; l.unlock() }
    var isCancelled: Bool { l.lock(); defer { l.unlock() }; return v }
}
