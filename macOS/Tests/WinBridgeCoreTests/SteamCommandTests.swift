import Foundation
import XCTest
@testable import WinBridgeCore

final class SteamCommandTests: XCTestCase {
    func testLaunchBuildsExplicitArgumentVectorAndPrefix() throws {
        let fixture = try makeFixture()
        let command = try SteamCommand.make(
            wine: fixture.wine.path, prefix: fixture.prefix.path,
            windowsExecutable: fixture.steam.path,
            installing: false, appID: " 00271590 ", metalHUD: true,
            environment: ["WINEPREFIX": "/previous", "PATH": "/usr/bin"]
        )
        XCTAssertEqual(command.executable.path, fixture.wine.path)
        XCTAssertEqual(command.arguments, [fixture.steam.path, "-applaunch", "271590"])
        XCTAssertEqual(command.directory.path, fixture.steam.deletingLastPathComponent().path)
        XCTAssertEqual(command.environment["WINEPREFIX"], fixture.prefix.path)
        XCTAssertEqual(command.environment["MTL_HUD_ENABLED"], "1")
        XCTAssertEqual(command.environment["PATH"], "/usr/bin")
    }

    func testSteamSoftwareRenderingIsOptionalAndSkipsInstaller() throws {
        let fixture = try makeFixture()
        let open = try SteamCommand.make(
            wine: fixture.wine.path, prefix: fixture.prefix.path,
            windowsExecutable: fixture.steam.path, installing: false, appID: "271590",
            softwareRendering: true
        )
        XCTAssertEqual(open.arguments, [fixture.steam.path, "-cef-disable-gpu", "-applaunch", "271590"])
        let install = try SteamCommand.make(
            wine: fixture.wine.path, prefix: fixture.prefix.path,
            windowsExecutable: fixture.steam.path, installing: true, softwareRendering: true
        )
        XCTAssertEqual(install.arguments, [fixture.steam.path])
    }

    func testLaunchRejectsInvalidAppIDAndUninitializedPrefix() throws {
        let fixture = try makeFixture()
        XCTAssertThrowsError(try SteamCommand.make(
            wine: fixture.wine.path, prefix: fixture.prefix.path,
            windowsExecutable: fixture.steam.path, installing: false, appID: "3 -extra"
        ))
        try FileManager.default.removeItem(at: fixture.prefix.appendingPathComponent("system.reg"))
        XCTAssertThrowsError(try SteamCommand.make(
            wine: fixture.wine.path, prefix: fixture.prefix.path,
            windowsExecutable: fixture.steam.path, installing: false
        ))
    }

    func testInstallAllowsNewPrefixAndCreatesParentDirectory() throws {
        let fixture = try makeFixture()
        let prefix = fixture.prefix.appendingPathComponent("Other location/Steam")
        let command = try SteamCommand.make(
            wine: fixture.wine.path, prefix: prefix.path,
            windowsExecutable: fixture.steam.path, installing: true
        )
        XCTAssertEqual(command.arguments, [fixture.steam.path])
        XCTAssertTrue(FileManager.default.fileExists(atPath: prefix.deletingLastPathComponent().path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: prefix.path))
    }

    private func makeFixture() throws -> (wine: URL, prefix: URL, steam: URL) {
        let root = FileManager.default.temporaryDirectory
            .resolvingSymlinksInPath().appendingPathComponent(UUID().uuidString)
        let prefix = root.appendingPathComponent("Steam Prefix")
        let drive = prefix.appendingPathComponent("drive_c")
        try FileManager.default.createDirectory(at: drive, withIntermediateDirectories: true)
        addTeardownBlock { try FileManager.default.removeItem(at: root) }
        let wine = root.appendingPathComponent("Wine Loader")
        let steam = drive.appendingPathComponent("Steam.exe")
        try Data().write(to: wine)
        try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: wine.path)
        try Data().write(to: steam)
        try Data().write(to: prefix.appendingPathComponent("system.reg"))
        return (wine, prefix, steam)
    }
}
