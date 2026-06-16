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
    static func discoverApps() -> [InstalledApp] {
        let fm = FileManager.default
        var seen = Set<String>()
        var result: [InstalledApp] = []

        for dir in searchPaths {
            guard let entries = try? fm.contentsOfDirectory(
                at: dir,
                includingPropertiesForKeys: [.isApplicationKey],
                options: [.skipsHiddenFiles]
            ) else { continue }

            for url in entries where url.pathExtension == "app" {
                let path = url.path
                guard seen.insert(path).inserted else { continue }
                let app = InstalledApp(
                    id: path,
                    name: displayName(for: url, fileManager: fm),
                    url: url,
                    bundleID: Bundle(url: url)?.bundleIdentifier
                )
                result.append(app)
            }
        }

        return result.sorted {
            $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
        }
    }

    private static func displayName(for url: URL, fileManager fm: FileManager) -> String {
        var name = fm.displayName(atPath: url.path)
        if name.hasSuffix(".app") { name.removeLast(4) }
        return name
    }
}
