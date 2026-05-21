import Foundation
import Glibc

public enum TemporaryFileDescriptorError: Error, Equatable, Sendable {
    case missingTemplateStorage
    case createFailed(errno: Int32)
    case writeFailed(expected: Int, actual: Int)
    case rewindFailed(errno: Int32)
}

public func makeTemporaryFileDescriptor(
    prefix: String,
    bytes: [UInt8]
) throws -> Int32 {
    let directory = FileManager.default.temporaryDirectory.path
    var template = Array("\(directory)/\(prefix)-XXXXXX".utf8CString)
    let descriptor = unsafe template.withUnsafeMutableBufferPointer { buffer in
        guard let baseAddress = buffer.baseAddress else {
            return Int32(-1)
        }

        return unsafe mkstemp(baseAddress)
    }
    guard descriptor >= 0 else {
        throw TemporaryFileDescriptorError.createFailed(errno: errno)
    }

    unsafe template.withUnsafeBufferPointer { buffer in
        if let baseAddress = buffer.baseAddress {
            unsafe unlink(baseAddress)
        }
    }

    let writeResult = unsafe bytes.withUnsafeBytes { rawBytes in
        unsafe write(descriptor, rawBytes.baseAddress, bytes.count)
    }
    guard writeResult == bytes.count else {
        throw TemporaryFileDescriptorError.writeFailed(
            expected: bytes.count,
            actual: writeResult
        )
    }
    guard lseek(descriptor, 0, SEEK_SET) == 0 else {
        throw TemporaryFileDescriptorError.rewindFailed(errno: errno)
    }

    return descriptor
}
