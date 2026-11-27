import Foundation

public struct ApplicationLibrary {
    public let directory: URL

    public init(directory: URL) {
        self.directory = directory
    }

    private var catalog: URL { directory.appendingPathComponent("Applications.json") }
    public var defaultStorage: URL { directory.appendingPathComponent("Environments", isDirectory: true) }

    public func load() throws -> [WindowsApplication] {
        do {
            return try JSONDecoder().decode([WindowsApplication].self, from: Data(contentsOf: catalog))
        } catch let error as NSError where error.domain == NSCocoaErrorDomain
            && error.code == NSFileReadNoSuchFileError {
            return []
        }
    }

    public func save(_ profiles: [WindowsApplication]) throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try JSONEncoder().encode(profiles).write(to: catalog, options: [.atomic])
    }

    public func profile(forExecutable url: URL, in profiles: [WindowsApplication]) throws -> WindowsApplication {
        guard url.isFileURL, url.pathExtension.lowercased() == "exe" else {
            throw WindowsError("Choose a Windows .exe file.")
        }
        let file = url.standardizedFileURL.resolvingSymlinksInPath()
        guard case .executable = try WindowsFile.inspect(file) else {
            throw WindowsError("Choose an executable PE image.")
        }
        if let existing = profiles.first(where: {
            guard $0.executable.hasPrefix("/") else { return false }
            return URL(fileURLWithPath: $0.executable).standardizedFileURL.resolvingSymlinksInPath().path == file.path
        }) { return existing }
        var profile = try makeApplication()
        profile.name = url.deletingPathExtension().lastPathComponent
        profile.executable = file.path
        return profile
    }

    public func makeApplication() throws -> WindowsApplication {
        try FileManager.default.createDirectory(at: defaultStorage, withIntermediateDirectories: true)
        return WindowsApplication(name: "New Windows App", location: defaultStorage)
    }
}
