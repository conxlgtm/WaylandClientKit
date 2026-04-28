import Testing

@testable import WaylandKeyboardInterpretation

@Suite
struct KeyboardInterpretationBootstrapTests {
    @Test
    func targetImportsXKBCommonAndCanCreateContext() {
        #expect(KeyboardInterpretationBootstrap.ready)
        #expect(KeyboardInterpretationBootstrap.canCreateContext())
    }
}
