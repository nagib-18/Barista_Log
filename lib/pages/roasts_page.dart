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
  final priceCtrl = TextEditingController();
  final notesCtrl = TextEditingController();
  final regionCtrl = TextEditingController();
  double _rating = 3.0;
  List<String> _flavorTags = [];
  final flavorInputCtrl = TextEditingController();
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
    priceCtrl.dispose();
    notesCtrl.dispose();
    regionCtrl.dispose();
    flavorInputCtrl.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    final data = await DatabaseHelper.instance.getRoasts();
    if (!mounted) return;
    setState(() => roasts = data);
  }

  void _addFlavor() {
    final v = flavorInputCtrl.text.trim();
    if (v.isEmpty) return;
    setState(() => _flavorTags.add(v));
    flavorInputCtrl.clear();
  }

  void _addRoast() async {
    if (brandCtrl.text.isEmpty && blendCtrl.text.isEmpty) {
      _snack("Enter brand or blend name!");
      return;
    }
    final weight = double.tryParse(weightCtrl.text) ?? 0;
    final price = double.tryParse(priceCtrl.text);
    try {
      await DatabaseHelper.instance.insertRoast({
        'brand': brandCtrl.text,
        'blend': blendCtrl.text,
        'rating': _rating,
        'notes': notesCtrl.text,
        'date': DateTime.now().toIso8601String(),
        'total_weight': weight,
        'remaining_weight': weight,
        'region': regionCtrl.text,
        'flavor_profile': _flavorTags.join(','),
        'price': price,
      });
      brandCtrl.clear();
      blendCtrl.clear();
      weightCtrl.clear();
      priceCtrl.clear();
      notesCtrl.clear();
      regionCtrl.clear();
      flavorInputCtrl.clear();
      setState(() {
        _rating = 3.0;
        _flavorTags = [];
      });
      _refresh();
      _snack("Roast added!");
    } catch (e) {
      _snack("Error adding roast: $e");
    }
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
          title: Text('Rate: ${roast['brand'] ?? ''} \u2013 ${roast['blend'] ?? ''}'),
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
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
            ElevatedButton(
              onPressed: () async {
                await DatabaseHelper.instance.updateRoastRating(roast['id'] as int, tempRating);
                if (ctx.mounted) Navigator.pop(ctx);
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

  void _editNotes(Map<String, dynamic> roast) {
    final notesEditCtrl = TextEditingController(text: roast['notes'] ?? '');
    final regionEditCtrl = TextEditingController(text: roast['region'] ?? '');
    final existingFlavors = ((roast['flavor_profile'] as String?) ?? '')
        .split(',')
        .where((s) => s.isNotEmpty)
        .toList();
    List<String> tempFlavors = List.from(existingFlavors);
    final flavorEdit = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text('Edit: ${roast['brand'] ?? ''} \u2013 ${roast['blend'] ?? ''}'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: regionEditCtrl,
                  decoration: const InputDecoration(
                      labelText: 'Region', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: notesEditCtrl,
                  maxLines: 3,
                  decoration: const InputDecoration(
                      labelText: 'Notes', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 12),
                const Text('Flavor Profile',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 6,
                  children: tempFlavors
                      .map((f) => Chip(
                            label: Text(f),
                            onDeleted: () =>
                                setDialogState(() => tempFlavors.remove(f)),
                          ))
                      .toList(),
                ),
                Row(children: [
                  Expanded(
                    child: TextField(
                      controller: flavorEdit,
                      decoration: const InputDecoration(
                          hintText: 'Add flavor note',
                          border: OutlineInputBorder(),
                          isDense: true),
                    ),
                  ),
                  const SizedBox(width: 6),
                  IconButton(
                    icon: const Icon(Icons.add, color: Colors.brown),
                    onPressed: () {
                      final v = flavorEdit.text.trim();
                      if (v.isNotEmpty) {
                        setDialogState(() => tempFlavors.add(v));
                        flavorEdit.clear();
                      }
                    },
                  ),
                ]),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
            ElevatedButton(
              onPressed: () async {
                await DatabaseHelper.instance.updateRoastDetails(
                  roast['id'] as int,
                  {
                    'notes': notesEditCtrl.text,
                    'region': regionEditCtrl.text,
                    'flavor_profile': tempFlavors.join(','),
                  },
                );
                if (ctx.mounted) Navigator.pop(ctx);
                _refresh();
                _snack("Updated!");
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
          Expanded(child: _field(regionCtrl, 'Region')),
          const SizedBox(width: 10),
          Expanded(child: _numField(weightCtrl, 'Weight (g)')),
        ]),
        Row(children: [
          Expanded(child: _numField(priceCtrl, 'Price Paid')),
          const SizedBox(width: 10),
          Expanded(child: Container()), // spacer
        ]),
        _field(notesCtrl, 'Notes'),

        // Flavor profile input
        Row(children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: TextField(
                controller: flavorInputCtrl,
                decoration: const InputDecoration(
                    labelText: 'Add Flavor Note',
                    border: OutlineInputBorder(),
                    isDense: true),
                onSubmitted: (_) => _addFlavor(),
              ),
            ),
          ),
          const SizedBox(width: 6),
          IconButton(
            icon: const Icon(Icons.add, color: Colors.brown),
            onPressed: _addFlavor,
          ),
        ]),
        if (_flavorTags.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Wrap(
              spacing: 6,
              children: _flavorTags
                  .map((f) => Chip(
                        label: Text(f),
                        onDeleted: () => setState(() => _flavorTags.remove(f)),
                      ))
                  .toList(),
            ),
          ),

        Row(children: [
          const Text("Rating: "),
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
    final remaining = (r['remaining_weight'] as num?)?.toStringAsFixed(1) ?? '0';
    final total = (r['total_weight'] as num?)?.toStringAsFixed(1) ?? '0';
    final rating = (r['rating'] as num?)?.toStringAsFixed(1) ?? '?';
    final pct = (r['total_weight'] != null && (r['total_weight'] as num) > 0)
        ? ((r['remaining_weight'] as num? ?? 0) /
                (r['total_weight'] as num) *
                100)
            .toStringAsFixed(0)
        : '?';

    final flavors = ((r['flavor_profile'] as String?) ?? '')
        .split(',')
        .where((s) => s.isNotEmpty)
        .toList();

    // Cost per gram → estimated cost per shot (assuming ~18g dose)
    String? costInfo;
    final price = (r['price'] as num?)?.toDouble();
    final totalW = (r['total_weight'] as num?)?.toDouble();
    if (price != null && price > 0 && totalW != null && totalW > 0) {
      final costPerGram = price / totalW;
      final costPerShot = costPerGram * 18;
      costInfo =
          '${price.toStringAsFixed(2)} total  ·  ~${costPerShot.toStringAsFixed(2)} / shot';
    }

    final subtitleParts = <String>[];
    subtitleParts.add('${remaining}g / ${total}g  ($pct% left)');
    if (costInfo != null) subtitleParts.add(costInfo);
    if ((r['region'] as String?)?.isNotEmpty == true) {
      subtitleParts.add('Region: ${r['region']}');
    }
    if (flavors.isNotEmpty) {
      subtitleParts.add('Flavors: ${flavors.join(', ')}');
    }
    if ((r['notes'] as String?)?.isNotEmpty == true) {
      subtitleParts.add(r['notes'] as String);
    }
    subtitleParts.add(dateStr);

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
        subtitle: Text(subtitleParts.join('\n')),
        isThreeLine: true,
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.edit_note, color: Colors.brown),
              tooltip: 'Edit notes',
              onPressed: () => _editNotes(r),
            ),
            IconButton(
              icon: const Icon(Icons.delete, color: Colors.red),
              onPressed: () => _deleteRoast(r['id']),
            ),
          ],
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

  Widget _numField(TextEditingController c, String label) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: TextField(
          controller: c,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
              labelText: label, border: const OutlineInputBorder()),
        ),
      );
}
