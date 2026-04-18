import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:csv/csv.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../db_helper.dart';

class EspressoOutPage extends StatefulWidget {
  const EspressoOutPage({super.key});
  @override
  State<EspressoOutPage> createState() => _EspressoOutPageState();
}

class _EspressoOutPageState extends State<EspressoOutPage> {
  final cafeCtrl = TextEditingController();
  final blendCtrl = TextEditingController();
  final cityCtrl = TextEditingController();
  final countryCtrl = TextEditingController();
  final notesCtrl = TextEditingController();

  double _ratingVibes = 3.0;
  double _ratingCoffee = 3.0;
  double _ratingService = 3.0;
  double _ratingPrice = 3.0;

  List<Map<String, dynamic>> logs = [];
  List<String> _savedCafes = [];

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  @override
  void dispose() {
    cafeCtrl.dispose();
    blendCtrl.dispose();
    cityCtrl.dispose();
    countryCtrl.dispose();
    notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    final data = await DatabaseHelper.instance.getExternalLogs();
    final cafes = await DatabaseHelper.instance.getDistinctCafes();
    if (!mounted) return;
    setState(() {
      logs = data;
      _savedCafes = cafes;
    });
  }

  double get _overallRating =>
      (_ratingVibes + _ratingCoffee + _ratingService + _ratingPrice) / 4.0;

  void _addCoffee() async {
    if (cafeCtrl.text.isEmpty) {
      _snack("Cafe name is required!");
      return;
    }
    try {
      await DatabaseHelper.instance.insertExternal({
        'blend': blendCtrl.text,
        'cafe': cafeCtrl.text,
        'city': cityCtrl.text,
        'country': countryCtrl.text,
        'notes': notesCtrl.text,
        'rating': _overallRating,
        'rating_vibes': _ratingVibes,
        'rating_coffee': _ratingCoffee,
        'rating_service': _ratingService,
        'rating_price': _ratingPrice,
        'date': DateTime.now().toIso8601String(),
      });
      cafeCtrl.clear();
      blendCtrl.clear();
      cityCtrl.clear();
      countryCtrl.clear();
      notesCtrl.clear();
      setState(() {
        _ratingVibes = 3.0;
        _ratingCoffee = 3.0;
        _ratingService = 3.0;
        _ratingPrice = 3.0;
      });
      _refresh();
      _snack("Visit logged!");
    } catch (e) {
      _snack("Error logging visit: $e");
    }
  }

  void _deleteEntry(int id) async {
    await DatabaseHelper.instance.deleteItem(id, 'external_coffee');
    _refresh();
    _snack("Deleted!");
  }

  void _exportCSV() async {
    List<List<dynamic>> rows = [
      [
        "ID", "Blend", "Cafe", "City", "Country", "Notes",
        "Vibes", "Coffee", "Service", "Price", "Overall", "Date"
      ]
    ];
    for (var r in logs) {
      rows.add([
        r['id'], r['blend'], r['cafe'], r['city'], r['country'], r['notes'],
        r['rating_vibes'], r['rating_coffee'], r['rating_service'],
        r['rating_price'], r['rating'], r['date'],
      ]);
    }
    final csv = const ListToCsvConverter().convert(rows);
    final dir = await getTemporaryDirectory();
    final path = "${dir.path}/cafe_visits_logs.csv";
    await File(path).writeAsString(csv);
    await Share.shareXFiles([XFile(path)], text: 'Cafe visit logs');
  }

  void _pickSavedCafe() {
    if (_savedCafes.isEmpty) {
      _snack("No previously saved cafes.");
      return;
    }
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Select Cafe"),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: _savedCafes.length,
            itemBuilder: (_, i) => ListTile(
              title: Text(_savedCafes[i]),
              onTap: () {
                cafeCtrl.text = _savedCafes[i];
                Navigator.pop(context);
              },
            ),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel")),
        ],
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
        // Cafe name + history picker
        Row(children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: TextField(
                controller: cafeCtrl,
                decoration: const InputDecoration(
                    labelText: 'Cafe Name *',
                    border: OutlineInputBorder()),
              ),
            ),
          ),
          const SizedBox(width: 6),
          IconButton(
            icon: const Icon(Icons.history, color: Colors.brown),
            tooltip: 'Saved cafes',
            onPressed: _pickSavedCafe,
          ),
        ]),

        Row(children: [
          Expanded(child: _field(blendCtrl, 'Blend')),
          const SizedBox(width: 10),
          Expanded(child: _field(cityCtrl, 'City')),
        ]),
        _field(countryCtrl, 'Country'),
        _field(notesCtrl, 'Notes'),

        const SizedBox(height: 4),
        _ratingRow("Vibes", _ratingVibes, (v) => setState(() => _ratingVibes = v)),
        _ratingRow("Coffee", _ratingCoffee, (v) => setState(() => _ratingCoffee = v)),
        _ratingRow("Service", _ratingService, (v) => setState(() => _ratingService = v)),
        _ratingRow("Price", _ratingPrice, (v) => setState(() => _ratingPrice = v)),

        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text(
            'Overall: ${_overallRating.toStringAsFixed(1)} / 5',
            style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 15,
                color: Colors.brown),
          ),
        ),

        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _addCoffee,
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.brown, foregroundColor: Colors.white),
            child: const Text("Log Cafe Visit"),
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
        ...logs.map(_buildLogTile),
      ],
    );
  }

  Widget _ratingRow(String label, double value, ValueChanged<double> onChanged) {
    return Row(children: [
      SizedBox(width: 60, child: Text(label)),
      Expanded(
        child: Slider(
          value: value,
          min: 1,
          max: 5,
          divisions: 8,
          label: value.toStringAsFixed(1),
          onChanged: onChanged,
          activeColor: Colors.brown,
        ),
      ),
      SizedBox(
        width: 32,
        child: Text(value.toStringAsFixed(1),
            style: const TextStyle(fontSize: 12)),
      ),
    ]);
  }

  Widget _buildLogTile(Map<String, dynamic> item) {
    final date = DateTime.tryParse(item['date'] ?? '');
    final dateStr = date != null ? DateFormat('MM/dd HH:mm').format(date) : '';
    final title = '${item['cafe'] ?? ''} (${item['city'] ?? ''})';

    final overall = (item['rating'] as num?)?.toStringAsFixed(1) ?? '?';

    final parts = <String>[];
    if (item['blend'] != null && item['blend'].toString().isNotEmpty) {
      parts.add(item['blend']);
    }

    // Show individual ratings if present
    final vibes = (item['rating_vibes'] as num?)?.toStringAsFixed(1);
    final coffee = (item['rating_coffee'] as num?)?.toStringAsFixed(1);
    final service = (item['rating_service'] as num?)?.toStringAsFixed(1);
    final price = (item['rating_price'] as num?)?.toStringAsFixed(1);
    if (vibes != null) {
      parts.add('Vibes $vibes  Coffee $coffee  Service $service  Price $price');
    }

    if (item['notes'] != null && item['notes'].toString().isNotEmpty) {
      parts.add(item['notes']);
    }
    if (item['country'] != null && item['country'].toString().isNotEmpty) {
      parts.add(item['country']);
    }
    parts.add(dateStr);

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Colors.brown,
          child: Text(
            overall,
            style: const TextStyle(color: Colors.white, fontSize: 11),
          ),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(parts.join('\n')),
        isThreeLine: true,
        trailing: IconButton(
          icon: const Icon(Icons.delete, color: Colors.red),
          onPressed: () => _deleteEntry(item['id']),
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
