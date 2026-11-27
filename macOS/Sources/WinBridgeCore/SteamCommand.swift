import Foundation

public enum SteamCommand {
    public static func make(
        wine: String, prefix: String, windowsExecutable: String,
        installing: Bool, appID: String = "", metalHUD: Bool = false, softwareRendering: Bool = false,
        environment inherited: [String: String] = ProcessInfo.processInfo.environment
    ) throws -> WineInvocation {
        let loader = try WineInvocation.loader(wine)
        let program = try WineInvocation.absolutePath(windowsExecutable, label: "Windows executable")
        let prefix = try WineInvocation.absolutePath(prefix, label: "Steam environment")
        guard program.pathExtension.lowercased() == "exe",
              (try? program.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile) == true else {
            throw WindowsError("Choose an existing Windows .exe file.")
        }

        try WineInvocation.preparePrefix(prefix, allowNew: installing)

        var arguments = [program.path]
        if !installing && softwareRendering {
            arguments += ["-cef-disable-gpu", "-cef-disable-gpu-compositing"]
        }
        let appID = appID.trimmingCharacters(in: .whitespacesAndNewlines)
        if !installing && !appID.isEmpty {
            guard appID.utf8.count <= 10,
                  appID.utf8.allSatisfy({ (48...57).contains($0) }),
                  let number = UInt32(appID), number > 0 else {
                throw WindowsError("Enter a numeric Steam App ID, for example 271590.")
            }
            arguments += ["-applaunch", String(number)]
        }
        var environment = inherited
        environment["WINEPREFIX"] = prefix.path
        if metalHUD { environment["MTL_HUD_ENABLED"] = "1" }
        return WineInvocation(
            executable: loader, arguments: arguments,
            directory: program.deletingLastPathComponent(), environment: environment
        )
    }

    public static func quit(wine: String, prefix: String, client: String) throws -> WineInvocation {
        let launch = try make(wine: wine, prefix: prefix, windowsExecutable: client, installing: false)
        return WineInvocation(
            executable: launch.executable, arguments: launch.arguments + ["-shutdown"],
            directory: launch.directory, environment: launch.environment
        )
    }

    public static func repair(
        wine: String, prefix: String,
        environment inherited: [String: String] = ProcessInfo.processInfo.environment
    ) throws -> WineInvocation {
        let loader = try WineInvocation.loader(wine)
        let prefix = try WineInvocation.absolutePath(prefix, label: "Steam environment")
        try WineInvocation.preparePrefix(prefix, allowNew: false)
        let files = FileManager.default
        let backup = prefix.appendingPathComponent("WinBridge Registry Backups")
            .appendingPathComponent(UUID().uuidString)
        try files.createDirectory(at: backup, withIntermediateDirectories: true)
        for name in ["system.reg", "user.reg", "userdef.reg"] {
            let source = prefix.appendingPathComponent(name)
            if (try? source.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile) == true {
                try files.copyItem(at: source, to: backup.appendingPathComponent(name))
            }
        }
        var environment = inherited
        environment["WINEPREFIX"] = prefix.path
        return WineInvocation(
            executable: loader, arguments: ["wineboot", "--update"],
            directory: prefix, environment: environment
        )
    }
}
