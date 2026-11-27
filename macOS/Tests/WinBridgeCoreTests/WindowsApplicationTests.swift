import Foundation
import XCTest
@testable import WinBridgeCore

final class WindowsApplicationTests: XCTestCase {
    func testCatalogPersistsDistinctProfiles() throws {
        let root = try temporaryDirectory()
        let library = ApplicationLibrary(directory: root)
        XCTAssertEqual(try library.load(), [])
        var first = try library.makeApplication()
        first.name = "First profile"
        first.executable = "/fixtures/file.exe"
        let second = try library.makeApplication()
        try library.save([first, second])
        XCTAssertEqual(try library.load(), [first, second])
        XCTAssertNotEqual(first.prefix, second.prefix)
    }

    func testInspectArchitecturesAndRejectMalformedPE() throws {
        let root = try temporaryDirectory()
        let file = root.appendingPathComponent("app.exe")
        for (machine, architecture, optionalSize) in [
            (0x014C, WindowsFile.Architecture.x86, 96), (0x8664, .x64, 112),
            (0x01C4, .arm32, 96), (0xAA64, .arm64, 112),
            (0xA641, .arm64ec, 112), (0xA64E, .arm64x, 112),
        ] {
            try image(machine: machine, optionalSize: optionalSize).write(to: file)
            XCTAssertEqual(try WindowsFile.inspect(file), .executable(architecture))
        }
        try image(machine: 0x8664, optionalSize: 96).write(to: file)
        XCTAssertThrowsError(try WindowsFile.inspect(file))
        try Data("Not a Windows file".utf8).write(to: file)
        XCTAssertThrowsError(try WindowsFile.inspect(file))
    }

    func testPlanRejectsARMAndUsesProfileLocalWineEnvironment() throws {
        let root = try temporaryDirectory()
        let file = root.appendingPathComponent("app.exe")
        var profile = WindowsApplication(name: "Test", location: root)
        profile.executable = file.path
        try image(machine: 0xAA64, optionalSize: 112).write(to: file)
        XCTAssertThrowsError(try profile.command(.run, bundledWine: "/usr/bin/true"))
        try image(machine: 0x014C, optionalSize: 96).write(to: file)
        let plan = try profile.command(.run, bundledWine: "/usr/bin/true", environment: [
            "WINEPREFIX": "/bad", "WINEARCH": "win32", "WINEPATH": "Z:\\unexpected"
        ])
        XCTAssertEqual(plan.arguments, [file.path])
        XCTAssertEqual(plan.environment["WINEPREFIX"], profile.prefix.path)
        XCTAssertNil(plan.environment["WINEARCH"])
        XCTAssertNil(plan.environment["WINEPATH"])
    }

    func testRealWindowsRuntimeFixtures() throws {
        let environment = ProcessInfo.processInfo.environment
        let wine = try XCTUnwrapOrSkip(environment["WINBRIDGE_TEST_WINE"], "Run with a packaged Wine engine")
        let fixturePath = try XCTUnwrap(environment["WINBRIDGE_TEST_FIXTURES"])
        let fixtures = URL(fileURLWithPath: fixturePath)
        let root = try temporaryDirectory()
        var profile = WindowsApplication(name: "Windows fixtures", location: root)
        profile.executable = fixtures.appendingPathComponent("app/fixture.exe").path
        profile.installer = fixtures.appendingPathComponent("fixture.msi").path
        let other = WindowsApplication(name: "Isolated", location: root)

        func execute(_ action: WindowsApplication.Action) throws -> Int32 {
            let plan = try profile.command(action, bundledWine: wine, silentMSI: true)
            let process = plan.makeProcess()
            var environment = plan.environment
            let extras = environment["WINEDLLOVERRIDES"].map { ";\($0)" } ?? ""
            environment["WINEDLLOVERRIDES"] = "mscoree,mshtml=\(extras)"
            environment["WINEDEBUG"] = "-all"
            process.environment = environment
            try process.run()
            process.waitUntilExit()
            return process.terminationStatus
        }

        XCTAssertEqual(try execute(.initialize), 0)
        XCTAssertTrue(profile.isInitialized)
        XCTAssertFalse(other.isInitialized)
        XCTAssertNotEqual(try execute(.run), 0, "The fixture must fail before its DLL is installed")
        try WindowsComponents.importDLL(fixtures.appendingPathComponent("components/WinBridgeFixture.dll"), into: profile)
        XCTAssertEqual(try execute(.run), 0)

        XCTAssertEqual(try execute(.install), 0)
        let installed = ["Program Files", "Program Files (x86)"].map { dir in
            profile.prefix.appendingPathComponent("drive_c/\(dir)/WinBridge Fixture/fixture.txt")
        }
        XCTAssertTrue(installed.contains { FileManager.default.fileExists(atPath: $0.path) })
        XCTAssertEqual(try execute(.uninstall), 0)
        XCTAssertFalse(installed.contains { FileManager.default.fileExists(atPath: $0.path) })
    }

    private func temporaryDirectory() throws -> URL {
        let root = FileManager.default.temporaryDirectory.resolvingSymlinksInPath()
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        addTeardownBlock { try FileManager.default.removeItem(at: root) }
        return root
    }

    private func image(machine: Int, optionalSize: Int) -> Data {
        var bytes = [UInt8](repeating: 0, count: 64 + 24 + optionalSize + 40)
        func write(_ value: Int, at offset: Int) {
            bytes[offset] = UInt8(value & 255)
            bytes[offset + 1] = UInt8(value >> 8)
        }
        write(0x5A4D, at: 0)
        write(64, at: 60)
        write(0x4550, at: 64)
        write(machine, at: 68)
        write(1, at: 70)
        write(optionalSize, at: 84)
        write(2, at: 86)
        write(optionalSize == 96 ? 0x10B : 0x20B, at: 88)
        return Data(bytes)
    }

    private func XCTUnwrapOrSkip<T>(_ value: T?, _ reason: String) throws -> T {
        guard let value else { throw XCTSkip(reason) }
        return value
    }
}
