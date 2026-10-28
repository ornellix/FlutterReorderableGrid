import 'dart:math' as math;
import 'package:material_ui/material_ui.dart';

import 'reorderable_grid_context_menu.dart';

/// Overlay layer: a barrier covering everything except the cell, plus the
/// menu anchored to the cell.
///
/// Internal: not exported by the package.
class ContextMenuLayer extends StatelessWidget {
  final Rect anchor;
  final List<ReorderableGridContextMenuItem> items;
  final ReorderableGridContextMenuStyle style;
  final VoidCallback onDismiss;
  final ValueChanged<ReorderableGridContextMenuItem> onSelected;

  const ContextMenuLayer({
    super.key,
    required this.anchor,
    required this.items,
    required this.style,
    required this.onDismiss,
    required this.onSelected,
  });

  Widget _barrier(Rect r) {
    if (r.width <= 0 || r.height <= 0) return const SizedBox.shrink();
    return Positioned.fromRect(
      rect: r,
      child: Listener(
        behavior: HitTestBehavior.opaque,
        onPointerDown: (_) => onDismiss(),
        child: const SizedBox.expand(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final w = media.size.width;
    final h = media.size.height;
    final edge = style.screenMargin;
    final gap = style.gap;

    double cl(double v, double max) => math.max(0.0, math.min(max, v));

    // Cell rect clamped to the screen.
    final a = Rect.fromLTRB(
      cl(anchor.left, w),
      cl(anchor.top, h),
      cl(anchor.right, w),
      cl(anchor.bottom, h),
    );

    final menuW = math.min(style.width, w - edge * 2);
    final menuH = style.heightFor(items.length);

    final spaceBelow = h - media.padding.bottom - a.bottom;
    final spaceAbove = a.top - media.padding.top;

    final bool showBelow;
    switch (style.placement) {
      case ReorderableGridContextMenuPlacement.below:
        showBelow = true;
        break;
      case ReorderableGridContextMenuPlacement.above:
        showBelow = false;
        break;
      case ReorderableGridContextMenuPlacement.auto:
        showBelow =
            spaceBelow >= menuH + gap + edge || spaceBelow >= spaceAbove;
        break;
    }

    final minTop = media.padding.top + edge;
    final maxTop = math.max(minTop, h - media.padding.bottom - edge - menuH);
    final rawTop = showBelow ? a.bottom + gap : a.top - gap - menuH;
    final top = math.max(minTop, math.min(maxTop, rawTop));

    final maxLeft = math.max(edge, w - edge - menuW);
    final left = math.max(edge, math.min(maxLeft, a.center.dx - menuW / 2));

    final alignX = (((a.center.dx - left) / menuW) * 2 - 1).clamp(-1.0, 1.0);

    return SizedBox.expand(
      child: Stack(
        children: [
          _barrier(Rect.fromLTRB(0, 0, w, a.top)),
          _barrier(Rect.fromLTRB(0, a.bottom, w, h)),
          _barrier(Rect.fromLTRB(0, a.top, a.left, a.bottom)),
          _barrier(Rect.fromLTRB(a.right, a.top, w, a.bottom)),
          Positioned(
            left: left,
            top: top,
            width: menuW,
            child: TweenAnimationBuilder<double>(
              tween: Tween<double>(begin: 0, end: 1),
              duration: style.animationDuration,
              curve: Curves.easeOutCubic,
              builder: (context, v, child) => Opacity(
                opacity: v,
                child: Transform.scale(
                  scale: 0.92 + 0.08 * v,
                  alignment: Alignment(alignX, showBelow ? -1.0 : 1.0),
                  child: child,
                ),
              ),
              child: ReorderableGridContextMenu(
                items: items,
                style: style,
                onSelected: onSelected,
              ),
            ),
          ),
        ],
      ),
    );
  }
}