import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/item.dart';
import '../services/firestore_service.dart';
import 'add_edit_item_screen.dart';

class InventoryHomePage extends StatefulWidget {
  final String title;
  const InventoryHomePage({super.key, required this.title});

  @override
  State<InventoryHomePage> createState() => _InventoryHomePageState();
}

class _InventoryHomePageState extends State<InventoryHomePage> {
  final _searchCtl = TextEditingController();
  String? _selectedCategory;

  @override
  void dispose() {
    _searchCtl.dispose();
    super.dispose();
  }

  void _openAdd() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AddEditItemScreen()),
    );
  }

  void _openEdit(Item item) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => AddEditItemScreen(item: item)),
    );
  }

  void _openDashboard() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const _DashboardScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final service = FirestoreService.instance;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        actions: [
          IconButton(onPressed: _openDashboard, icon: const Icon(Icons.insights_outlined)),
        ],
      ),
      body: Column(
        children: [
          // Search field
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: TextField(
              controller: _searchCtl,
              decoration: InputDecoration(
                labelText: 'Search by name',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchCtl.text.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () {
                          setState(() {
                            _searchCtl.clear();
                          });
                        },
                      ),
              ),
              onChanged: (_) => setState(() {}),
            ),
          ),

          // Category filter chips (live from Firestore)
          SizedBox(
            height: 56,
            child: StreamBuilder<List<String>>(
              stream: service.categoriesStream(),
              builder: (context, snap) {
                final cats = snap.data ?? const <String>[];
                if (cats.isEmpty) {
                  return const SizedBox.shrink();
                }
                return ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: FilterChip(
                        label: const Text('All'),
                        selected: _selectedCategory == null,
                        onSelected: (_) => setState(() => _selectedCategory = null),
                      ),
                    ),
                    ...cats.map((c) => Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: FilterChip(
                            label: Text(c),
                            selected: _selectedCategory == c,
                            onSelected: (_) => setState(() => _selectedCategory = c),
                          ),
                        )),
                  ],
                );
              },
            ),
          ),

          const Divider(height: 1),

          // Real-time list
          Expanded(
            child: StreamBuilder<List<Item>>(
              stream: service.getItemsStream(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(
                    child: Text('Error: ${snapshot.error}'),
                  );
                }
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                // Filter by search + category
                final q = _searchCtl.text.trim().toLowerCase();
                final filtered = snapshot.data!
                    .where((i) => (q.isEmpty || i.name.toLowerCase().contains(q)))
                    .where((i) => (_selectedCategory == null || i.category == _selectedCategory))
                    .toList();

                if (filtered.isEmpty) {
                  return const Center(child: Text('No items found.'));
                }

                return ListView.separated(
                  itemCount: filtered.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final item = filtered[index];
                    return Dismissible(
                      key: ValueKey(item.id ?? '${item.name}-$index'),
                      background: Container(
                        color: Colors.red.withOpacity(0.1),
                        alignment: Alignment.centerLeft,
                        padding: const EdgeInsets.only(left: 16),
                        child: const Icon(Icons.delete, color: Colors.red),
                      ),
                      secondaryBackground: Container(
                        color: Colors.red.withOpacity(0.1),
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.only(right: 16),
                        child: const Icon(Icons.delete, color: Colors.red),
                      ),
                      confirmDismiss: (_) async {
                        if (item.id == null) return false;
                        return await showDialog<bool>(
                              context: context,
                              builder: (_) => AlertDialog(
                                title: const Text('Delete item?'),
                                content: Text('Delete “${item.name}”?'),
                                actions: [
                                  TextButton(
                                      onPressed: () => Navigator.pop(context, false),
                                      child: const Text('Cancel')),
                                  FilledButton.tonal(
                                      onPressed: () => Navigator.pop(context, true),
                                      child: const Text('Delete')),
                                ],
                              ),
                            ) ??
                            false;
                      },
                      onDismissed: (_) async {
                        if (item.id != null) {
                          await FirestoreService.instance.deleteItem(item.id!);
                        }
                      },
                      child: ListTile(
                        title: Text(item.name),
                        subtitle: Text(
                            'Qty: ${item.quantity} • \$${item.price.toStringAsFixed(2)} • ${item.category}'),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => _openEdit(item),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _openAdd,
        child: const Icon(Icons.add),
      ),
    );
  }
}

class _DashboardScreen extends StatefulWidget {
  const _DashboardScreen();

  @override
  State<_DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<_DashboardScreen> {
  late Future<Map<String, dynamic>> _statsFut;

  @override
  void initState() {
    super.initState();
    _statsFut = FirestoreService.instance.computeStats();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Inventory Insights')),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _statsFut,
        builder: (context, snap) {
          if (snap.hasError) {
            return Center(child: Text('Error: ${snap.error}'));
          }
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final totalItems = snap.data!['totalItems'] as int;
          final totalValue = snap.data!['totalValue'] as double;
          final outOfStock = (snap.data!['outOfStock'] as List<Item>);

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  _StatCard(
                    label: 'Total Items',
                    value: '$totalItems',
                    icon: Icons.inventory_2_outlined,
                  ),
                  _StatCard(
                    label: 'Total Value',
                    value: '\$${totalValue.toStringAsFixed(2)}',
                    icon: Icons.attach_money,
                  ),
                  _StatCard(
                    label: 'Out of Stock',
                    value: '${outOfStock.length}',
                    icon: Icons.error_outline,
                  ),
                ],
              ),
              const SizedBox(height: 24),
              const Text('Out of Stock Items', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              if (outOfStock.isEmpty)
                const Text('🎉 None! All items are in stock.')
              else
                ...outOfStock.map(
                  (i) => Card(
                    child: ListTile(
                      title: Text(i.name),
                      subtitle: Text('Category: ${i.category} • Price: \$${i.price.toStringAsFixed(2)}'),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  const _StatCard({required this.label, required this.value, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: SizedBox(
        width: 220,
        height: 110,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(icon, size: 36),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
                    const SizedBox(height: 6),
                    Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
