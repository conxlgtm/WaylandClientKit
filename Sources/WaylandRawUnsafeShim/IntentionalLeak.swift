@unsafe
package func intentionallyLeakObjectForWrongThreadResourceFallback(_ object: AnyObject) {
    _ = unsafe Unmanaged.passRetained(object).toOpaque()
}
