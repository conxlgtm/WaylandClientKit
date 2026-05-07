import Foundation
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
    case fileDescriptorAlreadyReleased
    case transferTooLarge(limit: ByteCount)
    case transferTimedOut
    case emptyDataSource
    case duplicateMIMEType(MIMEType)
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
        case .fileDescriptorAlreadyReleased:
            "file descriptor was already released"
        case .transferTooLarge(let limit):
            "transfer exceeded limit: \(limit.description)"
        case .transferTimedOut:
            "data transfer timed out"
        case .emptyDataSource:
            "data source must offer at least one MIME type"
        case .duplicateMIMEType(let mimeType):
            "duplicate MIME type in data source: \(mimeType.description)"
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
            "data source has no payload for MIME type: \(mimeType.description)"
        case .mimeTypeUnavailable(let mimeType):
            "MIME type unavailable: \(mimeType.description)"
        case .cancelled:
            "data transfer was cancelled"
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

public enum DataTransferDiagnosticOperation: Equatable, Sendable {
    case sourceWriteFailed
}

public struct DataTransferDiagnostic: Equatable, Sendable {
    public let source: ClipboardSourceIdentity
    public let mimeType: MIMEType
    public let operation: DataTransferDiagnosticOperation
    public let message: String

    public init(
        source diagnosticSource: ClipboardSourceIdentity,
        mimeType diagnosticMIMEType: MIMEType,
        operation diagnosticOperation: DataTransferDiagnosticOperation,
        message diagnosticMessage: String
    ) {
        source = diagnosticSource
        mimeType = diagnosticMIMEType
        operation = diagnosticOperation
        message = diagnosticMessage
    }
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
