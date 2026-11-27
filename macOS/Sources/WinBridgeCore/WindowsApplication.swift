import Foundation

public struct WindowsApplication: Codable, Identifiable, Equatable {
    public let id: UUID
    public var name: String
    public var location: String
    public var wine: String = ""
    public var executable: String = ""
    public var installer: String = ""
    public var metalHUD = false

    public init(name: String, location: URL) {
        self.id = UUID()
        self.name = name
        self.location = location.path
    }

    public var prefix: URL {
        URL(fileURLWithPath: location, isDirectory: true)
            .appendingPathComponent(id.uuidString, isDirectory: true)
    }

    public var isInitialized: Bool { WineInvocation.initialized(prefix) }

    public enum Action: Equatable {
        case initialize, run, install, uninstall
    }

    public func command(
        _ action: Action, bundledWine: String?, silentMSI: Bool = false,
        environment inherited: [String: String] = ProcessInfo.processInfo.environment
    ) throws -> WineInvocation {
        let loader = try WineInvocation.loader(wine.isEmpty ? bundledWine ?? "" : wine)
        let base = try WineInvocation.absolutePath(location, label: "environment storage")
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: base.path, isDirectory: &isDirectory), isDirectory.boolValue else {
            throw WindowsError("The environment storage folder is unavailable. Reconnect the disk or choose an existing folder.")
        }
        let prefix = base.appendingPathComponent(id.uuidString, isDirectory: true)
        guard !((try? prefix.resourceValues(forKeys: [.isSymbolicLinkKey]).isSymbolicLink) ?? false) else {
            throw WindowsError("The Windows environment folder is a symbolic link.")
        }
        var environment = inherited
        environment["WINEPREFIX"] = prefix.path
        // A parent process's Wine architecture, loader or server cannot redirect this profile.
        for key in ["WINEARCH", "WINELOADER", "WINESERVER", "WINEDLLPATH", "WINEPATH", "WINEDLLOVERRIDES"] {
            environment.removeValue(forKey: key)
        }
        if metalHUD { environment["MTL_HUD_ENABLED"] = "1" }
        var directory = base
        var arguments: [String]

        switch action {
        case .initialize:
            arguments = ["wineboot", "--init"]
        case .run, .install, .uninstall:
            let path = action == .run ? executable : installer
            let file = try WineInvocation.absolutePath(path, label: action == .run ? "Windows EXE" : "installer")
            directory = file.deletingLastPathComponent()
            switch try WindowsFile.inspect(file) {
            case .executable(let architecture) where action != .uninstall:
                guard architecture.isIntel else {
                    throw WindowsError("This engine supports x86 and x86-64 executables. The file declares \(architecture.rawValue).")
                }
                arguments = [file.path]
                if action == .run {
                    try WindowsComponents.apply(for: architecture, in: prefix, to: &environment)
                }
            case .msiContainer where action != .run:
                // Wine maps the launch working directory to a Windows drive.
                arguments = ["msiexec", action == .install ? "/i" : "/x", ".\\\(file.lastPathComponent)"]
                if silentMSI { arguments.append("/qn") }
            default:
                throw WindowsError(action == .uninstall
                    ? "Choose the original MSI to uninstall. Run an EXE uninstaller as an application."
                    : "Choose a Windows EXE to run, or an EXE or MSI to install.")
            }
        }

        try WineInvocation.preparePrefix(prefix, allowNew: action != .uninstall)
        return WineInvocation(executable: loader, arguments: arguments, directory: directory, environment: environment)
    }
}
