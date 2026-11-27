import Foundation

public struct SteamCommand {
    public let executable: URL
    public let arguments: [String]
    public let directory: URL
    public let environment: [String: String]

    public static func make(
        wine: String, prefix: String, windowsExecutable: String,
        installing: Bool, appID: String = "", metalHUD: Bool = false,
        environment inherited: [String: String] = ProcessInfo.processInfo.environment
    ) throws -> SteamCommand {
        let files = FileManager.default
        let loader = try absolutePath(wine, label: "Wine executable")
        let program = try absolutePath(windowsExecutable, label: "Windows executable")
        let prefix = try absolutePath(prefix, label: "Steam environment")
        guard files.isExecutableFile(atPath: loader.path),
              (try? loader.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile) == true else {
            throw SetupError("Choose an executable Wine launcher file.")
        }
        guard program.pathExtension.lowercased() == "exe",
              (try? program.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile) == true else {
            throw SetupError("Choose an existing Windows .exe file.")
        }

        var isDirectory: ObjCBool = false
        let prefixExists = files.fileExists(atPath: prefix.path, isDirectory: &isDirectory)
        if prefixExists && !isDirectory.boolValue {
            throw SetupError("The Steam environment location must be a folder.")
        }
        var isDriveDirectory: ObjCBool = false
        let drive = prefix.appendingPathComponent("drive_c")
        let registry = prefix.appendingPathComponent("system.reg")
        let initialized = files.fileExists(atPath: drive.path, isDirectory: &isDriveDirectory)
            && isDriveDirectory.boolValue
            && (try? registry.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile) == true
        if installing {
            if prefixExists && !initialized {
                let contents = try files.contentsOfDirectory(atPath: prefix.path)
                guard contents.isEmpty else {
                    throw SetupError("Choose a new, empty, or initialized Wine environment.")
                }
            }
            try files.createDirectory(at: prefix.deletingLastPathComponent(), withIntermediateDirectories: true)
        } else if !initialized {
            throw SetupError("Run Steam Setup in this environment first.")
        }

        var arguments = [program.path]
        let appID = appID.trimmingCharacters(in: .whitespacesAndNewlines)
        if !installing && !appID.isEmpty {
            guard appID.utf8.count <= 10,
                  appID.utf8.allSatisfy({ (48...57).contains($0) }),
                  let number = UInt32(appID), number > 0 else {
                throw SetupError("Enter a numeric Steam App ID, for example 271590.")
            }
            arguments += ["-applaunch", String(number)]
        }
        var environment = inherited
        environment["WINEPREFIX"] = prefix.path
        if metalHUD { environment["MTL_HUD_ENABLED"] = "1" }
        return SteamCommand(
            executable: loader, arguments: arguments,
            directory: program.deletingLastPathComponent(), environment: environment
        )
    }

    private static func absolutePath(_ value: String, label: String) throws -> URL {
        let expanded = NSString(string: value).expandingTildeInPath
        guard expanded.hasPrefix("/") else {
            throw SetupError("Choose an absolute path for \(label).")
        }
        return URL(fileURLWithPath: expanded).standardizedFileURL.resolvingSymlinksInPath()
    }

    private struct SetupError: LocalizedError {
        let errorDescription: String?
        init(_ message: String) { errorDescription = message }
    }
}
