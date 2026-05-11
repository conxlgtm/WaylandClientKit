#if DEBUG
    extension RawSurface {
        package var pointerAddressForTesting: UInt {
            unsafe UInt(bitPattern: UnsafeMutableRawPointer(pointer))
        }
    }
#endif
