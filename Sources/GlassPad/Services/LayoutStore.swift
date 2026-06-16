import Foundation

// MARK: - On-disk representation

struct StoredFolder: Codable, Hashable, Sendable {
    var id: UUID
    var name: String
    var appIDs: [String]
}

/// One persisted grid slot. Codable synthesis handles the associated values.
enum StoredEntry: Codable, Hashable, Sendable {
    case app(path: String)
    case folder(StoredFolder)
}

struct StoredLayout: Codable, Sendable {
    var version: Int
    var entries: [StoredEntry]
}

/// Persists the grid arrangement (item order + folders) to
/// `~/Library/Application Support/GlassPad/layout.json`. Stateless + `Sendable`,
/// so reads/writes run off the main actor.
enum LayoutStore {
    static let currentVersion = 1

    static var fileURL: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSHomeDirectory() + "/Library/Application Support")
        return base
            .appendingPathComponent("GlassPad", isDirectory: true)
            .appendingPathComponent("layout.json", isDirectory: false)
    }

    static func load() -> StoredLayout? {
        guard let data = try? Data(contentsOf: fileURL) else { return nil }
        return try? JSONDecoder().decode(StoredLayout.self, from: data)
    }

    static func save(_ layout: StoredLayout) {
        do {
            let dir = fileURL.deletingLastPathComponent()
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(layout)
            try data.write(to: fileURL, options: .atomic)
        } catch {
            NSLog("GlassPad: failed to save layout: \(error.localizedDescription)")
        }
    }
}
