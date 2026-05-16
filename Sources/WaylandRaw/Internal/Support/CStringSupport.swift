@safe
package func stringFromNullableCString(_ cString: UnsafePointer<CChar>?) -> String? {
    unsafe cString.map { unsafe String(cString: $0) }
}
