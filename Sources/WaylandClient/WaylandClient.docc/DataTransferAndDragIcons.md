# Data Transfer And Drag Icons

SwiftWayland exposes clipboard, primary selection, and drag-and-drop transfer
through ``ClipboardOffer``, ``ClipboardSource``, ``PrimarySelectionOffer``,
``PrimarySelectionSource``, ``DragOffer``, and ``DragSource``.

``DragIcon`` supports no icon or a simple XRGB8888 ``DragIconImage``. The icon is
a pixel payload used to create a temporary source-side Wayland surface for the
drag. It is not a retained drag UI, renderer surface, or widget.
Use ``DragIconImage/solid(size:color:)`` for one-color test or placeholder
icons, and construct ``DragIconImage`` directly when supplying exact XRGB8888
pixels.

Data-transfer events use their own stream so clipboard, primary selection, and
drag lifecycles can be observed independently from pointer and keyboard input.
