import Foundation

public enum WindowsComponents {
    private static func subfolder(_ architecture: WindowsFile.Architecture) -> String {
        architecture == .x86 ? "x86" : "x64"
    }

    private static func folder(_ architecture: WindowsFile.Architecture, in prefix: URL) -> URL {
        prefix.appendingPathComponent("drive_c/WinBridge/Dependencies")
            .appendingPathComponent(subfolder(architecture), isDirectory: true)
    }

    public static func importDLL(_ source: URL, into application: WindowsApplication) throws {
        guard !((try? application.prefix.resourceValues(forKeys: [.isSymbolicLinkKey]).isSymbolicLink) ?? false) else {
            throw WindowsError("The Windows environment folder is a symbolic link.")
        }
        try WineInvocation.preparePrefix(application.prefix, allowNew: false)
        guard case .dll(let architecture) = try WindowsFile.inspect(source), architecture.isIntel,
              isDLLName(source.lastPathComponent) else {
            throw WindowsError("Choose a 32-bit or 64-bit Windows DLL with a standard filename.")
        }
        let destination = folder(architecture, in: application.prefix)
        try requireLocalFolder(destination, in: application.prefix)
        let files = FileManager.default
        try files.createDirectory(at: destination, withIntermediateDirectories: true)
        let name = source.lastPathComponent.lowercased()
        guard try !files.contentsOfDirectory(atPath: destination.path)
            .contains(where: { $0.lowercased() == name }) else {
            throw WindowsError("A DLL with this name is already installed for this architecture.")
        }
        try files.copyItem(at: source.resolvingSymlinksInPath(), to: destination.appendingPathComponent(name))
    }

    static func apply(
        for architecture: WindowsFile.Architecture, in prefix: URL, to environment: inout [String: String]
    ) throws {
        let folder = folder(architecture, in: prefix)
        let files = FileManager.default
        try requireLocalFolder(folder, in: prefix)
        guard files.fileExists(atPath: folder.path) else { return }
        let entries = try files.contentsOfDirectory(at: folder, includingPropertiesForKeys: [.isSymbolicLinkKey])
        let dlls = try entries.filter { file in
            guard isDLLName(file.lastPathComponent) else { return false }
            guard try file.resourceValues(forKeys: [.isSymbolicLinkKey]).isSymbolicLink != true,
                  try WindowsFile.inspect(file) == .dll(architecture) else {
                throw WindowsError("Invalid compatibility component: \(file.lastPathComponent)")
            }
            return true
        }
        guard !dlls.isEmpty else { return }
        environment["WINEPATH"] = "C:\\WinBridge\\Dependencies\\\(subfolder(architecture))"
        environment["WINEDLLOVERRIDES"] = dlls.map { "\($0.deletingPathExtension().lastPathComponent)=n,b" }
            .sorted().joined(separator: ";")
    }

    private static func requireLocalFolder(_ folder: URL, in prefix: URL) throws {
        let root = prefix.resolvingSymlinksInPath().path + "/"
        guard folder.resolvingSymlinksInPath().path.hasPrefix(root) else {
            throw WindowsError("The DLL storage directory resolves outside this Windows environment.")
        }
    }

    private static func isDLLName(_ name: String) -> Bool {
        name.lowercased().hasSuffix(".dll") && name.count > 4 && name.utf8.allSatisfy {
            (48...57).contains($0) || (65...90).contains($0) || (97...122).contains($0) || [45, 46, 95].contains($0)
        }
    }
}
