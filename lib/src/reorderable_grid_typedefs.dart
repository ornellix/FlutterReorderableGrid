import 'package:material_ui/material_ui.dart';

import 'context_menu/reorderable_grid_context_menu.dart';

/// Builds the widget shown for [item] at position [index].
typedef ReorderableGridItemBuilder<T> = Widget Function(
  BuildContext context,
  T item,
  int index,
);

/// Returns a stable, unique key that identifies [item].
typedef ReorderableGridItemKey<T> = Object Function(T item);

/// Returns the context menu entries for [item].
typedef ReorderableGridContextMenuBuilder<T> =
    List<ReorderableGridContextMenuItem> Function(T item);
