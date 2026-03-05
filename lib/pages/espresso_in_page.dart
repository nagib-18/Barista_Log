import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:csv/csv.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../db_helper.dart';

class EspressoInPage extends StatefulWidget {
  const EspressoInPage({super.key});
  @override
  State<EspressoInPage> createState() => _EspressoInPageState();
}

class _EspressoInPageState extends State<EspressoInPage> {
  final shotCtrl = TextEditingController();
  final brandCtrl = TextEditingController();
  final blendCtrl = TextEditingController();
  final reviewCtrl = TextEditingController();
  final weightInCtrl = TextEditingController();
  final weightOutCtrl = TextEditingController();

  double _rating = 3.0;
  double? _ratio;
  int? _selectedRoastId;
  List<Map<String, dynamic>> logs = [];
  List<Map<String, dynamic>> roasts = [];

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  @override
  void dispose() {
    shotCtrl.dispose();
    brandCtrl.dispose();
    blendCtrl.dispose();
    reviewCtrl.dispose();
    weightInCtrl.dispose();
    weightOutCtrl.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    final data = await DatabaseHelper.instance.getHomeLogs();
    final roastData = await DatabaseHelper.instance.getActiveRoasts();
    if (!mounted) return;
    setState(() {
      logs = data;
      roasts = roastData;
    });
  }

  void _calcRatio() {
    final wIn = double.tryParse(weightInCtrl.text);
    final wOut = double.tryParse(weightOutCtrl.text);
    setState(() {
      _ratio = (wIn != null && wIn > 0 && wOut != null && wOut > 0)
          ? wOut / wIn
          : null;
    });
  }

  void _addCoffee() async {
    if (shotCtrl.text.isEmpty) {
      _snack("Shot type is required!");
      return;
    }

    final wIn = double.tryParse(weightInCtrl.text);
    final wOut = double.tryParse(weightOutCtrl.text);
    double? ratio;
    if (wIn != null && wIn > 0 && wOut != null && wOut > 0) {
      ratio = wOut / wIn;
    }

    try {
      await DatabaseHelper.instance.insertHome({
        'shot': shotCtrl.text,
        'brand': brandCtrl.text,
        'blend': blendCtrl.text,
        'review': reviewCtrl.text,
        'rating': _rating,
        'date': DateTime.now().toIso8601String(),
        'weight_in': wIn,
        'weight_out': wOut,
        'ratio': ratio,
        'roast_id': _selectedRoastId,
      });

      // Deduct weight from selected roast
      if (_selectedRoastId != null && wIn != null && wIn > 0) {
        await DatabaseHelper.instance.updateRoastWeight(_selectedRoastId!, wIn);
      }

      // Cleaning reminder check
      final reminderOn =
          await DatabaseHelper.instance.getSetting('cleaning_reminder');
      if (reminderOn != 'false') {
        int count = await DatabaseHelper.instance.getHomeCount();
        if (count % 120 == 0 && mounted) _cleaningAlert(count);
      }

      shotCtrl.clear();
      brandCtrl.clear();
      blendCtrl.clear();
      reviewCtrl.clear();
      weightInCtrl.clear();
      weightOutCtrl.clear();
      setState(() {
        _rating = 3.0;
        _ratio = null;
        _selectedRoastId = null;
      });
      _refresh();
      _snack("Shot logged!");
    } catch (e) {
      _snack("Error saving shot: $e");
    }
  }

  void _deleteEntry(Map<String, dynamic> item) async {
    // Restore roast weight if this shot was linked to a roast
    if (item['roast_id'] != null && item['weight_in'] != null) {
      await DatabaseHelper.instance.restoreRoastWeight(
        item['roast_id'] as int,
        (item['weight_in'] as num).toDouble(),
      );
    }
    await DatabaseHelper.instance.deleteItem(item['id'], 'home_coffee');
    _refresh();
    _snack("Deleted!");
  }

  void _exportCSV() async {
    List<List<dynamic>> rows = [
      [
        "ID",
        "Shot",
        "Brand",
        "Blend",
        "Review",
        "Rating",
        "Weight In",
        "Weight Out",
        "Ratio",
        "Date"
      ]
    ];
    for (var r in logs) {
      rows.add([
        r['id'],
        r['shot'],
        r['brand'],
        r['blend'],
        r['review'],
        r['rating'],
        r['weight_in'],
        r['weight_out'],
        r['ratio'],
        r['date'],
      ]);
    }
    final csv = const ListToCsvConverter().convert(rows);
    final dir = await getTemporaryDirectory();
    final path = "${dir.path}/home_coffee_logs.csv";
    await File(path).writeAsString(csv);
    await Share.shareXFiles([XFile(path)], text: 'Home coffee logs');
  }

  void _onRoastSelected(int? id) {
    if (id == null) {
      setState(() => _selectedRoastId = null);
      brandCtrl.clear();
      blendCtrl.clear();
      return;
    }
    final roast = roasts.firstWhere((r) => r['id'] == id);
    setState(() => _selectedRoastId = id);
    brandCtrl.text = roast['brand'] ?? '';
    blendCtrl.text = roast['blend'] ?? '';
  }

  void _snack(String msg) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

  void _cleaningAlert(int count) => showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text("⚠️ CLEAN MACHINE"),
          content: Text("$count shots reached.\nTime to clean your machine!"),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("OK"))
          ],
        ),
      );

  // ── BUILD ───────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Roast selector
        DropdownButtonFormField<int?>(
          value: _selectedRoastId,
          decoration: const InputDecoration(
            labelText: 'Select Roast (optional)',
            border: OutlineInputBorder(),
          ),
          items: [
            const DropdownMenuItem<int?>(value: null, child: Text('None')),
            ...roasts.map((r) => DropdownMenuItem<int?>(
                  value: r['id'] as int,
                  child: Text(
                      '${r['brand'] ?? ''} – ${r['blend'] ?? ''} (${(r['remaining_weight'] as num?)?.toStringAsFixed(0) ?? '?'}g)'),
                )),
          ],
          onChanged: _onRoastSelected,
        ),
        const SizedBox(height: 8),

        _field(shotCtrl, 'Shot Type *'),

        Row(children: [
          Expanded(child: _field(brandCtrl, 'Brand')),
          const SizedBox(width: 10),
          Expanded(child: _field(blendCtrl, 'Blend')),
        ]),

        // Weight + ratio
        Row(children: [
          Expanded(child: _numField(weightInCtrl, 'Dose In (g)')),
          const SizedBox(width: 10),
          Expanded(child: _numField(weightOutCtrl, 'Yield Out (g)')),
        ]),
        if (_ratio != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              'Ratio  1 : ${_ratio!.toStringAsFixed(1)}',
              style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: Colors.brown),
            ),
          ),

        _field(reviewCtrl, 'Review'),

        // Rating slider (0.5 increments)
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
          Text("${_rating.toStringAsFixed(1)}/5"),
        ]),

        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _addCoffee,
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.brown, foregroundColor: Colors.white),
            child: const Text("Log Home Shot"),
          ),
        ),

        Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(
            onPressed: _exportCSV,
            icon: const Icon(Icons.download, size: 18),
            label: const Text("Export CSV"),
          ),
        ),
        const Divider(thickness: 2),

        // Log entries
        ...logs.map(_buildLogTile),
      ],
    );
  }

  Widget _buildLogTile(Map<String, dynamic> item) {
    final date = DateTime.tryParse(item['date'] ?? '');
    final dateStr = date != null ? DateFormat('MM/dd HH:mm').format(date) : '';

    String title = [item['brand'], item['blend']]
        .where((s) => s != null && s.toString().isNotEmpty)
        .join(' – ');
    if (title.isEmpty) title = item['shot'] ?? 'Shot';

    final parts = <String>[item['shot'] ?? ''];
    if (item['review'] != null && item['review'].toString().isNotEmpty) {
      parts.add(item['review']);
    }
    if (item['weight_in'] != null || item['weight_out'] != null) {
      var w = '${item['weight_in'] ?? '?'}g → ${item['weight_out'] ?? '?'}g';
      if (item['ratio'] != null) {
        w += '  (1:${(item['ratio'] as num).toStringAsFixed(1)})';
      }
      parts.add(w);
    }
    parts.add(dateStr);

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Colors.brown,
          child: Text(
            (item['rating'] as num).toStringAsFixed(1),
            style: const TextStyle(color: Colors.white, fontSize: 11),
          ),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(parts.join('\n')),
        isThreeLine: true,
        trailing: IconButton(
          icon: const Icon(Icons.delete, color: Colors.red),
          onPressed: () => _deleteEntry(item),
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
          onChanged: (_) => _calcRatio(),
        ),
      );
}
