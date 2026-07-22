# Data Transfer And Drag Icons

WaylandClientKit exposes clipboard, primary selection, and drag-and-drop transfer
through ``ClipboardOffer``, ``ClipboardSource``, ``PrimarySelectionOffer``,
``PrimarySelectionSource``, ``DragOffer``, and ``DragSource``.

``DragIcon`` supports no icon or a simple XRGB8888 ``DragIconImage``. The icon is
a pixel payload used to create a temporary source-side Wayland surface for the
drag. Use ``DragIconImage/solid(size:color:)`` for one-color test or placeholder
icons, and construct ``DragIconImage`` directly when supplying exact XRGB8888
pixels.

Data-transfer events use their own stream so clipboard, primary selection, and
drag lifecycles can be observed independently from pointer and keyboard input.
Offers are external compositor state and can become stale between advertisement
and use. Stale or unknown offers produce typed failures or diagnostics.

``DataTransferEvent`` reports source send requests and successful writes. Failed
writes publish a `DataTransferDiagnosticOperation.sourceWriteFailed` diagnostic.

## Capability Gates

Regular clipboard and drag-and-drop use `wl_data_device_manager`. Primary
selection uses `zwp_primary_selection_device_manager_v1` and is focus-sensitive
selection state, not a second regular clipboard.

WaylandClientKit owns offer/source lifetime, descriptor cleanup, stale-offer
diagnostics, and typed callback failures. Frameworks own MIME negotiation,
clipboard policy, drag visuals, and drop-action policy.

## Example

See `DataTransferSmoke` in `Examples/DataTransferSmoke`.
