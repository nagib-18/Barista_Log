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
  double _rating = 3.0;
  List<Map<String, dynamic>> logs = [];

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
    if (!mounted) return;
    setState(() => logs = data);
  }

  void _addCoffee() async {
    if (cafeCtrl.text.isEmpty) {
      _snack("Cafe name is required!");
      return;
    }
    await DatabaseHelper.instance.insertExternal({
      'blend': blendCtrl.text,
      'cafe': cafeCtrl.text,
      'city': cityCtrl.text,
      'country': countryCtrl.text,
      'notes': notesCtrl.text,
      'rating': _rating,
      'date': DateTime.now().toIso8601String(),
    });
    cafeCtrl.clear();
    blendCtrl.clear();
    cityCtrl.clear();
    countryCtrl.clear();
    notesCtrl.clear();
    setState(() => _rating = 3.0);
    _refresh();
    _snack("Visit logged!");
  }

  void _deleteEntry(int id) async {
    await DatabaseHelper.instance.deleteItem(id, 'external_coffee');
    _refresh();
    _snack("Deleted!");
  }

  void _exportCSV() async {
    List<List<dynamic>> rows = [
      ["ID", "Blend", "Cafe", "City", "Country", "Notes", "Rating", "Date"]
    ];
    for (var r in logs) {
      rows.add([
        r['id'],
        r['blend'],
        r['cafe'],
        r['city'],
        r['country'],
        r['notes'],
        r['rating'],
        r['date'],
      ]);
    }
    final csv = const ListToCsvConverter().convert(rows);
    final dir = await getTemporaryDirectory();
    final path = "${dir.path}/cafe_visits_logs.csv";
    await File(path).writeAsString(csv);
    await Share.shareXFiles([XFile(path)], text: 'Cafe visit logs');
  }

  void _snack(String msg) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(children: [
          Expanded(child: _field(cafeCtrl, 'Cafe Name *')),
          const SizedBox(width: 10),
          Expanded(child: _field(blendCtrl, 'Blend')),
        ]),
        Row(children: [
          Expanded(child: _field(cityCtrl, 'City')),
          const SizedBox(width: 10),
          Expanded(child: _field(countryCtrl, 'Country')),
        ]),
        _field(notesCtrl, 'Notes'),
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

  Widget _buildLogTile(Map<String, dynamic> item) {
    final date = DateTime.tryParse(item['date'] ?? '');
    final dateStr = date != null ? DateFormat('MM/dd HH:mm').format(date) : '';
    final title = '${item['cafe'] ?? ''} (${item['city'] ?? ''})';

    final parts = <String>[];
    if (item['blend'] != null && item['blend'].toString().isNotEmpty) {
      parts.add(item['blend']);
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
            (item['rating'] as num).toStringAsFixed(1),
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
