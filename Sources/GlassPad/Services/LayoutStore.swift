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

/// Outcome of a load attempt, kept distinct so the caller never confuses
/// "no file yet" with "file present but unreadable" (the latter must NOT trigger
/// a destructive default write-back).
enum LayoutLoad: Sendable {
    case missing
    case failed
    case loaded(StoredLayout)
}

/// Persists the grid arrangement to `~/Library/Application Support/GlassPad/
/// layout.json`. All disk access is funneled through one serial queue so reads
/// and writes are FIFO-ordered (no torn reads, no out-of-order last-writer).
enum LayoutStore {
    static let currentVersion = 1
    private static let ioQueue = DispatchQueue(label: "com.glasspad.layoutstore")

    static var fileURL: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSHomeDirectory() + "/Library/Application Support")
        return base
            .appendingPathComponent("GlassPad", isDirectory: true)
            .appendingPathComponent("layout.json", isDirectory: false)
    }

    static func load() -> LayoutLoad {
        ioQueue.sync {
            let fm = FileManager.default
            guard fm.fileExists(atPath: fileURL.path) else { return .missing }
            do {
                let data = try Data(contentsOf: fileURL)
                return .loaded(try JSONDecoder().decode(StoredLayout.self, from: data))
            } catch {
                // Preserve the unreadable file for recovery, then report failure so
                // the caller keeps the user's arrangement instead of overwriting it.
                backUpUnreadableFile()
                NSLog("GlassPad: failed to load layout (backed up to layout.json.bak): \(error.localizedDescription)")
                return .failed
            }
        }
    }

    static func save(_ layout: StoredLayout) {
        ioQueue.async {
            do {
                let dir = fileURL.deletingLastPathComponent()
                try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
                let encoder = JSONEncoder()
                encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
                try encoder.encode(layout).write(to: fileURL, options: .atomic)
            } catch {
                NSLog("GlassPad: failed to save layout: \(error.localizedDescription)")
            }
        }
    }

    private static func backUpUnreadableFile() {
        let backup = fileURL.appendingPathExtension("bak")
        try? FileManager.default.removeItem(at: backup)
        try? FileManager.default.copyItem(at: fileURL, to: backup)
    }
}
