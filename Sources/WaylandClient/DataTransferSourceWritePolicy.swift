import Glibc

package struct DataTransferSourceWritePolicy: Equatable, Sendable {
    package static let `default` = DataTransferSourceWritePolicy()

    package let maximumTemporaryWriteFailures: Int
    package let retryDelayMicroseconds: useconds_t

    package init(
        maximumTemporaryWriteFailures temporaryWriteFailureLimit: Int = 10_000,
        retryDelayMicroseconds retryDelay: useconds_t = 1_000
    ) {
        precondition(
            temporaryWriteFailureLimit >= 0,
            "temporary write failure limit must be non-negative"
        )

        maximumTemporaryWriteFailures = temporaryWriteFailureLimit
        retryDelayMicroseconds = retryDelay
    }
}
