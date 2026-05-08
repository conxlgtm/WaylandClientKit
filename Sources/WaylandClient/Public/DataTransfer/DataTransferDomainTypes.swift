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
    case callbackFailure(DataTransferCallbackFailureCause)
    case emptyDataSource
    case emptyDataOffer
    case duplicateMIMEType(MIMEType)
    case unavailable
    case unknownSeat(SeatID)
    case missingDataDevice(SeatID)
    case missingPrimarySelectionDevice(SeatID)
    case duplicateOffer
    case duplicateOfferHandle(rawValue: UInt, existingOffer: ClipboardOfferIdentity?)
    case duplicatePrimarySelectionOfferHandle(
        rawValue: UInt,
        existingOffer: PrimarySelectionOfferIdentity?
    )
    case duplicateSource
    case unknownOffer
    case missingOfferHandle(seatID: SeatID)
    case unknownOfferHandle(rawValue: UInt, seatID: SeatID?)
    case unknownOfferIdentity(ClipboardOfferIdentity)
    case unknownPrimarySelectionOfferIdentity(PrimarySelectionOfferIdentity)
    case mismatchedOfferSeat(
        offer: DataTransferOfferIdentity,
        expected: SeatID,
        actual: SeatID?
    )
    case offerExpired
    case unknownSource
    case unknownSourceIdentity(ClipboardSourceIdentity)
    case unknownPrimarySelectionSourceIdentity(PrimarySelectionSourceIdentity)
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
        case .callbackFailure(let cause):
            "data transfer callback failed: \(cause.description)"
        case .emptyDataSource:
            "data source must offer at least one MIME type"
        case .emptyDataOffer:
            "data offer must provide at least one MIME type before selection"
        case .duplicateMIMEType(let mimeType):
            "duplicate MIME type in data source: \(mimeType.description)"
        case .unavailable:
            "data transfer is unavailable"
        case .unknownSeat(let seatID):
            "unknown seat: \(seatID)"
        case .missingDataDevice(let seatID):
            "seat has no data device: \(seatID)"
        case .missingPrimarySelectionDevice(let seatID):
            "seat has no primary selection device: \(seatID)"
        case .duplicateOffer:
            "duplicate data offer"
        case .duplicateOfferHandle(let rawValue, let existingOffer):
            "duplicate data offer handle \(rawValue)"
                + (existingOffer.map { " for \($0.description)" } ?? "")
        case .duplicatePrimarySelectionOfferHandle(let rawValue, let existingOffer):
            "duplicate primary selection offer handle \(rawValue)"
                + (existingOffer.map { " for \($0.description)" } ?? "")
        case .duplicateSource:
            "duplicate data source"
        case .unknownOffer:
            "unknown data offer"
        case .missingOfferHandle(let seatID):
            "data offer callback for \(seatID) did not include an offer handle"
        case .unknownOfferHandle(let rawValue, let seatID):
            "unknown data offer handle \(rawValue)"
                + (seatID.map { " for \($0.description)" } ?? "")
        case .unknownOfferIdentity(let offer):
            "unknown data offer \(offer.description)"
        case .unknownPrimarySelectionOfferIdentity(let offer):
            "unknown primary selection offer \(offer.description)"
        case .mismatchedOfferSeat(let offer, let expected, let actual):
            "data offer \(offer.description) belonged to "
                + (actual?.description ?? "no seat")
                + ", expected \(expected.description)"
        case .offerExpired:
            "data offer expired"
        case .unknownSource:
            "unknown data source"
        case .unknownSourceIdentity(let source):
            "unknown data source \(source.description)"
        case .unknownPrimarySelectionSourceIdentity(let source):
            "unknown primary selection source \(source.description)"
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

public enum DataTransferCallbackFailureCause: Equatable, Sendable,
    CustomStringConvertible
{
    case backend(type: String, description: String)

    public var description: String {
        switch self {
        case .backend(let type, let description):
            "\(type): \(description)"
        }
    }
}

public enum DataTransferOfferIdentity: Equatable, Sendable, CustomStringConvertible {
    case clipboard(ClipboardOfferIdentity)
    case primarySelection(PrimarySelectionOfferIdentity)

    public var description: String {
        switch self {
        case .clipboard(let offer):
            offer.description
        case .primarySelection(let offer):
            offer.description
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

public struct PrimarySelectionOfferIdentity: Hashable, Sendable, CustomStringConvertible {
    package let rawValue: UInt64

    package init(_ offerID: DataOfferID) {
        rawValue = offerID.rawValue
    }

    public var description: String {
        "primary-selection-offer-\(rawValue)"
    }
}

public struct PrimarySelectionSourceIdentity: Hashable, Sendable, CustomStringConvertible {
    package let rawValue: UInt64

    package init(_ sourceID: DataSourceID) {
        rawValue = sourceID.rawValue
    }

    public var description: String {
        "primary-selection-source-\(rawValue)"
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

public struct PrimarySelectionEvent: Equatable, Sendable {
    public let seatID: SeatID
    public let offer: PrimarySelectionOfferIdentity?

    package init(seatID eventSeatID: SeatID, offerID: DataOfferID?) {
        seatID = eventSeatID
        offer = offerID.map(PrimarySelectionOfferIdentity.init)
    }
}

public enum DataTransferEvent: Equatable, Sendable {
    case clipboardSelectionChanged(ClipboardSelectionEvent)
    case primarySelectionChanged(PrimarySelectionEvent)
    case clipboardSourceCancelled(ClipboardSourceIdentity)
    case primarySelectionSourceCancelled(PrimarySelectionSourceIdentity)
}

public enum DataTransferDiagnosticOperation: Equatable, Sendable {
    case sourceWriteFailed
}

public enum DataTransferDiagnosticSource: Equatable, Sendable, CustomStringConvertible {
    case clipboard(ClipboardSourceIdentity)
    case primarySelection(PrimarySelectionSourceIdentity)

    public var description: String {
        switch self {
        case .clipboard(let source):
            source.description
        case .primarySelection(let source):
            source.description
        }
    }
}

public struct DataTransferDiagnostic: Equatable, Sendable {
    public let source: DataTransferDiagnosticSource
    public let mimeType: MIMEType
    public let operation: DataTransferDiagnosticOperation
    public let error: DataTransferError

    public var message: String {
        error.description
    }

    public init(
        source diagnosticSource: DataTransferDiagnosticSource,
        mimeType diagnosticMIMEType: MIMEType,
        operation diagnosticOperation: DataTransferDiagnosticOperation,
        error diagnosticError: DataTransferError
    ) {
        source = diagnosticSource
        mimeType = diagnosticMIMEType
        operation = diagnosticOperation
        error = diagnosticError
    }

    public init(
        source diagnosticSource: ClipboardSourceIdentity,
        mimeType diagnosticMIMEType: MIMEType,
        operation diagnosticOperation: DataTransferDiagnosticOperation,
        error diagnosticError: DataTransferError
    ) {
        self.init(
            source: .clipboard(diagnosticSource),
            mimeType: diagnosticMIMEType,
            operation: diagnosticOperation,
            error: diagnosticError
        )
    }

    public init(
        source diagnosticSource: PrimarySelectionSourceIdentity,
        mimeType diagnosticMIMEType: MIMEType,
        operation diagnosticOperation: DataTransferDiagnosticOperation,
        error diagnosticError: DataTransferError
    ) {
        self.init(
            source: .primarySelection(diagnosticSource),
            mimeType: diagnosticMIMEType,
            operation: diagnosticOperation,
            error: diagnosticError
        )
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
        precondition(Self.isValid(value), "MIME type must be a valid MIME token")
        rawValue = value
    }

    public var description: String {
        rawValue
    }

    private static func isValid(_ value: String) -> Bool {
        guard !value.isEmpty, value == value.trimmingCharacters(in: .whitespacesAndNewlines) else {
            return false
        }
        guard !value.unicodeScalars.contains(where: { $0.value < 0x21 || $0.value > 0x7E }) else {
            return false
        }

        let parts = value.split(separator: ";", omittingEmptySubsequences: false)
        guard let mediaType = parts.first else { return false }
        let mediaTypeParts = mediaType.split(separator: "/", omittingEmptySubsequences: false)
        guard mediaTypeParts.count == 2,
            isToken(mediaTypeParts[0]),
            isToken(mediaTypeParts[1])
        else {
            return false
        }

        for parameter in parts.dropFirst() {
            let parameterParts = parameter.split(
                separator: "=",
                maxSplits: 1,
                omittingEmptySubsequences: false
            )
            guard parameterParts.count == 2,
                isToken(parameterParts[0]),
                isToken(parameterParts[1])
            else {
                return false
            }
        }

        return true
    }

    private static func isToken(_ value: Substring) -> Bool {
        guard !value.isEmpty else { return false }

        return value.unicodeScalars.allSatisfy { scalar in
            switch scalar.value {
            case 0x30...0x39, 0x41...0x5A, 0x61...0x7A:
                true
            case 0x21, 0x23...0x27, 0x2A, 0x2B, 0x2D, 0x2E, 0x5E, 0x5F, 0x60, 0x7C, 0x7E:
                true
            default:
                false
            }
        }
    }
}

public struct ByteCount: Equatable, Comparable, Sendable, CustomStringConvertible {
    public let rawValue: Int

    public static let defaultTransferReadLimit = ByteCount(unchecked: 16 * 1_024 * 1_024)

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
