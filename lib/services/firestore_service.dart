import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/item.dart';

class FirestoreService {
  FirestoreService._();
  static final instance = FirestoreService._();

  final _col = FirebaseFirestore.instance.collection('items');

  Future<void> addItem(Item item) async {
    await _col.add(item.toMap());
  }

  Stream<List<Item>> getItemsStream() {
    return _col.orderBy('createdAt', descending: true).snapshots().map(
      (snap) => snap.docs
          .map((d) => Item.fromMap(d.id, d.data()))
          .toList(growable: false),
    );
  }

  Future<void> updateItem(Item item) async {
    if (item.id == null) return;
    await _col.doc(item.id!).update(item.toMap());
  }

  Future<void> deleteItem(String itemId) async {
    await _col.doc(itemId).delete();
  }


  Future<Map<String, dynamic>> computeStats() async {
    final qs = await _col.get();
    double totalValue = 0;
    int totalItems = qs.docs.length;
    final outOfStock = <Item>[];

    for (final d in qs.docs) {
      final it = Item.fromMap(d.id, d.data());
      totalValue += it.price * it.quantity;
      if (it.quantity <= 0) outOfStock.add(it);
    }
    return {
      'totalItems': totalItems,
      'totalValue': totalValue,
      'outOfStock': outOfStock,
    };
  }

  /// Distinct category list for filter chips
  Stream<List<String>> categoriesStream() {
    return _col.snapshots().map((snap) {
      final set = <String>{};
      for (final d in snap.docs) {
        final cat = (d.data()['category'] ?? '').toString().trim();
        if (cat.isNotEmpty) set.add(cat);
      }
      return set.toList()..sort();
    });
  }
}
