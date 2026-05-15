@safe
extension String {
    package var xkbASCIITrimmed: String {
        let trimmedScalars = unicodeScalars
            .drop { $0.isXKBASCIIWhitespace }
            .reversed()
            .drop { $0.isXKBASCIIWhitespace }
            .reversed()

        return String(String.UnicodeScalarView(trimmedScalars))
    }

    package var containsNULByte: Bool {
        utf8.contains(0)
    }
}

@safe
private extension UnicodeScalar {
    var isXKBASCIIWhitespace: Bool {
        switch value {
        case 0x09...0x0D, 0x20:
            true
        default:
            false
        }
    }
}
