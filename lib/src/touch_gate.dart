import 'package:flutter/rendering.dart';
import 'package:material_ui/material_ui.dart';

/// Lets only one finger at a time interact with the grid cells. When two
/// fingers land almost simultaneously, the cell with the lowest index wins.
///
/// Internal: not exported by the package.
class TouchGate {
  /// Two touches within this window are considered simultaneous.
  static const simultaneousWindow = Duration(milliseconds: 60);

  /// Called with the key of a cell that has just been preempted by a cell
  /// with a lower index.
  final void Function(Object preemptedKey) onPreempt;

  TouchGate({required this.onPreempt});

  Object? key;
  int? index;
  int? pointer;
  final Stopwatch _sinceLock = Stopwatch();

  bool get _recent =>
      _sinceLock.isRunning && _sinceLock.elapsed <= simultaneousWindow;

  bool allows(Object cellKey, int cellIndex) {
    if (key == null || key == cellKey) return true;
    return _recent && index != null && cellIndex < index!;
  }

  void onDown(Object cellKey, int cellIndex, int pointerId) {
    if (key == cellKey) {
      pointer ??= pointerId;
      return;
    }

    if (!allows(cellKey, cellIndex)) return;

    final old = key;
    key = cellKey;
    index = cellIndex;
    pointer = pointerId;
    _sinceLock
      ..reset()
      ..start();

    if (old != null) onPreempt(old);
  }

  void onUpOrCancel(int pointerId) {
    if (pointerId == pointer) release();
  }

  void release() {
    key = null;
    index = null;
    pointer = null;
    _sinceLock
      ..stop()
      ..reset();
  }
}

/// Wraps a cell and filters its touches through a [TouchGate].
///
/// Internal: not exported by the package.
class SingleTouchGate extends SingleChildRenderObjectWidget {
  final TouchGate gate;
  final Object cellKey;
  final int index;

  const SingleTouchGate({
    super.key,
    required this.gate,
    required this.cellKey,
    required this.index,
    required super.child,
  });

  @override
  RenderObject createRenderObject(BuildContext context) {
    return RenderSingleTouchGate(gate, cellKey, index);
  }

  @override
  void updateRenderObject(
      BuildContext context,
      covariant RenderSingleTouchGate renderObject,
      ) {
    renderObject
      ..gate = gate
      ..cellKey = cellKey
      ..index = index;
  }
}

class RenderSingleTouchGate extends RenderProxyBox {
  RenderSingleTouchGate(this.gate, this.cellKey, this.index);

  TouchGate gate;
  Object cellKey;
  int index;

  @override
  bool hitTestSelf(Offset position) => true;

  @override
  bool hitTest(BoxHitTestResult result, {required Offset position}) {
    if (!size.contains(position)) return false;
    if (!gate.allows(cellKey, index)) return false;
    return super.hitTest(result, position: position);
  }

  @override
  void handleEvent(PointerEvent event, HitTestEntry entry) {
    if (event is PointerDownEvent) {
      gate.onDown(cellKey, index, event.pointer);
    } else if (event is PointerUpEvent || event is PointerCancelEvent) {
      gate.onUpOrCancel(event.pointer);
    }
  }
}