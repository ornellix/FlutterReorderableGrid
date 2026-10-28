import 'package:flutter_reorderable_grid/flutter_reorderable_grid.dart';
import 'package:material_ui/material_ui.dart';

void main() => runApp(const ExampleApp());

class ExampleApp extends StatelessWidget {
  const ExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'flutter_reorderable_grid example',
      theme: ThemeData(colorSchemeSeed: Colors.indigo, useMaterial3: true),
      home: const DemoPage(),
    );
  }
}

/// Any class can be used as grid item. The grid only needs a stable key
/// for each item, provided through `itemKey`.
class Tile {
  const Tile({
    required this.id,
    required this.label,
    required this.icon,
    required this.color,
  });

  final String id;
  final String label;
  final IconData icon;
  final Color color;
}

class DemoPage extends StatefulWidget {
  const DemoPage({super.key});

  @override
  State<DemoPage> createState() => _DemoPageState();
}

class _DemoPageState extends State<DemoPage> {
  static const _icons = <IconData>[
    Icons.home,
    Icons.star,
    Icons.favorite,
    Icons.settings,
    Icons.camera_alt,
    Icons.music_note,
    Icons.map,
    Icons.bolt,
    Icons.cloud,
    Icons.book,
    Icons.call,
    Icons.shopping_cart,
  ];

  late List<Tile> _tiles = List.generate(
    _icons.length,
    (i) => Tile(
      id: 'tile-$i',
      label: 'Tile ${i + 1}',
      icon: _icons[i],
      color: Colors.primaries[i % Colors.primaries.length],
    ),
  );

  int _copies = 0;

  void _duplicate(Tile tile) {
    final index = _tiles.indexWhere((t) => t.id == tile.id);
    if (index < 0) return;

    setState(() {
      _tiles = [
        ..._tiles.sublist(0, index + 1),
        Tile(
          id: '${tile.id}-copy-${_copies++}',
          label: '${tile.label} copy',
          icon: tile.icon,
          color: tile.color,
        ),
        ..._tiles.sublist(index + 1),
      ];
    });
  }

  void _delete(Tile tile) {
    setState(() {
      _tiles = _tiles.where((t) => t.id != tile.id).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Reorderable grid')),
      body: ReorderableGrid<Tile>(
        padding: const EdgeInsets.all(16),
        items: _tiles,
        itemKey: (tile) => tile.id,
        crossAxisCount: 3,
        // The grid never changes your list: store the new order yourself.
        onReorder: (reordered) => setState(() => _tiles = reordered),
        itemBuilder: (context, tile, index) => _TileCard(tile: tile),
        contextMenuStyle: const ReorderableGridContextMenuStyle(
          width: 200,
          itemHeight: 48,
        ),
        contextMenuBuilder: (tile) => [
          ReorderableGridContextMenuItem(
            icon: Icons.copy,
            label: 'Duplicate',
            onPressed: () => _duplicate(tile),
          ),
          ReorderableGridContextMenuItem(
            icon: Icons.delete_outline,
            label: 'Delete',
            isDestructive: true,
            onPressed: () => _delete(tile),
          ),
        ],
      ),
    );
  }
}

class _TileCard extends StatelessWidget {
  const _TileCard({required this.tile});

  final Tile tile;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: tile.color,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(tile.icon, color: Colors.white, size: 32),
          const SizedBox(height: 8),
          Text(
            tile.label,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
