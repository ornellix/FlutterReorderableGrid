import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import 'context_menu/context_menu_layer.dart';
import 'context_menu/reorderable_grid_context_menu.dart';
import 'reorderable_grid_typedefs.dart';
import 'touch_gate.dart';

/// A grid whose items can be reordered with drag and drop.
///
/// Long press an item to start dragging it. If [contextMenuBuilder] returns
/// entries for the item, the long press opens a context menu first: moving
/// the finger afterwards turns the gesture into a drag.
///
/// The grid never modifies [items]. When an item is dropped in a new position
/// it calls [onReorder] with the new order: store it in your state and pass it
/// back through [items].
class ReorderableGrid<T extends Object> extends StatefulWidget {
  /// The items to display, in order.
  final List<T> items;

  /// Builds the widget for an item. It is also used for the drag feedback.
  final ReorderableGridItemBuilder<T> itemBuilder;

  /// Returns a stable, unique key for an item.
  ///
  /// If null, the item itself is used as key, so it needs a proper `==` and
  /// `hashCode`. Providing this is strongly recommended.
  final ReorderableGridItemKey<T>? itemKey;

  /// Called with the new order when an item is dropped in a different
  /// position.
  final ValueChanged<List<T>> onReorder;

  /// Returns the context menu entries for an item.
  ///
  /// If null (or if it returns an empty list), a long press starts the drag
  /// immediately.
  final ReorderableGridContextMenuBuilder<T>? contextMenuBuilder;

  /// Look and placement of the context menu (radius, padding, colors,
  /// position...).
  final ReorderableGridContextMenuStyle contextMenuStyle;

  /// Number of columns.
  final int crossAxisCount;

  /// Vertical space between rows.
  final double mainAxisSpacing;

  /// Horizontal space between columns.
  final double crossAxisSpacing;

  /// Width / height ratio of each cell.
  final double childAspectRatio;

  /// Padding around the grid.
  final EdgeInsets padding;

  /// Creates a reorderable grid.
  const ReorderableGrid({
    super.key,
    required this.items,
    required this.itemBuilder,
    required this.onReorder,
    this.itemKey,
    this.contextMenuBuilder,
    this.contextMenuStyle = const ReorderableGridContextMenuStyle(),
    this.crossAxisCount = 6,
    this.mainAxisSpacing = 12,
    this.crossAxisSpacing = 12,
    this.childAspectRatio = 1,
    this.padding = EdgeInsets.zero,
  }) : assert(crossAxisCount > 0),
       assert(childAspectRatio > 0);

  @override
  State<ReorderableGrid<T>> createState() => _ReorderableGridState<T>();
}

class _ReorderableGridState<T extends Object> extends State<ReorderableGrid<T>>
    with TickerProviderStateMixin {
  static const _moveDuration = Duration(milliseconds: 220);
  static const _effectDuration = Duration(milliseconds: 180);
  static const _dragDelay = Duration(milliseconds: 500);
  static const _wiggleDuration = Duration(milliseconds: 110);

  /// After the menu opens, moving the finger (still down) farther than this
  /// distance, in logical pixels, starts the drag.
  static const double _moveSlop = 12;

  static const double _wiggleAngle = 0.012;

  final GlobalKey _gridKey = GlobalKey();

  late final AnimationController _wiggleController;
  late final AnimationController _modeController;

  late final Animation<double> _wiggleAnimation;
  late final Listenable _wiggleListenable;

  late final TouchGate _gate = TouchGate(
    onPreempt: (key) {
      if (!mounted) return;
      setState(() => _epochs[key] = (_epochs[key] ?? 0) + 1);
    },
  );

  final Map<Object, int> _epochs = {};

  // --- Context menu / pending phase ---------------------------------------
  final ValueNotifier<bool> _feedbackVisible = ValueNotifier<bool>(true);

  OverlayEntry? _menuEntry;
  Object? _menuKey; // cell with the open menu

  Object? _pendingKey; // menu just opened, finger still down, drag not started
  T? _pendingItem;

  Offset? _lastPointer;
  Offset? _holdOrigin;
  bool _draggableStartedThisPress = false;

  // --- Drag ----------------------------------------------------------------
  T? _draggingItem;

  List<T> _originalItems = [];
  List<T> _previewItems = [];

  int? _targetIndex;

  bool _dragActive = false;

  double _cellWidth = 0;
  double _cellHeight = 0;

  bool get _isDragging => _dragActive && _draggingItem != null;

  Object _keyFor(T item) => widget.itemKey?.call(item) ?? item;

  bool _sameItem(T a, T b) => _keyFor(a) == _keyFor(b);

  List<T> get _displayItems {
    if (!_isDragging || _targetIndex == null) {
      return List<T>.of(widget.items);
    }

    final result = List<T>.of(_previewItems);
    final index = _targetIndex!.clamp(0, result.length);

    result.insert(index, _draggingItem!);

    return result;
  }

  @override
  void initState() {
    super.initState();

    _wiggleController = AnimationController(
      vsync: this,
      duration: _wiggleDuration,
    );

    _modeController = AnimationController(
      vsync: this,
      duration: _effectDuration,
    );

    _wiggleAnimation = Tween<double>(begin: -_wiggleAngle, end: _wiggleAngle)
        .animate(
          CurvedAnimation(parent: _wiggleController, curve: Curves.easeInOut),
        );

    _wiggleListenable = Listenable.merge([_wiggleAnimation, _modeController]);
  }

  @override
  void didUpdateWidget(covariant ReorderableGrid<T> oldWidget) {
    super.didUpdateWidget(oldWidget);

    // If the item with the open menu disappears, close the menu.
    final key = _menuKey;
    if (key != null && !widget.items.any((e) => _keyFor(e) == key)) {
      _closeMenu();
    }
  }

  @override
  void dispose() {
    _closeMenu();
    _feedbackVisible.dispose();
    _wiggleController.dispose();
    _modeController.dispose();

    super.dispose();
  }

  // ------------------------------------------------------------------------
  // Context menu
  // ------------------------------------------------------------------------

  bool _openMenu(
    Object key,
    List<ReorderableGridContextMenuItem> items,
    BuildContext cellContext,
  ) {
    final box = cellContext.findRenderObject();
    if (box is! RenderBox || !box.hasSize) return false;

    final overlay = Overlay.maybeOf(cellContext, rootOverlay: true);
    if (overlay == null) return false;

    final rect = box.localToGlobal(Offset.zero) & box.size;

    _closeMenu();

    final entry = OverlayEntry(
      builder: (_) => ContextMenuLayer(
        anchor: rect,
        items: items,
        style: widget.contextMenuStyle,
        onDismiss: _closeMenu,
        onSelected: (item) {
          _closeMenu();
          item.onPressed();
        },
      ),
    );

    overlay.insert(entry);
    _menuEntry = entry;
    _menuKey = key;

    HapticFeedback.mediumImpact();
    return true;
  }

  void _closeMenu() {
    final entry = _menuEntry;
    _menuEntry = null;
    _menuKey = null;
    if (entry == null) return;
    entry.remove();
    entry.dispose();
  }

  // ------------------------------------------------------------------------
  // Drag
  // ------------------------------------------------------------------------

  /// Called when the delay (500 ms) expires with the finger still down.
  void _onDraggableStarted(T item, BuildContext cellContext) {
    _draggableStartedThisPress = true;

    if (_dragActive) return;

    final key = _keyFor(item);
    if (_gate.key != null && _gate.key != key) return;

    final menuItems =
        widget.contextMenuBuilder?.call(item) ??
        const <ReorderableGridContextMenuItem>[];

    // No menu, or menu already open on this item: start the drag directly.
    if (menuItems.isEmpty || _menuKey == key) {
      _commitDrag(item);
      return;
    }

    // Phase 1: open the menu; the drag stays "pending" until the finger
    // moves.
    _feedbackVisible.value = false;

    if (!_openMenu(key, menuItems, cellContext)) {
      _commitDrag(item);
      return;
    }

    _holdOrigin = _lastPointer;

    setState(() {
      _pendingKey = key;
      _pendingItem = item;
    });
  }

  /// Moves from the "pending" phase to the real drag and drop.
  void _commitDrag(T item) {
    if (_dragActive) return;

    _closeMenu();
    _feedbackVisible.value = true;
    _pendingKey = null;
    _pendingItem = null;

    HapticFeedback.lightImpact();
    _startDrag(item);
  }

  void _onDragUpdate(DragUpdateDetails details) {
    if (!_dragActive && _pendingItem != null) {
      final origin = _holdOrigin;
      final moved =
          origin == null ||
          (details.globalPosition - origin).distance > _moveSlop;
      if (!moved) return;

      _commitDrag(_pendingItem as T);
    }

    _updatePointer(details.globalPosition);
  }

  void _startDrag(T item) {
    // A drag is already active, or the lock belongs to another cell.
    if (_dragActive) return;
    if (_gate.key != null && _gate.key != _keyFor(item)) return;

    final original = List<T>.of(widget.items);

    final oldIndex = original.indexWhere((element) => _sameItem(element, item));

    if (oldIndex < 0) return;

    setState(() {
      _originalItems = original;

      _previewItems = List<T>.of(original)..removeAt(oldIndex);

      _draggingItem = item;
      _targetIndex = oldIndex;
      _dragActive = true;
    });

    // Start the wiggle and fade it in gradually.
    _modeController.forward();
    _wiggleController.repeat(reverse: true);
  }

  void _updatePointer(Offset globalPosition) {
    if (!_isDragging || _cellWidth <= 0 || _cellHeight <= 0) {
      return;
    }

    final renderObject = _gridKey.currentContext?.findRenderObject();

    if (renderObject is! RenderBox || !renderObject.hasSize) {
      return;
    }

    final local = renderObject.globalToLocal(globalPosition);

    final columnStride = _cellWidth + widget.crossAxisSpacing;
    final rowStride = _cellHeight + widget.mainAxisSpacing;

    if (local.dx < 0 ||
        local.dy < 0 ||
        local.dx >= renderObject.size.width ||
        local.dy >= renderObject.size.height) {
      return;
    }

    final column = (local.dx / columnStride).floor();
    final row = (local.dy / rowStride).floor();

    final clampedColumn = column.clamp(0, widget.crossAxisCount - 1);

    final rowCount = (_originalItems.length / widget.crossAxisCount).ceil();

    if (rowCount == 0) return;

    final clampedRow = row.clamp(0, rowCount - 1);

    final columnOffset = local.dx - clampedColumn * columnStride;

    final rowOffset = local.dy - clampedRow * rowStride;

    // Ignore the gaps between cells.
    if (columnOffset > _cellWidth || rowOffset > _cellHeight) {
      return;
    }

    final rawIndex = clampedRow * widget.crossAxisCount + clampedColumn;

    final index = rawIndex.clamp(0, _originalItems.length - 1);

    if (_targetIndex == index) return;

    setState(() {
      _targetIndex = index;
    });
  }

  void _finishDrag() {
    if (!_dragActive) {
      // Finger released during the pending phase: the menu stays open.
      _gate.release();
      if (_pendingKey != null && mounted) {
        setState(() {
          _pendingKey = null;
          _pendingItem = null;
        });
      }
      return;
    }

    final item = _draggingItem;
    final targetIndex = _targetIndex;

    List<T>? reordered;

    if (item != null && targetIndex != null) {
      final result = List<T>.of(_previewItems);

      final index = targetIndex.clamp(0, result.length);

      result.insert(index, item);

      final changed =
          result.length != _originalItems.length ||
          List.generate(
            result.length,
            (i) => !_sameItem(result[i], _originalItems[i]),
          ).any((different) => different);

      if (changed) {
        reordered = result;
      }
    }

    _gate.release();

    setState(() {
      _dragActive = false;
      _draggingItem = null;
      _targetIndex = null;

      _previewItems = [];
      _originalItems = [];
    });

    // The wiggle fades out gradually instead of stopping abruptly.
    _modeController.reverse().then((_) {
      if (!mounted || !_modeController.isDismissed) return;

      _wiggleController.stop();
      _wiggleController.reset();
    });

    if (reordered != null) {
      widget.onReorder(reordered);
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final count = widget.crossAxisCount;

        // Real width available to the cells, minus the horizontal padding.
        final availableWidth = math.max(
          0.0,
          constraints.maxWidth - widget.padding.horizontal,
        );

        _cellWidth =
            (availableWidth - widget.crossAxisSpacing * (count - 1)) / count;

        _cellHeight = _cellWidth / widget.childAspectRatio;

        final items = _displayItems;

        final rows = (items.length / count).ceil();

        final gridHeight = rows == 0
            ? 0.0
            : rows * _cellHeight + (rows - 1) * widget.mainAxisSpacing;

        return SingleChildScrollView(
          padding: widget.padding,
          child: SizedBox(
            key: _gridKey,
            width: availableWidth,
            height: gridHeight,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                for (var i = 0; i < items.length; i++)
                  _buildCell(
                    context: context,
                    item: items[i],
                    index: i,
                    width: _cellWidth,
                    height: _cellHeight,
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildCell({
    required BuildContext context,
    required T item,
    required int index,
    required double width,
    required double height,
  }) {
    final cellKey = _keyFor(item);

    final isDraggingItem =
        _isDragging &&
        _draggingItem != null &&
        _sameItem(item, _draggingItem as T);

    final isTarget = _isDragging && _targetIndex == index && !isDraggingItem;

    final column = index % widget.crossAxisCount;
    final row = index ~/ widget.crossAxisCount;

    final left = column * (width + widget.crossAxisSpacing);
    final top = row * (height + widget.mainAxisSpacing);

    final phase = index.isEven ? 0.0 : math.pi;

    return AnimatedPositioned(
      // The key stays stable even when the item object is recreated.
      key: ValueKey<Object>(cellKey),
      duration: _moveDuration,
      curve: Curves.easeOutCubic,
      left: left,
      top: top,
      width: width,
      height: height,
      child: AnimatedBuilder(
        key: ValueKey<Object>('cell-$cellKey'),
        animation: _wiggleListenable,
        child: AnimatedScale(
          duration: _effectDuration,
          curve: Curves.easeOutCubic,
          scale: isTarget ? 1.035 : 1,
          child: SingleTouchGate(
            gate: _gate,
            cellKey: cellKey,
            index: index,
            child: KeyedSubtree(
              // Changes only when the cell is preempted by one with a lower
              // index: remounts the subtree and cancels its gestures.
              key: ValueKey<Object>('${cellKey}_${_epochs[cellKey] ?? 0}'),
              child: Listener(
                onPointerDown: (event) {
                  _lastPointer = event.position;
                  _draggableStartedThisPress = false;
                },
                onPointerMove: (event) {
                  _lastPointer = event.position;
                },
                onPointerUp: (_) {
                  // Short tap on the item with the open menu: close the menu.
                  if (_menuKey == cellKey &&
                      !_draggableStartedThisPress &&
                      !_dragActive) {
                    _closeMenu();
                  }
                },
                child: Builder(
                  builder: (cellContext) {
                    final cellChild = AnimatedOpacity(
                      duration: _effectDuration,
                      curve: Curves.easeInOut,
                      opacity: isDraggingItem ? 0.12 : 1,
                      child: AnimatedScale(
                        duration: _effectDuration,
                        curve: Curves.easeOutCubic,
                        scale: isDraggingItem ? 0.92 : 1,
                        child: widget.itemBuilder(context, item, index),
                      ),
                    );

                    return LongPressDraggable<T>(
                      maxSimultaneousDrags: 1,
                      data: item,
                      delay: _dragDelay,
                      onDragStarted: () =>
                          _onDraggableStarted(item, cellContext),
                      onDragUpdate: _onDragUpdate,
                      onDragEnd: (_) => _finishDrag(),
                      onDraggableCanceled: (_, _) => _finishDrag(),
                      // Invisible until the drag is "confirmed".
                      feedback: ValueListenableBuilder<bool>(
                        valueListenable: _feedbackVisible,
                        builder: (context, visible, child) =>
                            Opacity(opacity: visible ? 1 : 0, child: child),
                        child: Material(
                          color: Colors.transparent,
                          child: SizedBox(
                            width: width,
                            height: height,
                            child: Transform.scale(
                              scale: 1.06,
                              child: Opacity(
                                opacity: 0.94,
                                child: widget.itemBuilder(context, item, index),
                              ),
                            ),
                          ),
                        ),
                      ),
                      // During the pending phase the item stays visible in
                      // its place.
                      childWhenDragging: _pendingKey == cellKey
                          ? cellChild
                          : const SizedBox.expand(),
                      child: cellChild,
                    );
                  },
                ),
              ),
            ),
          ),
        ),
        builder: (context, child) {
          // A separate controller lets the wiggle fade out smoothly after the
          // drag has ended.
          final strength = _modeController.value;

          if (strength <= 0 || isDraggingItem) {
            return child!;
          }

          final angle = _wiggleAnimation.value * math.cos(phase) * strength;

          return Transform.rotate(angle: angle, child: child);
        },
      ),
    );
  }
}
