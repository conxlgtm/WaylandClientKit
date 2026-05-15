@safe
extension String {
    package var xkbASCIITrimmed: String {
        let trimmedScalars =
            unicodeScalars
            .drop(while: \.isXKBASCIIWhitespace)
            .reversed()
            .drop(while: \.isXKBASCIIWhitespace)
            .reversed()

        return String(String.UnicodeScalarView(trimmedScalars))
    }

    package var containsNULByte: Bool {
        utf8.contains(0)
    }
}

@safe
extension UnicodeScalar {
    package var isXKBASCIIWhitespace: Bool {
        switch value {
        case 0x09...0x0D, 0x20:
            true
        default:
            false
        }
    }
}
