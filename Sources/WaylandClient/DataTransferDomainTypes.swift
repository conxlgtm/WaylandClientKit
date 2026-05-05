import Foundation
import Glibc
import WaylandRaw

public enum DataTransferError: Error, Equatable, Sendable, CustomStringConvertible {
    case invalidMIMEType(String)
    case negativeByteCount(Int)
    case byteCountOverflow(value: Int, multiplier: Int)
    case invalidFileDescriptor(Int32)
    case createPipe(WaylandSystemErrno)
    case readFileDescriptor(WaylandSystemErrno)
    case writeFileDescriptor(WaylandSystemErrno)
    case closeFileDescriptor(WaylandSystemErrno)
    case transferTooLarge(limit: ByteCount)
    case unavailable
    case unknownSeat(SeatID)
    case missingDataDevice(SeatID)
    case duplicateOffer
    case duplicateSource
    case unknownOffer
    case offerExpired
    case unknownSource
    case sourceCancelled
    case sourceDataUnavailable(MIMEType)
    case mimeTypeUnavailable(MIMEType)
    case cancelled
    case invalidSerial(seatID: SeatID, serial: InputSerial)

    public var description: String {
        switch self {
        case .invalidMIMEType(let value):
            "invalid MIME type: \(value)"
        case .negativeByteCount(let value):
            "negative byte count: \(value)"
        case .byteCountOverflow(let value, let multiplier):
            "byte count overflow: \(value) * \(multiplier)"
        case .invalidFileDescriptor(let descriptor):
            "invalid file descriptor: \(descriptor)"
        case .createPipe(let error):
            "create pipe failed: \(error.description)"
        case .readFileDescriptor(let error):
            "read file descriptor failed: \(error.description)"
        case .writeFileDescriptor(let error):
            "write file descriptor failed: \(error.description)"
        case .closeFileDescriptor(let error):
            "close file descriptor failed: \(error.description)"
        case .transferTooLarge(let limit):
            "transfer exceeded limit: \(limit.description)"
        case .unavailable:
            "data transfer is unavailable"
        case .unknownSeat(let seatID):
            "unknown seat: \(seatID)"
        case .missingDataDevice(let seatID):
            "seat has no data device: \(seatID)"
        case .duplicateOffer:
            "duplicate data offer"
        case .duplicateSource:
            "duplicate data source"
        case .unknownOffer:
            "unknown data offer"
        case .offerExpired:
            "data offer expired"
        case .unknownSource:
            "unknown data source"
        case .sourceCancelled:
            "data source was cancelled"
        case .sourceDataUnavailable(let mimeType):
            "data source has no provider for MIME type: \(mimeType.description)"
        case .mimeTypeUnavailable(let mimeType):
            "MIME type unavailable: \(mimeType.description)"
        case .cancelled:
            "data transfer was cancelled"
        case .invalidSerial(let seatID, let serial):
            "invalid input serial \(serial) for seat \(seatID)"
        }
    }
}

public struct ClipboardOfferIdentity: Hashable, Sendable, CustomStringConvertible {
    package let rawValue: UInt64

    package init(_ offerID: DataOfferID) {
        rawValue = offerID.rawValue
    }

    public var description: String {
        "clipboard-offer-\(rawValue)"
    }
}

public struct ClipboardSourceIdentity: Hashable, Sendable, CustomStringConvertible {
    package let rawValue: UInt64

    package init(_ sourceID: DataSourceID) {
        rawValue = sourceID.rawValue
    }

    public var description: String {
        "clipboard-source-\(rawValue)"
    }
}

public struct ClipboardSelectionEvent: Equatable, Sendable {
    public let seatID: SeatID
    public let offer: ClipboardOfferIdentity?

    package init(seatID eventSeatID: SeatID, offerID: DataOfferID?) {
        seatID = eventSeatID
        offer = offerID.map(ClipboardOfferIdentity.init)
    }
}

public enum DataTransferEvent: Equatable, Sendable {
    case selectionChanged(ClipboardSelectionEvent)
    case sourceCancelled(ClipboardSourceIdentity)
}

public struct MIMEType: RawRepresentable, Equatable, Hashable, Sendable,
    CustomStringConvertible
{
    public let rawValue: String

    public static let plainText = MIMEType(unchecked: "text/plain")
    public static let plainTextUTF8 = MIMEType(unchecked: "text/plain;charset=utf-8")
    public static let uriList = MIMEType(unchecked: "text/uri-list")

    public init(_ value: String) throws {
        guard Self.isValid(value) else {
            throw DataTransferError.invalidMIMEType(value)
        }

        rawValue = value
    }

    public init?(rawValue value: String) {
        guard Self.isValid(value) else {
            return nil
        }

        rawValue = value
    }

    package init(unchecked value: String) {
        precondition(Self.isValid(value), "MIME type must be non-empty and NUL-free")
        rawValue = value
    }

    public var description: String {
        rawValue
    }

    private static func isValid(_ value: String) -> Bool {
        !value.isEmpty && !value.contains("\0")
    }
}

public struct ByteCount: Equatable, Comparable, Sendable, CustomStringConvertible {
    public let rawValue: Int

    public static let defaultClipboardReadLimit = ByteCount(unchecked: 16 * 1_024 * 1_024)

    public init(_ value: Int) throws {
        guard value >= 0 else {
            throw DataTransferError.negativeByteCount(value)
        }

        rawValue = value
    }

    public static func bytes(_ value: Int) throws -> ByteCount {
        try ByteCount(value)
    }

    public static func kilobytes(_ value: Int) throws -> ByteCount {
        try scaled(value, by: 1_024)
    }

    public static func megabytes(_ value: Int) throws -> ByteCount {
        try scaled(value, by: 1_024 * 1_024)
    }

    package init(unchecked value: Int) {
        precondition(value >= 0, "byte count must be non-negative")
        rawValue = value
    }

    public var description: String {
        "\(rawValue) bytes"
    }

    public static func < (lhs: ByteCount, rhs: ByteCount) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    private static func scaled(_ value: Int, by multiplier: Int) throws -> ByteCount {
        let product = value.multipliedReportingOverflow(by: multiplier)
        guard !product.overflow else {
            throw DataTransferError.byteCountOverflow(value: value, multiplier: multiplier)
        }

        return try ByteCount(product.partialValue)
    }
}

public struct OwnedFileDescriptor: ~Copyable, Sendable {
    private static let readChunkByteCount = 16 * 1_024

    private var storage: Int32?
    private let readDescriptor: @Sendable (Int32, Int) throws -> [UInt8]
    private let writeDescriptor: @Sendable (Int32, [UInt8]) throws -> Int
    private let closeDescriptor: @Sendable (Int32) -> Int32

    public init(adopting rawValue: Int32) throws {
        try self.init(
            adopting: rawValue,
            readDescriptor: Self.defaultReadDescriptor,
            writeDescriptor: Self.defaultWriteDescriptor,
            closeDescriptor: Self.defaultCloseDescriptor
        )
    }

    package init(
        adopting rawValue: Int32,
        readDescriptor read: @escaping @Sendable (Int32, Int) throws -> [UInt8] =
            Self.defaultReadDescriptor,
        writeDescriptor write: @escaping @Sendable (Int32, [UInt8]) throws -> Int =
            Self.defaultWriteDescriptor,
        closeDescriptor close: @escaping @Sendable (Int32) -> Int32
    ) throws {
        guard rawValue >= 0 else {
            throw DataTransferError.invalidFileDescriptor(rawValue)
        }

        storage = rawValue
        readDescriptor = read
        writeDescriptor = write
        closeDescriptor = close
    }

    public var rawValue: Int32 {
        guard let storage else {
            preconditionFailure("file descriptor was already closed or released")
        }

        return storage
    }

    public var isClosed: Bool {
        storage == nil
    }

    public var description: String {
        guard let storage else {
            return "closed file descriptor"
        }

        return "file descriptor \(storage)"
    }

    public mutating func readData(
        limit: ByteCount = .defaultClipboardReadLimit
    ) throws -> Data {
        let data: Data
        do {
            data = try readDataWithoutClosing(limit: limit)
        } catch {
            do {
                try close()
            } catch {
                _ = error
            }
            throw error
        }

        try close()
        return data
    }

    public mutating func writeData(_ data: Data) throws {
        do {
            try writeDataWithoutClosing(data)
        } catch {
            do {
                try close()
            } catch {
                _ = error
            }
            throw error
        }

        try close()
    }

    public mutating func close() throws {
        guard let descriptor = storage else {
            return
        }

        let closeErrno = closeDescriptor(descriptor)
        guard closeErrno == 0 else {
            throw DataTransferError.closeFileDescriptor(
                WaylandSystemErrno(unchecked: Self.normalizeErrno(closeErrno))
            )
        }

        storage = nil
    }

    public mutating func releaseRawValue() -> Int32 {
        guard let descriptor = storage else {
            preconditionFailure("file descriptor was already closed or released")
        }

        storage = nil
        return descriptor
    }

    private mutating func readDataWithoutClosing(limit: ByteCount) throws -> Data {
        var data = Data()

        while true {
            let remainingByteCount = limit.rawValue - data.count
            let readByteCount = Self.nextReadByteCount(remainingByteCount)
            let bytes = try readDescriptor(rawValue, readByteCount)
            guard !bytes.isEmpty else {
                return data
            }
            guard bytes.count <= remainingByteCount else {
                throw DataTransferError.transferTooLarge(limit: limit)
            }

            data.append(contentsOf: bytes)
        }
    }

    private static func nextReadByteCount(_ remainingByteCount: Int) -> Int {
        let byteCountIncludingOverflowProbe =
            if remainingByteCount == Int.max {
                remainingByteCount
            } else {
                remainingByteCount + 1
            }

        return max(1, min(readChunkByteCount, byteCountIncludingOverflowProbe))
    }

    private func writeDataWithoutClosing(_ data: Data) throws {
        let bytes = Array(data)
        var writtenByteCount = 0

        while writtenByteCount < bytes.count {
            let remainingBytes = Array(bytes[writtenByteCount...])
            let count = try writeDescriptor(rawValue, remainingBytes)
            guard count > 0, count <= remainingBytes.count else {
                throw DataTransferError.writeFileDescriptor(
                    WaylandSystemErrno(unchecked: EIO)
                )
            }

            writtenByteCount += count
        }
    }

    private static func defaultReadDescriptor(
        _ descriptor: Int32,
        maximumByteCount: Int
    ) throws -> [UInt8] {
        do {
            return try RawFileDescriptor.read(
                descriptor: descriptor,
                maximumByteCount: maximumByteCount
            )
        } catch {
            throw dataTransferReadError(error)
        }
    }

    private static func dataTransferReadError(_ error: RuntimeError) -> DataTransferError {
        switch error {
        case .system(let systemError):
            .readFileDescriptor(WaylandSystemErrno(unchecked: systemError.errno.rawValue))
        case .systemErrnoUnavailable:
            .readFileDescriptor(WaylandSystemErrno(unchecked: EIO))
        default:
            .unavailable
        }
    }

    private static func defaultWriteDescriptor(
        _ descriptor: Int32,
        bytes: [UInt8]
    ) throws -> Int {
        do {
            return try RawFileDescriptor.write(descriptor: descriptor, bytes: bytes)
        } catch {
            throw dataTransferWriteError(error)
        }
    }

    private static func dataTransferWriteError(_ error: RuntimeError) -> DataTransferError {
        switch error {
        case .system(let systemError):
            .writeFileDescriptor(WaylandSystemErrno(unchecked: systemError.errno.rawValue))
        case .systemErrnoUnavailable:
            .writeFileDescriptor(WaylandSystemErrno(unchecked: EIO))
        default:
            .unavailable
        }
    }

    deinit {
        if let storage {
            _ = closeDescriptor(storage)
        }
    }

    private static func defaultCloseDescriptor(_ descriptor: Int32) -> Int32 {
        guard Glibc.close(descriptor) == 0 else {
            return normalizeErrno(errno)
        }

        return 0
    }

    private static func normalizeErrno(_ value: Int32) -> Int32 {
        value > 0 ? value : EIO
    }
}
