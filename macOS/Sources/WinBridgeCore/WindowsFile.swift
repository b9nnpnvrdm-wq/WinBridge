import Foundation

public enum WindowsFile: Equatable {
    public enum Architecture: String, Equatable {
        case x86 = "x86 (32-bit)"
        case x64 = "x86-64"
        case arm32 = "ARM32"
        case arm64 = "ARM64"
        case arm64ec = "ARM64EC"
        case arm64x = "ARM64X"
        case unknown = "Unknown"

        public var isIntel: Bool { self == .x86 || self == .x64 }
    }

    case executable(Architecture)
    case dll(Architecture)
    case msiContainer

    public var description: String {
        switch self {
        case .executable(let architecture): return "EXE · \(architecture.rawValue)"
        case .dll(let architecture): return "DLL · \(architecture.rawValue)"
        case .msiContainer: return "MSI container · architecture checked by the installer"
        }
    }

    public static func inspect(_ url: URL) throws -> WindowsFile {
        let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
        guard attributes[.type] as? FileAttributeType == .typeRegular else {
            throw WindowsError("Choose a regular Windows file.")
        }
        let file = try FileHandle(forReadingFrom: url)
        defer { try? file.close() }
        let size = try file.seekToEnd()
        let dos = try bytes(file, at: 0, count: 64)
        if url.pathExtension.lowercased() == "msi" {
            guard size >= 512, dos.prefix(8).elementsEqual([0xD0, 0xCF, 0x11, 0xE0, 0xA1, 0xB1, 0x1A, 0xE1]) else {
                throw WindowsError("This file does not have a Windows Installer container header.")
            }
            return .msiContainer
        }
        guard dos[0] == 0x4D && dos[1] == 0x5A else {
            throw WindowsError("This file does not have a Windows executable header.")
        }
        let offset = UInt64(word(dos, 60)) | UInt64(word(dos, 62)) << 16
        guard offset >= 64, offset + 24 <= size else { throw WindowsError("Invalid PE header location.") }
        let pe = try bytes(file, at: offset, count: 24)
        guard pe.prefix(4).elementsEqual([0x50, 0x45, 0, 0]),
              word(pe, 22) & 2 != 0, word(pe, 6) > 0 else {
            throw WindowsError("This file does not contain a valid PE image header.")
        }
        let optionalSize = UInt64(word(pe, 20))
        let sections = UInt64(word(pe, 6))
        guard optionalSize >= 2, offset + 24 + optionalSize + sections * 40 <= size else {
            throw WindowsError("The PE headers are truncated.")
        }
        let magic = word(try bytes(file, at: offset + 24, count: 2), 0)
        guard (magic == 0x10B && optionalSize >= 96) || (magic == 0x20B && optionalSize >= 112) else {
            throw WindowsError("Unsupported PE optional header.")
        }

        let architecture: Architecture
        let expectedMagic: UInt16
        switch word(pe, 4) {
        case 0x014C: (architecture, expectedMagic) = (.x86, 0x10B)
        case 0x8664: (architecture, expectedMagic) = (.x64, 0x20B)
        case 0x01C0, 0x01C2, 0x01C4: (architecture, expectedMagic) = (.arm32, 0x10B)
        case 0xAA64: (architecture, expectedMagic) = (.arm64, 0x20B)
        case 0xA641: (architecture, expectedMagic) = (.arm64ec, 0x20B)
        case 0xA64E: (architecture, expectedMagic) = (.arm64x, 0x20B)
        default: (architecture, expectedMagic) = (.unknown, magic)
        }
        guard magic == expectedMagic else { throw WindowsError("The PE machine and optional header disagree.") }
        return word(pe, 22) & 0x2000 != 0 ? .dll(architecture) : .executable(architecture)
    }

    private static func bytes(_ file: FileHandle, at offset: UInt64, count: Int) throws -> [UInt8] {
        try file.seek(toOffset: offset)
        let bytes = try file.read(upToCount: count) ?? Data()
        guard bytes.count == count else { throw WindowsError("The Windows file header is truncated.") }
        return Array(bytes)
    }

    private static func word(_ bytes: [UInt8], _ offset: Int) -> UInt16 {
        UInt16(bytes[offset]) | UInt16(bytes[offset + 1]) << 8
    }
}

struct WindowsError: LocalizedError {
    let errorDescription: String?
    init(_ message: String) { errorDescription = message }
}
