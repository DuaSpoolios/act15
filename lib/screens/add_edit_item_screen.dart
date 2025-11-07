import 'package:flutter/material.dart';
import '../models/item.dart';
import '../services/firestore_service.dart';

class AddEditItemScreen extends StatefulWidget {
  final Item? item;
  const AddEditItemScreen({super.key, this.item});

  @override
  State<AddEditItemScreen> createState() => _AddEditItemScreenState();
}

class _AddEditItemScreenState extends State<AddEditItemScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtl;
  late final TextEditingController _qtyCtl;
  late final TextEditingController _priceCtl;
  late final TextEditingController _catCtl;

  @override
  void initState() {
    super.initState();
    _nameCtl = TextEditingController(text: widget.item?.name ?? '');
    _qtyCtl = TextEditingController(
        text: widget.item != null ? widget.item!.quantity.toString() : '');
    _priceCtl = TextEditingController(
        text: widget.item != null ? widget.item!.price.toString() : '');
    _catCtl = TextEditingController(text: widget.item?.category ?? '');
  }

  @override
  void dispose() {
    _nameCtl.dispose();
    _qtyCtl.dispose();
    _priceCtl.dispose();
    _catCtl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final item = Item(
      id: widget.item?.id,
      name: _nameCtl.text.trim(),
      quantity: int.parse(_qtyCtl.text.trim()),
      price: double.parse(_priceCtl.text.trim()),
      category: _catCtl.text.trim(),
      createdAt: widget.item?.createdAt ?? DateTime.now(),
    );
    if (widget.item == null) {
      await FirestoreService.instance.addItem(item);
    } else {
      await FirestoreService.instance.updateItem(item);
    }
    if (mounted) Navigator.pop(context);
  }

  Future<void> _delete() async {
    if (widget.item?.id == null) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete item?'),
        content:
            const Text('This will permanently remove the item from Firestore.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton.tonal(onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
        ],
      ),
    );
    if (ok == true) {
      await FirestoreService.instance.deleteItem(widget.item!.id!);
      if (mounted) Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.item != null;
    return Scaffold(
      appBar: AppBar(title: Text(editing ? 'Edit Item' : 'Add Item')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _nameCtl,
              decoration: const InputDecoration(labelText: 'Name'),
              textInputAction: TextInputAction.next,
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _qtyCtl,
              decoration: const InputDecoration(labelText: 'Quantity'),
              keyboardType: TextInputType.number,
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Required';
                final n = int.tryParse(v);
                if (n == null) return 'Enter a whole number';
                return null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _priceCtl,
              decoration: const InputDecoration(labelText: 'Price'),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Required';
                final n = double.tryParse(v);
                if (n == null) return 'Enter a number';
                return null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _catCtl,
              decoration: const InputDecoration(labelText: 'Category'),
              textInputAction: TextInputAction.done,
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: _save,
              child: Text(editing ? 'Save Changes' : 'Add Item'),
            ),
            if (editing) ...[
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _delete,
                icon: const Icon(Icons.delete_outline),
                label: const Text('Delete'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
