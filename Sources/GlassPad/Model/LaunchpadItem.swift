import Foundation

/// A folder of apps. References apps by their stable id (bundle path).
struct Folder: Identifiable, Hashable, Sendable {
    let id: UUID
    var name: String
    var appIDs: [String]
}

/// A slot in the launcher grid: either a loose app or a folder.
enum LaunchpadItem: Identifiable, Hashable, Sendable {
    case app(InstalledApp)
    case folder(Folder)

    var id: String {
        switch self {
        case .app(let app): return Self.appItemID(app.id)
        case .folder(let folder): return Self.folderItemID(folder.id)
        }
    }

    static func appItemID(_ appID: String) -> String { "app:" + appID }
    static func folderItemID(_ folderID: UUID) -> String { "folder:" + folderID.uuidString }
}
