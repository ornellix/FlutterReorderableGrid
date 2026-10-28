## 0.0.1

- Initial release.
- `ReorderableGrid<T>`: reorderable grid with drag and drop for any item type,
  keyed through `itemKey` and reporting the new order through `onReorder`.
- iOS-style wiggle animation on the other items while dragging, with smooth
  fade in and out.
- Animated item movement, highlighted drop target, scaled drag preview, faded
  placeholder for the dragged item and haptic feedback.
- Optional long-press context menu (`contextMenuBuilder`): moving the finger
  after the menu opens starts the drag, releasing it keeps the menu open.
- `ReorderableGridContextMenuStyle`: size, padding, colors, border, elevation,
  shadow, dividers, icon and font sizes, gap, screen margin, placement
  (`auto`, `below`, `above`) and animation duration.
- `ReorderableGridContextMenuItem`: icon, label, custom colors and destructive
  style.
- `ReorderableGridContextMenu`: menu panel reusable outside of the grid.
- Single-touch handling: only one item can be pressed at a time.
- Grid layout options: `crossAxisCount`, `mainAxisSpacing`,
  `crossAxisSpacing`, `childAspectRatio` and `padding`.