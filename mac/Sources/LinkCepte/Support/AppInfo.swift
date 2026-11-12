import Foundation

/// Kodda birden fazla yerde geçen sabitler. (Info.plist ve ShareExtension bunları ayrıca yazar;
/// değiştirirseniz `Resources/Info.plist` ve `ShareExtension/` içindekileri de güncelleyin.)
enum AppInfo {
    static let bundleID = "io.github.idrisokys.linkcepte.mac"
    static let shareExtensionID = bundleID + ".share"
    static let urlScheme = "linkcepte"
    static let supportFolderName = "Link Cepte"
    static let contactEmail = "sislivadi@gmail.com"
    static let githubURL = URL(string: "https://github.com/idrisokys/")!
}
