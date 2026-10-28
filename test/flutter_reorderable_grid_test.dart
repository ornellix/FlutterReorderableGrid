import 'package:flutter_reorderable_grid/flutter_reorderable_grid.dart';
import 'package:flutter_reorderable_grid/src/context_menu/reorderable_grid_context_menu.dart';
import 'package:flutter_reorderable_grid/src/reorderable_grid.dart';
import 'package:flutter_reorderable_grid/src/reorderable_grid_typedefs.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

Widget _app({
  ValueChanged<List<String>>? onReorder,
  ReorderableGridContextMenuBuilder<String>? contextMenuBuilder,
}) {
  return MaterialApp(
    home: Scaffold(
      body: ReorderableGrid<String>(
        items: const ['a', 'b', 'c'],
        itemKey: (item) => item,
        crossAxisCount: 3,
        onReorder: onReorder ?? (_) {},
        contextMenuBuilder: contextMenuBuilder,
        itemBuilder: (context, item, index) => Center(child: Text(item)),
      ),
    ),
  );
}

void main() {
  testWidgets('renders every item', (tester) async {
    await tester.pumpWidget(_app());

    expect(find.text('a'), findsOneWidget);
    expect(find.text('b'), findsOneWidget);
    expect(find.text('c'), findsOneWidget);
  });

  testWidgets('long press opens the context menu', (tester) async {
    await tester.pumpWidget(
      _app(
        contextMenuBuilder: (item) => [
          ReorderableGridContextMenuItem(
            icon: Icons.delete_outline,
            label: 'Delete',
            onPressed: () {},
          ),
        ],
      ),
    );

    final gesture = await tester.startGesture(tester.getCenter(find.text('a')));
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.text('Delete'), findsOneWidget);

    await gesture.up();
    await tester.pump();
  });

  testWidgets('dragging an item calls onReorder with the new order', (
      tester,
      ) async {
    List<String>? result;
    await tester.pumpWidget(_app(onReorder: (items) => result = items));

    final gesture = await tester.startGesture(tester.getCenter(find.text('a')));
    await tester.pump(const Duration(milliseconds: 600));
    await gesture.moveTo(tester.getCenter(find.text('c')));
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();

    expect(result, ['b', 'c', 'a']);
  });
}