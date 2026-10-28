import 'package:material_ui/material_ui.dart';

/// Where the context menu appears relative to the cell it belongs to.
enum ReorderableGridContextMenuPlacement {
  /// Below the cell if there is enough room, above it otherwise.
  auto,

  /// Below the cell.
  below,

  /// Above the cell.
  above,
}

/// Look and placement of the context menu. Every parameter has a default.
class ReorderableGridContextMenuStyle {
  /// Width of the menu panel.
  final double width;

  /// Height of each entry.
  final double itemHeight;

  /// Corner radius of the panel.
  final BorderRadius borderRadius;

  /// Padding inside the panel, around the list of entries.
  final EdgeInsets padding;

  /// Padding inside each entry.
  final EdgeInsets itemPadding;

  /// Background color of the panel. Defaults to the theme's surface color.
  final Color? backgroundColor;

  /// Border color of the panel. Defaults to a translucent `onSurface`.
  final Color? borderColor;

  /// Border width of the panel. Use 0 to hide the border.
  final double borderWidth;

  /// Elevation of the panel.
  final double elevation;

  /// Shadow color of the panel.
  final Color? shadowColor;

  /// Whether to draw a divider between entries.
  final bool showDividers;

  /// Color of the dividers. Defaults to a translucent `onSurface`.
  final Color? dividerColor;

  /// Size of the entry icons.
  final double iconSize;

  /// Horizontal space between an icon and its label.
  final double iconSpacing;

  /// Font size of the labels.
  final double fontSize;

  /// Font weight of the labels.
  final FontWeight fontWeight;

  /// Distance between the cell and the menu. If negative, the menu overlaps
  /// the cell.
  final double gap;

  /// Minimum distance between the menu and the screen edges.
  final double screenMargin;

  /// Where the menu appears relative to the cell.
  final ReorderableGridContextMenuPlacement placement;

  /// Duration of the menu appearance animation.
  final Duration animationDuration;

  /// Creates a context menu style.
  const ReorderableGridContextMenuStyle({
    this.width = 232,
    this.itemHeight = 48,
    this.borderRadius = const BorderRadius.all(Radius.circular(16)),
    this.padding = const EdgeInsets.symmetric(vertical: 8),
    this.itemPadding = const EdgeInsets.symmetric(horizontal: 16),
    this.backgroundColor,
    this.borderColor,
    this.borderWidth = 1,
    this.elevation = 10,
    this.shadowColor,
    this.showDividers = true,
    this.dividerColor,
    this.iconSize = 20,
    this.iconSpacing = 12,
    this.fontSize = 15,
    this.fontWeight = FontWeight.w500,
    this.gap = 4,
    this.screenMargin = 12,
    this.placement = ReorderableGridContextMenuPlacement.auto,
    this.animationDuration = const Duration(milliseconds: 140),
  });

  /// Total height of a menu with [count] entries.
  double heightFor(int count) {
    if (count <= 0) return padding.vertical;
    final dividers = showDividers ? (count - 1) * 1.0 : 0.0;
    return count * itemHeight + dividers + padding.vertical;
  }
}

/// One entry of the grid context menu.
class ReorderableGridContextMenuItem {
  /// Icon shown before the label.
  final IconData icon;

  /// Text of the entry.
  final String label;

  /// Called when the entry is tapped, after the menu has been closed.
  final VoidCallback onPressed;

  /// If true, uses the theme's error color (unless [color] is given).
  final bool isDestructive;

  /// Color of the text and of the splash (and of the icon if [iconColor] is
  /// null). If null: `onSurface`, or `error` if [isDestructive] is true.
  final Color? color;

  /// Color of the icon. If null, the text color is used.
  final Color? iconColor;

  /// Creates a context menu entry.
  const ReorderableGridContextMenuItem({
    required this.icon,
    required this.label,
    required this.onPressed,
    this.isDestructive = false,
    this.color,
    this.iconColor,
  });
}

/// The menu panel. It can also be used outside of the grid.
class ReorderableGridContextMenu extends StatelessWidget {
  /// Entries shown in the menu.
  final List<ReorderableGridContextMenuItem> items;

  /// Called when an entry is tapped.
  final ValueChanged<ReorderableGridContextMenuItem> onSelected;

  /// Look of the menu.
  final ReorderableGridContextMenuStyle style;

  /// Creates a context menu panel.
  const ReorderableGridContextMenu({
    super.key,
    required this.items,
    required this.onSelected,
    this.style = const ReorderableGridContextMenuStyle(),
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    final children = <Widget>[];
    for (var i = 0; i < items.length; i++) {
      if (i > 0 && style.showDividers) {
        children.add(
          Container(
            height: 1,
            color: style.dividerColor ?? scheme.onSurface.withAlpha(18),
          ),
        );
      }
      children.add(
        _ContextMenuTile(
          item: items[i],
          style: style,
          onTap: () => onSelected(items[i]),
        ),
      );
    }

    return Material(
      color: style.backgroundColor ?? scheme.surface,
      elevation: style.elevation,
      shadowColor: style.shadowColor ?? Colors.black.withAlpha(90),
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: style.borderRadius,
        side: style.borderWidth <= 0
            ? BorderSide.none
            : BorderSide(
                color: style.borderColor ?? scheme.onSurface.withAlpha(25),
                width: style.borderWidth,
              ),
      ),
      child: Padding(
        padding: style.padding,
        child: Column(mainAxisSize: MainAxisSize.min, children: children),
      ),
    );
  }
}

class _ContextMenuTile extends StatelessWidget {
  final ReorderableGridContextMenuItem item;
  final ReorderableGridContextMenuStyle style;
  final VoidCallback onTap;

  const _ContextMenuTile({
    required this.item,
    required this.style,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color =
        item.color ?? (item.isDestructive ? scheme.error : scheme.onSurface);
    final iconColor = item.iconColor ?? color;

    return InkWell(
      onTap: onTap,
      splashColor: color.withAlpha(40),
      highlightColor: color.withAlpha(20),
      child: SizedBox(
        height: style.itemHeight,
        child: Padding(
          padding: style.itemPadding,
          child: Row(
            children: [
              Icon(item.icon, size: style.iconSize, color: iconColor),
              SizedBox(width: style.iconSpacing),
              Expanded(
                child: Text(
                  item.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: color,
                    fontSize: style.fontSize,
                    fontWeight: style.fontWeight,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
