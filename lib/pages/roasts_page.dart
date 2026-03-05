import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../db_helper.dart';

class RoastsPage extends StatefulWidget {
  const RoastsPage({super.key});
  @override
  State<RoastsPage> createState() => _RoastsPageState();
}

class _RoastsPageState extends State<RoastsPage> {
  final brandCtrl = TextEditingController();
  final blendCtrl = TextEditingController();
  final weightCtrl = TextEditingController();
  final notesCtrl = TextEditingController();
  double _rating = 3.0;
  List<Map<String, dynamic>> roasts = [];

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  @override
  void dispose() {
    brandCtrl.dispose();
    blendCtrl.dispose();
    weightCtrl.dispose();
    notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    final data = await DatabaseHelper.instance.getRoasts();
    if (!mounted) return;
    setState(() => roasts = data);
  }

  void _addRoast() async {
    if (brandCtrl.text.isEmpty && blendCtrl.text.isEmpty) {
      _snack("Enter brand or blend name!");
      return;
    }
    final weight = double.tryParse(weightCtrl.text) ?? 0;
    await DatabaseHelper.instance.insertRoast({
      'brand': brandCtrl.text,
      'blend': blendCtrl.text,
      'rating': _rating,
      'notes': notesCtrl.text,
      'date': DateTime.now().toIso8601String(),
      'total_weight': weight,
      'remaining_weight': weight,
    });
    brandCtrl.clear();
    blendCtrl.clear();
    weightCtrl.clear();
    notesCtrl.clear();
    setState(() => _rating = 3.0);
    _refresh();
    _snack("Roast added!");
  }

  void _deleteRoast(int id) async {
    await DatabaseHelper.instance.deleteRoast(id);
    _refresh();
    _snack("Roast deleted!");
  }

  void _editRating(Map<String, dynamic> roast) {
    double tempRating = (roast['rating'] as num?)?.toDouble() ?? 3.0;
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text(
              'Rate: ${roast['brand'] ?? ''} \u2013 ${roast['blend'] ?? ''}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Slider(
                value: tempRating,
                min: 1,
                max: 5,
                divisions: 8,
                label: tempRating.toStringAsFixed(1),
                onChanged: (v) => setDialogState(() => tempRating = v),
                activeColor: Colors.brown,
              ),
              Text(
                '${tempRating.toStringAsFixed(1)} / 5',
                style:
                    const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text("Cancel"),
            ),
            ElevatedButton(
              onPressed: () async {
                await DatabaseHelper.instance
                    .updateRoastRating(roast['id'] as int, tempRating);
                Navigator.pop(ctx);
                _refresh();
                _snack("Rating updated!");
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.brown),
              child: const Text("Save", style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  void _snack(String msg) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(children: [
          Expanded(child: _field(brandCtrl, 'Brand')),
          const SizedBox(width: 10),
          Expanded(child: _field(blendCtrl, 'Blend')),
        ]),
        Row(children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: TextField(
                controller: weightCtrl,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                    labelText: 'Weight (g)', border: OutlineInputBorder()),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Row(children: [
              Expanded(
                child: Slider(
                  value: _rating,
                  min: 1,
                  max: 5,
                  divisions: 8,
                  label: _rating.toStringAsFixed(1),
                  onChanged: (v) => setState(() => _rating = v),
                  activeColor: Colors.brown,
                ),
              ),
              Text(_rating.toStringAsFixed(1)),
            ]),
          ),
        ]),
        _field(notesCtrl, 'Notes'),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _addRoast,
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.brown, foregroundColor: Colors.white),
            child: const Text("Add Roast"),
          ),
        ),
        const SizedBox(height: 8),
        const Divider(thickness: 2),
        if (roasts.isEmpty)
          const Padding(
            padding: EdgeInsets.only(top: 32),
            child: Center(
              child: Text("No roasts yet.\nAdd your first bag of coffee above!",
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey)),
            ),
          ),
        ...roasts.map(_buildRoastTile),
      ],
    );
  }

  Widget _buildRoastTile(Map<String, dynamic> r) {
    final date = DateTime.tryParse(r['date'] ?? '');
    final dateStr = date != null ? DateFormat('MM/dd/yyyy').format(date) : '';
    final remaining =
        (r['remaining_weight'] as num?)?.toStringAsFixed(0) ?? '0';
    final total = (r['total_weight'] as num?)?.toStringAsFixed(0) ?? '0';
    final rating = (r['rating'] as num?)?.toStringAsFixed(1) ?? '?';
    final pct = (r['total_weight'] != null && (r['total_weight'] as num) > 0)
        ? ((r['remaining_weight'] as num? ?? 0) /
                (r['total_weight'] as num) *
                100)
            .toStringAsFixed(0)
        : '?';

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ListTile(
        leading: GestureDetector(
          onTap: () => _editRating(r),
          child: CircleAvatar(
            backgroundColor: Colors.brown,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(rating,
                    style: const TextStyle(color: Colors.white, fontSize: 11)),
                const Icon(Icons.edit, color: Colors.white70, size: 10),
              ],
            ),
          ),
        ),
        title: Text('${r['brand'] ?? ''} – ${r['blend'] ?? ''}',
            style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(
            '${remaining}g / ${total}g  ($pct% left)\n${r['notes'] ?? ''}\n$dateStr'),
        isThreeLine: true,
        trailing: IconButton(
          icon: const Icon(Icons.delete, color: Colors.red),
          onPressed: () => _deleteRoast(r['id']),
        ),
      ),
    );
  }

  Widget _field(TextEditingController c, String label) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: TextField(
          controller: c,
          decoration: InputDecoration(
              labelText: label, border: const OutlineInputBorder()),
        ),
      );
}
