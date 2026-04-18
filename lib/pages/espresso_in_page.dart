import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:csv/csv.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../db_helper.dart';

// Dial-in taste outcomes with adjustment suggestions
const _tasteTags = ['Sour', 'Slightly Sour', 'Balanced', 'Slightly Bitter', 'Bitter'];

const _dialInSuggestions = {
  'Sour': ['Grind finer', 'Increase dose', 'Extend time', 'Raise temp'],
  'Slightly Sour': ['Grind slightly finer', 'Add 0.5g dose', 'Extend by 2s'],
  'Balanced': ['Recipe locked in', 'Save as reference'],
  'Slightly Bitter': ['Grind slightly coarser', 'Reduce dose by 0.5g', 'Shorten by 2s'],
  'Bitter': ['Grind coarser', 'Reduce dose', 'Shorten time', 'Lower temp'],
};

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
  final grindCtrl = TextEditingController();
  final brewTempCtrl = TextEditingController();

  double _rating = 3.0;
  double? _ratio;
  String? _tasteTag;
  int? _selectedRoastId;
  List<Map<String, dynamic>> logs = [];
  List<Map<String, dynamic>> roasts = [];

  // ── Shot timer ──
  Timer? _timer;
  int _timerSeconds = 0;
  bool _timerRunning = false;

  @override
  void initState() {
    super.initState();
    _loadDefaultTemp();
    _refresh();
  }

  @override
  void dispose() {
    _timer?.cancel();
    shotCtrl.dispose();
    brandCtrl.dispose();
    blendCtrl.dispose();
    reviewCtrl.dispose();
    weightInCtrl.dispose();
    weightOutCtrl.dispose();
    grindCtrl.dispose();
    brewTempCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadDefaultTemp() async {
    final t = await DatabaseHelper.instance.getSetting('default_brew_temp');
    if (!mounted) return;
    brewTempCtrl.text = t ?? '93';
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

  void _startTimer() {
    _timer?.cancel();
    setState(() => _timerRunning = true);
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() => _timerSeconds++);
    });
  }

  void _stopTimer() {
    _timer?.cancel();
    setState(() => _timerRunning = false);
  }

  void _resetTimer() {
    _timer?.cancel();
    setState(() {
      _timerRunning = false;
      _timerSeconds = 0;
    });
  }

  String _formatTimer(int s) =>
      '${(s ~/ 60).toString().padLeft(2, '0')}:${(s % 60).toString().padLeft(2, '0')}';

  void _addCoffee() async {
    if (shotCtrl.text.isEmpty) {
      _snack("Shot type is required!");
      return;
    }

    final wIn = double.tryParse(weightInCtrl.text);
    final wOut = double.tryParse(weightOutCtrl.text);
    final brewTemp = double.tryParse(brewTempCtrl.text);
    double? ratio;
    if (wIn != null && wIn > 0 && wOut != null && wOut > 0) {
      ratio = wOut / wIn;
    }

    try {
      await DatabaseHelper.instance.insertHome({
        'shot': shotCtrl.text.trim(),
        'brand': brandCtrl.text,
        'blend': blendCtrl.text,
        'review': reviewCtrl.text,
        'rating': _rating,
        'date': DateTime.now().toIso8601String(),
        'weight_in': wIn,
        'weight_out': wOut,
        'ratio': ratio,
        'roast_id': _selectedRoastId,
        'shot_time': _timerSeconds > 0 ? _timerSeconds : null,
        'grind_setting': grindCtrl.text.trim().isNotEmpty ? grindCtrl.text.trim() : null,
        'brew_temp': brewTemp,
        'taste_tag': _tasteTag,
      });

      if (_selectedRoastId != null && wIn != null && wIn > 0) {
        await DatabaseHelper.instance.updateRoastWeight(_selectedRoastId!, wIn);
      }

      final reminderOn =
          await DatabaseHelper.instance.getSetting('cleaning_reminder');
      if (reminderOn != 'false') {
        int count = await DatabaseHelper.instance.getShotsSinceReset();
        if (count > 0 && count % 120 == 0 && mounted) _cleaningAlert(count);
      }

      shotCtrl.clear();
      brandCtrl.clear();
      blendCtrl.clear();
      reviewCtrl.clear();
      weightInCtrl.clear();
      weightOutCtrl.clear();
      grindCtrl.clear();
      setState(() {
        _rating = 3.0;
        _ratio = null;
        _selectedRoastId = null;
        _tasteTag = null;
      });
      _resetTimer();
      // Re-load default temp for next shot
      _loadDefaultTemp();
      _refresh();
      _snack("Shot logged!");
    } catch (e) {
      _snack("Error saving shot: $e");
    }
  }

  void _deleteEntry(Map<String, dynamic> item) async {
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
        "ID", "Shot", "Brand", "Blend", "Review", "Rating",
        "Weight In", "Weight Out", "Ratio", "Shot Time (s)",
        "Grind Setting", "Brew Temp (°C)", "Taste Tag", "Date"
      ]
    ];
    for (var r in logs) {
      rows.add([
        r['id'], r['shot'], r['brand'], r['blend'], r['review'], r['rating'],
        r['weight_in'], r['weight_out'], r['ratio'], r['shot_time'],
        r['grind_setting'], r['brew_temp'], r['taste_tag'], r['date'],
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
          content: Text(
              "$count shots since last reset.\nTime to clean your machine!"),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("OK"))
          ],
        ),
      );

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
                      '${r['brand'] ?? ''} – ${r['blend'] ?? ''} (${(r['remaining_weight'] as num?)?.toStringAsFixed(1) ?? '?'}g)'),
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

        Row(children: [
          Expanded(child: _field(grindCtrl, 'Grind Setting')),
          const SizedBox(width: 10),
          Expanded(child: _numField(brewTempCtrl, 'Brew Temp (°C)')),
        ]),

        // Shot timer
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Container(
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey),
              borderRadius: BorderRadius.circular(4),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                const Icon(Icons.timer, color: Colors.brown),
                const SizedBox(width: 8),
                Text(
                  _formatTimer(_timerSeconds),
                  style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      fontFeatures: [FontFeature.tabularFigures()]),
                ),
                const Spacer(),
                if (!_timerRunning)
                  IconButton(
                    icon: const Icon(Icons.play_arrow, color: Colors.brown),
                    tooltip: 'Start',
                    onPressed: _startTimer,
                  ),
                if (_timerRunning)
                  IconButton(
                    icon: const Icon(Icons.stop, color: Colors.brown),
                    tooltip: 'Stop',
                    onPressed: _stopTimer,
                  ),
                IconButton(
                  icon: const Icon(Icons.refresh, color: Colors.grey),
                  tooltip: 'Reset',
                  onPressed: _resetTimer,
                ),
              ],
            ),
          ),
        ),

        _field(reviewCtrl, 'Review'),

        // Taste tag — dial-in outcome picker
        Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Text('Taste Outcome (optional)',
              style: TextStyle(color: Colors.grey[700], fontSize: 13)),
        ),
        Wrap(
          spacing: 6,
          runSpacing: 4,
          children: _tasteTags.map((tag) {
            final selected = _tasteTag == tag;
            return ChoiceChip(
              label: Text(tag),
              selected: selected,
              selectedColor: tag == 'Balanced'
                  ? Colors.green[100]
                  : tag.contains('Bitter')
                      ? Colors.orange[100]
                      : Colors.blue[100],
              onSelected: (_) =>
                  setState(() => _tasteTag = selected ? null : tag),
              labelStyle: TextStyle(
                  color: selected ? Colors.brown[900] : null,
                  fontWeight:
                      selected ? FontWeight.bold : FontWeight.normal),
            );
          }).toList(),
        ),
        // Dial-in suggestions
        if (_tasteTag != null && _tasteTag != 'Balanced') ...[
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: [
              for (final s in _dialInSuggestions[_tasteTag] ?? [])
                Chip(
                  avatar: const Icon(Icons.tips_and_updates,
                      size: 14, color: Colors.brown),
                  label: Text(s,
                      style: const TextStyle(fontSize: 12)),
                  backgroundColor: Colors.brown[50],
                ),
            ],
          ),
        ],
        if (_tasteTag == 'Balanced')
          Padding(
            padding: const EdgeInsets.only(top: 4, bottom: 4),
            child: Row(children: [
              const Icon(Icons.check_circle, color: Colors.green, size: 16),
              const SizedBox(width: 4),
              Text('Recipe locked in!',
                  style: TextStyle(
                      color: Colors.green[700], fontWeight: FontWeight.bold)),
            ]),
          ),
        const SizedBox(height: 4),

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

    final parts = <String>[];

    // Shot type + grind + temp on one line
    final shotLine = StringBuffer(item['shot'] ?? '');
    if (item['grind_setting'] != null &&
        item['grind_setting'].toString().isNotEmpty) {
      shotLine.write('  ·  Grind ${item['grind_setting']}');
    }
    if (item['brew_temp'] != null) {
      shotLine.write('  ·  ${(item['brew_temp'] as num).toStringAsFixed(1)}°C');
    }
    parts.add(shotLine.toString());

    if (item['review'] != null && item['review'].toString().isNotEmpty) {
      parts.add(item['review']);
    }
    if (item['weight_in'] != null || item['weight_out'] != null) {
      final wIn = (item['weight_in'] as num?)?.toStringAsFixed(1) ?? '?';
      final wOut = (item['weight_out'] as num?)?.toStringAsFixed(1) ?? '?';
      var w = '${wIn}g → ${wOut}g';
      if (item['ratio'] != null) {
        w += '  (1:${(item['ratio'] as num).toStringAsFixed(1)})';
      }
      parts.add(w);
    }
    if (item['shot_time'] != null && (item['shot_time'] as int) > 0) {
      parts.add('Time: ${_formatTimer(item['shot_time'] as int)}');
    }
    if (item['taste_tag'] != null &&
        item['taste_tag'].toString().isNotEmpty) {
      parts.add('Taste: ${item['taste_tag']}');
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
