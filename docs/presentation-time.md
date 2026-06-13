# Presentation Time

WaylandClientKit exposes compositor presentation feedback through the optional
`wp_presentation` protocol.

Frame callbacks and presentation feedback answer different questions:

- frame callbacks tell the client when the compositor is ready for another
  frame
- presentation feedback tells the client what happened to a committed update
  after it was submitted to the compositor

Do not treat frame callbacks as presentation timestamps. If `wp_presentation`
is unavailable, `WaylandCapabilities.presentationTime` reports `.unavailable`
and explicit feedback requests throw `presentationTimeUnavailable`.

## Public API

Use `Window.requestPresentationFeedback()` to request feedback for a managed
toplevel window. Feedback is delivered through `window.presentationEvents`.

```swift
let window = try await display.createWindow()

try await window.show { frame in
    frame.withXRGB8888Rows { _, pixels in
        pixels.initialize(repeating: 0x00306090)
    }
}

try await window.requestPresentationFeedback()

for try await event in window.presentationEvents {
    switch event {
    case .presented(let feedback):
        print(feedback.timestamp, feedback.refreshNanoseconds as Any)
    case .discarded(let identity):
        print("discarded", identity)
    }
}
```

Presentation feedback includes:

- a WaylandClientKit feedback identity
- presentation timestamp
- optional refresh estimate
- presentation sequence
- raw-preserving presentation flags
- synchronized output identity when the compositor reports one and WaylandClientKit
  can map it to a known output

## Test Policy

`wp_presentation` is optional compositor support. Live tests should skip with a
message that names `wp_presentation` when the global is absent. If the compositor
advertises `wp_presentation`, feedback request and callback behavior should be
treated as testable protocol behavior.
