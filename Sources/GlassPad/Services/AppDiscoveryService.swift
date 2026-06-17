import AppKit

/// Scans the standard application directories for `.app` bundles. Stateless and
/// `Sendable`, so it can run off the main actor via `Task.detached`.
enum AppDiscoveryService {
    /// Top-level directories to scan. We do NOT recurse into `.app` bundles.
    static let searchPaths: [URL] = {
        let paths = [
            "/Applications",
            "/Applications/Utilities",
            "/System/Applications",
            "/System/Applications/Utilities",
            NSHomeDirectory() + "/Applications",
        ]
        return paths.map { URL(fileURLWithPath: $0, isDirectory: true) }
    }()

    /// Discover all installed apps, de-duplicated by path and sorted by name.
    ///
    /// Uses the **path-based** directory listing, not the URL-based one: the URL
    /// enumerator silently drops symlinked system apps whose relative target points
    /// into a Cryptex (e.g. `/Applications/Safari.app → ../System/Cryptexes/…`),
    /// reading them as "dangling" when `/Applications` is traversed via its data
    /// firmlink. The path listing returns them. We also descend **one level** into
    /// plain subfolders (e.g. `Python 3.11/IDLE.app`) — but never into `.app` bundles.
    static func discoverApps() -> [InstalledApp] {
        let fm = FileManager.default
        var seen = Set<String>()
        var result: [InstalledApp] = []

        func consider(_ url: URL) {
            guard url.pathExtension == "app" else { return }
            // De-dupe by the resolved (canonical) path so the same physical bundle
            // reached via a symlink/alias only appears once — keep the readable raw
            // path as the stable id.
            let canonical = url.resolvingSymlinksInPath().standardizedFileURL.path
            guard seen.insert(canonical).inserted else { return }
            result.append(InstalledApp(
                id: url.path,
                name: displayName(for: url, fileManager: fm),
                url: url,
                bundleID: Bundle(url: url)?.bundleIdentifier
            ))
        }

        for dir in searchPaths {
            guard let names = try? fm.contentsOfDirectory(atPath: dir.path) else { continue }
            for name in names {
                let url = dir.appendingPathComponent(name)
                if name.hasSuffix(".app") {
                    consider(url)
                } else if isDirectory(url) {
                    // One level into a plain subfolder; don't recurse further.
                    if let sub = try? fm.contentsOfDirectory(atPath: url.path) {
                        for subName in sub where subName.hasSuffix(".app") {
                            consider(url.appendingPathComponent(subName))
                        }
                    }
                }
            }
        }

        return result.sorted {
            $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
        }
    }

    private static func isDirectory(_ url: URL) -> Bool {
        var isDir: ObjCBool = false
        return FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir) && isDir.boolValue
    }

    private static func displayName(for url: URL, fileManager fm: FileManager) -> String {
        var name = fm.displayName(atPath: url.path)
        if name.hasSuffix(".app") { name.removeLast(4) }
        return name
    }
}
