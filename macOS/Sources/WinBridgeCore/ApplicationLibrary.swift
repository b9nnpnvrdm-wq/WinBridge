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

    public func makeApplication() throws -> WindowsApplication {
        try FileManager.default.createDirectory(at: defaultStorage, withIntermediateDirectories: true)
        return WindowsApplication(name: "New Windows App", location: defaultStorage)
    }
}
