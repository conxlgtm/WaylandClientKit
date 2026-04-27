import Glibc

package struct ThreadAffinity {
    private let owner: pthread_t

    package init(owner ownerThread: pthread_t = pthread_self()) {
        owner = ownerThread
    }

    package func preconditionIsOwnerThread(
        _ operation: StaticString = #function,
        file: StaticString = #fileID,
        line: UInt = #line
    ) {
        precondition(
            pthread_equal(owner, pthread_self()) != 0,
            "Thread-affine object used from a different thread during \(operation)",
            file: file,
            line: line
        )
    }
}
