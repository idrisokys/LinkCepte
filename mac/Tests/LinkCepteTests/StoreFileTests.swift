import XCTest
@testable import LinkCepte

/// Geçici bir klasörde gerçek dosya işlemlerini dener (~/Link'e dokunmaz).
final class StoreFileTests: XCTestCase {
    private var dir: URL!

    override func setUpWithError() throws {
        dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("linkcepte-test-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: dir)
    }

    func testAddLinkRoundTrip() {
        XCTAssertTrue(Store.addLink(dir, title: "Example: Site", url: "https://example.com"))
        let items = Store.list(dir)
        XCTAssertEqual(items.count, 1)
        XCTAssertEqual(items[0].title, "Example - Site")
        XCTAssertEqual(Store.readLink(items[0].url).0, "https://example.com")
    }

    func testNewItemsKeepInsertionOrder() {
        for t in ["b", "a", "c"] { XCTAssertTrue(Store.addLink(dir, title: t, url: "https://example.com/\(t)")) }
        XCTAssertEqual(Store.list(dir).map { $0.title }, ["b", "a", "c"])
    }

    func testDuplicateTitlesGetNumberSuffix() {
        XCTAssertTrue(Store.addLink(dir, title: "b", url: "https://example.com/1"))
        XCTAssertTrue(Store.addLink(dir, title: "b", url: "https://example.com/2"))
        XCTAssertEqual(Store.list(dir).map { $0.title }, ["b", "b (2)"])
    }

    func testNoteKeepsNewlines() {
        XCTAssertTrue(Store.addNote(dir, text: "line1\nline2"))
        let e = Store.list(dir)[0]
        let (url, text) = Store.readLink(e.url)
        XCTAssertNil(url)
        XCTAssertEqual(text, "line1\nline2")
    }

    func testTextFileRoundTrip() {
        XCTAssertTrue(Store.addTextFile(dir, text: "hello world"))
        let e = Store.list(dir)[0]
        XCTAssertTrue(e.isTxt)
        XCTAssertEqual(Store.readPlain(e.url), "hello world")
        XCTAssertTrue(Store.writePlain(e.url, "changed"))
        XCTAssertEqual(Store.readPlain(e.url), "changed")
    }

    func testRenameKeepsExtension() {
        XCTAssertTrue(Store.addLink(dir, title: "old", url: "https://example.com"))
        let e = Store.list(dir)[0]
        XCTAssertTrue(Store.rename(dir, e, "new"))
        let after = Store.list(dir)
        XCTAssertEqual(after.map { $0.title }, ["new"])
        XCTAssertEqual(after[0].name, "new.url")
    }

    func testSearchFindsAcrossFoldersAndTurkishLetters() {
        let sub = Store.addFolder(dir, "Work")
        XCTAssertNotNil(sub)
        XCTAssertTrue(Store.addLink(sub!, title: "Swift Docs", url: "https://developer.apple.com/swift"))
        XCTAssertTrue(Store.addNote(dir, text: "Çalışma Notları"))

        let a = Store.search(root: dir, query: "SWIFT", alive: { true })
        XCTAssertEqual(a.count, 1)
        XCTAssertEqual(a.first?.entry.title, "Swift Docs")
        XCTAssertEqual(a.first?.path.map { $0.name }, ["Work"])

        let b = Store.search(root: dir, query: "calisma notlari", alive: { true })
        XCTAssertEqual(b.count, 1)
    }
}
