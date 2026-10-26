import Glibc
import Synchronization
import Testing
import WaylandClient
import WaylandGraphicsPreview
import WaylandRaw

final class PlaneDescriptorProbe: Sendable {
    private let pipes: [(readEnd: Int32, writeEnd: Int32)]
    private let closeCounts: Mutex<[Int]>

    init(count: Int) throws {
        var pipes: [(Int32, Int32)] = []
        do {
            for _ in 0..<count {
                pipes.append(try RawFileDescriptor.pipeDescriptors())
            }
        } catch {
            for (readEnd, writeEnd) in pipes {
                Glibc.close(readEnd)
                Glibc.close(writeEnd)
            }
            throw error
        }
        self.pipes = pipes
        closeCounts = Mutex(Array(repeating: 0, count: count))
    }

    var ownerCloseCounts: [Int] {
        closeCounts.withLock { $0 }
    }

    func descriptor() throws -> WaylandGraphicsExternalBufferDescriptor {
        try WaylandGraphicsExternalBufferDescriptor(
            size: PositivePixelSize(width: 4, height: 4),
            format: .xrgb8888, modifier: .linear, planes: planes())
    }

    func planes() throws -> WaylandGraphicsExternalBufferPlanes {
        switch pipes.count {
        case 1: return try .one(plane(0))
        case 2: return try .two(plane(0), plane(1))
        case 3: return try .three(plane(0), plane(1), plane(2))
        default: return try .four(plane(0), plane(1), plane(2), plane(3))
        }
    }

    private func plane(_ index: Int) throws -> WaylandGraphicsExternalBufferPlane {
        let descriptor = try ownedDescriptor(at: index)
        return try WaylandGraphicsExternalBufferPlane(
            fileDescriptor: descriptor, offset: UInt32(index * 64), stride: 16,
            planeIndex: UInt32(index)
        )
    }

    func ownedDescriptor(at index: Int) throws -> OwnedFileDescriptor {
        try OwnedFileDescriptor(adopting: pipes[index].writeEnd) { [self] fd in
            closeCounts.withLock { $0[index] += 1 }
            return Glibc.close(fd)
        }
    }

    func expectEOF() throws {
        for pipe in pipes {
            var event = pollfd(fd: pipe.readEnd, events: Int16(POLLIN), revents: 0)
            try unsafe #require(Glibc.poll(&event, 1, 1_000) == 1)
            var byte: UInt8 = 0
            let count = unsafe Glibc.read(pipe.readEnd, &byte, 1)
            #expect(count == 0)
        }
    }

    func closeReaders() {
        for pipe in pipes {
            Glibc.close(pipe.readEnd)
        }
    }
}
