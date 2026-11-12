import XCTest
@testable import LinkCepte

final class StoreHelpersTests: XCTestCase {
    func testFoldIgnoresTurkishLettersCaseAndAccents() {
        XCTAssertEqual(Store.fold("İstanbul"), "istanbul")
        XCTAssertEqual(Store.fold("ŞĞÜÖÇı"), "sguoci")
        XCTAssertEqual(Store.fold("Café"), "cafe")
    }

    func testExtractUrlStripsTrailingPunctuation() {
        XCTAssertEqual(Store.extractUrl("bak https://example.com/a?b=1."), "https://example.com/a?b=1")
        XCTAssertEqual(Store.extractUrl("(https://example.com/x)"), "https://example.com/x")
        XCTAssertEqual(Store.extractUrl("https://en.wikipedia.org/wiki/Swift_(programming_language)"),
                       "https://en.wikipedia.org/wiki/Swift_(programming_language)")
        XCTAssertNil(Store.extractUrl("burada link yok"))
    }

    func testCleanProducesSafeFileNames() {
        XCTAssertEqual(Store.clean("a:b"), "a - b")
        XCTAssertEqual(Store.clean("what?"), "what")
        XCTAssertEqual(Store.clean("  ..hidden"), "hidden")
        XCTAssertEqual(Store.clean("***"), "link")
        XCTAssertEqual(Store.clean(String(repeating: "a", count: 300), 10), String(repeating: "a", count: 10))
    }

    func testFitBytesStaysWithinLimit() {
        let s = String(repeating: "ş", count: 200)   // her biri 2 bayt
        XCTAssertEqual(Store.fitBytes(s, limit: 240).utf8.count, 240)
    }

    func testEntryTitleAndKind() {
        let dir = URL(fileURLWithPath: "/tmp")
        let link = Entry(name: "a.url", url: dir.appendingPathComponent("a.url"), isDir: false)
        XCTAssertEqual(link.title, "a")
        XCTAssertFalse(link.isTxt)
        let txt = Entry(name: "n.TXT", url: dir.appendingPathComponent("n.TXT"), isDir: false)
        XCTAssertTrue(txt.isTxt)
        XCTAssertEqual(txt.title, "n")
        XCTAssertEqual(txt.ext, ".txt")
        let folder = Entry(name: "Klasör", url: dir.appendingPathComponent("Klasör"), isDir: true)
        XCTAssertEqual(folder.title, "Klasör")
    }
}
