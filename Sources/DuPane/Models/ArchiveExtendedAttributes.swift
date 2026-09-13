import Darwin
import Foundation

struct ArchiveExtendedAttributeRecord: Codable, Equatable {
    let path: String
    let name: String
    let value: Data
}

struct ArchiveMetadataManifest: Codable, Equatable {
    static let version = 1
    let version: Int
    let extendedAttributes: [ArchiveExtendedAttributeRecord]
}

enum ArchiveExtendedAttributeStore {
    static func records(for url: URL, archivePath: String) throws -> [ArchiveExtendedAttributeRecord] {
        let names = try names(at: url)
        return try names.map { name in
            ArchiveExtendedAttributeRecord(
                path: archivePath,
                name: name,
                value: try value(at: url, name: name)
            )
        }
    }

    static func apply(_ records: [ArchiveExtendedAttributeRecord], to rootURL: URL) throws {
        for record in records {
            let itemURL = rootURL.appendingPathComponent(record.path)
            try setValue(record.value, at: itemURL, name: record.name)
        }
    }

    private static func names(at url: URL) throws -> [String] {
        let size = try url.path.withCString { path in
            let result = listxattr(path, nil, 0, XATTR_NOFOLLOW)
            guard result >= 0 else { throw currentPOSIXError() }
            return result
        }
        guard size > 0 else { return [] }

        var buffer = [CChar](repeating: 0, count: size)
        let count = try url.path.withCString { path in
            let result = listxattr(path, &buffer, buffer.count, XATTR_NOFOLLOW)
            guard result >= 0 else { throw currentPOSIXError() }
            return result
        }
        return Data(bytes: buffer, count: count)
            .split(separator: 0)
            .compactMap { String(bytes: $0, encoding: .utf8) }
            .sorted()
    }

    private static func value(at url: URL, name: String) throws -> Data {
        let size = try url.path.withCString { path in
            try name.withCString { attributeName in
                let result = getxattr(path, attributeName, nil, 0, 0, XATTR_NOFOLLOW)
                guard result >= 0 else { throw currentPOSIXError() }
                return result
            }
        }
        guard size > 0 else { return Data() }

        var data = Data(count: size)
        let count = try data.withUnsafeMutableBytes { buffer in
            try url.path.withCString { path in
                try name.withCString { attributeName in
                    let result = getxattr(path, attributeName, buffer.baseAddress, size, 0, XATTR_NOFOLLOW)
                    guard result >= 0 else { throw currentPOSIXError() }
                    return result
                }
            }
        }
        data.count = count
        return data
    }

    private static func setValue(_ value: Data, at url: URL, name: String) throws {
        let result = value.withUnsafeBytes { buffer in
            url.path.withCString { path in
                name.withCString { attributeName in
                    setxattr(path, attributeName, buffer.baseAddress, value.count, 0, XATTR_NOFOLLOW)
                }
            }
        }
        guard result == 0 else { throw currentPOSIXError() }
    }

    private static func currentPOSIXError() -> POSIXError {
        POSIXError(POSIXError.Code(rawValue: errno) ?? .EIO)
    }
}
