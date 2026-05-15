import Testing

@testable import WaylandKeyboard

@Suite
struct XKBStringTests {
    @Test
    func cCharBufferStopsAtFirstNULInsideWrittenRange() {
        let buffer: [CChar] = [
            CChar(UInt8(ascii: "a")),
            CChar(UInt8(ascii: "b")),
            0,
            CChar(UInt8(ascii: "c")),
        ]

        #expect(buffer.nullTerminatedUTF8String(writtenByteCount: 4) == "ab")
    }

    @Test
    func cCharBufferClampsWrittenByteCountToBufferLength() {
        let buffer: [CChar] = [
            CChar(UInt8(ascii: "o")),
            CChar(UInt8(ascii: "k")),
        ]

        #expect(buffer.nullTerminatedUTF8String(writtenByteCount: 20) == "ok")
    }

    @Test
    func cCharBufferRejectsInvalidUTF8() {
        let buffer = [CChar(bitPattern: 0xff)]

        #expect(buffer.nullTerminatedUTF8String(writtenByteCount: 1) == nil)
    }

    @Test
    func sizedCallRejectsTruncatedSecondRead() {
        var callCount = 0
        let value = stringFromXKBSizedCall { buffer, count in
            callCount += 1
            guard let buffer = unsafe buffer else { return 3 }
            unsafe buffer[0] = CChar(UInt8(ascii: "a"))
            unsafe buffer[1] = CChar(UInt8(ascii: "b"))
            unsafe buffer[2] = CChar(UInt8(ascii: "c"))
            if count > 3 {
                unsafe buffer[3] = 0
            }
            return Int32(count)
        }

        #expect(value == nil)
        #expect(callCount == 2)
    }

    @Test
    func sizedCallRejectsNegativeRead() {
        let value = stringFromXKBSizedCall { buffer, _ in
            guard unsafe buffer != nil else { return 3 }
            return -1
        }

        #expect(value == nil)
    }

    @Test
    func nameCallAcceptsGrowthPathWhenSecondReadFits() {
        var callCount = 0
        let value = stringFromXKBNameCall(initialCapacity: 2) { buffer, count in
            callCount += 1
            if count >= 5 {
                unsafe buffer[0] = CChar(UInt8(ascii: "L"))
                unsafe buffer[1] = CChar(UInt8(ascii: "o"))
                unsafe buffer[2] = CChar(UInt8(ascii: "n"))
                unsafe buffer[3] = CChar(UInt8(ascii: "g"))
                unsafe buffer[4] = 0
            }
            return 4
        }

        #expect(value == "Long")
        #expect(callCount == 2)
    }

    @Test
    func nameCallRejectsTruncatedSecondRead() {
        let value = stringFromXKBNameCall(initialCapacity: 2) { buffer, count in
            if count >= 5 {
                unsafe buffer[0] = CChar(UInt8(ascii: "L"))
                unsafe buffer[1] = CChar(UInt8(ascii: "o"))
                unsafe buffer[2] = CChar(UInt8(ascii: "n"))
                unsafe buffer[3] = CChar(UInt8(ascii: "g"))
            }
            return Int32(count)
        }

        #expect(value == nil)
    }
}
