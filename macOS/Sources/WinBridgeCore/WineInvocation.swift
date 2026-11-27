import Foundation

public struct WineInvocation {
    public let executable: URL
    public let arguments: [String]
    public let directory: URL
    public let environment: [String: String]

    public func makeProcess() -> Process {
        let process = Process()
        process.executableURL = executable
        process.arguments = arguments
        process.currentDirectoryURL = directory
        process.environment = environment
        return process
    }

    static func absolutePath(_ value: String, label: String) throws -> URL {
        let path = NSString(string: value).expandingTildeInPath
        guard path.hasPrefix("/") else { throw WindowsError("Choose an absolute path for \(label).") }
        return URL(fileURLWithPath: path).standardizedFileURL.resolvingSymlinksInPath()
    }

    static func loader(_ wine: String) throws -> URL {
        let url = try absolutePath(wine, label: "Wine executable")
        guard FileManager.default.isExecutableFile(atPath: url.path),
              (try? url.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile) == true else {
            throw WindowsError("Choose an executable Wine launcher file.")
        }
        return url
    }

    static func preparePrefix(_ prefix: URL, allowNew: Bool) throws {
        let files = FileManager.default
        var isDirectory: ObjCBool = false
        let exists = files.fileExists(atPath: prefix.path, isDirectory: &isDirectory)
        if exists && !isDirectory.boolValue { throw WindowsError("The Windows environment must be a folder.") }
        if initialized(prefix) { return }
        if !allowNew { throw WindowsError("Initialize this Windows environment first.") }
        if exists, try !files.contentsOfDirectory(atPath: prefix.path).isEmpty {
            throw WindowsError("This environment is incomplete and contains files. Create a new environment or inspect the existing files.")
        }
        try files.createDirectory(at: prefix.deletingLastPathComponent(), withIntermediateDirectories: true)
    }

    static func initialized(_ prefix: URL) -> Bool {
        let drive = prefix.appendingPathComponent("drive_c")
        let registry = prefix.appendingPathComponent("system.reg")
        var isDirectory: ObjCBool = false
        return FileManager.default.fileExists(atPath: drive.path, isDirectory: &isDirectory)
            && isDirectory.boolValue
            && (try? registry.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile) == true
    }
}
