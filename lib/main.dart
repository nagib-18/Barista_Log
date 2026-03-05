import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:csv/csv.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'db_helper.dart';

void main() {
  runApp(const MaterialApp(
    debugShowCheckedModeBanner: false,
    home: CoffeeRatingsApp(),
  ));
}

class CoffeeRatingsApp extends StatefulWidget {
  const CoffeeRatingsApp({super.key});

  @override
  State<CoffeeRatingsApp> createState() => _CoffeeRatingsAppState();
}

class _CoffeeRatingsAppState extends State<CoffeeRatingsApp>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // --- HOME CONTROLLERS ---
  final TextEditingController homeShotCtrl = TextEditingController();
  final TextEditingController homeBrandCtrl = TextEditingController();
  final TextEditingController homeBlendCtrl = TextEditingController();
  final TextEditingController homeReviewCtrl = TextEditingController();
  double _homeRating = 3.0;
  List<Map<String, dynamic>> homeLogs = [];

  // --- EXTERNAL CONTROLLERS ---
  final TextEditingController extBlendCtrl = TextEditingController();
  final TextEditingController extCafeCtrl = TextEditingController();
  final TextEditingController extCityCtrl = TextEditingController();
  final TextEditingController extCountryCtrl = TextEditingController();
  final TextEditingController extNotesCtrl = TextEditingController();
  double _extRating = 3.0;
  List<Map<String, dynamic>> extLogs = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _refreshAll();
  }

  void _refreshAll() async {
    final hData = await DatabaseHelper.instance.getHomeLogs();
    final eData = await DatabaseHelper.instance.getExternalLogs();
    setState(() {
      homeLogs = hData;
      extLogs = eData;
    });
  }

  // --- LOGIC: ADD HOME COFFEE ---
  void _addHomeCoffee() async {
    if (homeShotCtrl.text.isEmpty || homeBrandCtrl.text.isEmpty) {
      _showSnack("Enter Shot and Brand!");
      return;
    }
    await DatabaseHelper.instance.insertHome({
      'shot': homeShotCtrl.text,
      'brand': homeBrandCtrl.text,
      'blend': homeBlendCtrl.text,
      'review': homeReviewCtrl.text,
      'rating': _homeRating.toInt(),
      'date': DateTime.now().toIso8601String(),
    });

    // Check for cleaning reminder
    int count = await DatabaseHelper.instance.getHomeCount();
    if (count % 120 == 0) _showCleaningAlert(count);

    // Clear and Refresh
    homeShotCtrl.clear();
    homeBrandCtrl.clear();
    homeBlendCtrl.clear();
    homeReviewCtrl.clear();
    setState(() => _homeRating = 3.0);
    _refreshAll();
  }

  // --- LOGIC: ADD EXTERNAL COFFEE ---
  void _addExternalCoffee() async {
    if (extCafeCtrl.text.isEmpty || extCityCtrl.text.isEmpty) {
      _showSnack("Enter Cafe and City!");
      return;
    }
    await DatabaseHelper.instance.insertExternal({
      'blend': extBlendCtrl.text,
      'cafe': extCafeCtrl.text,
      'city': extCityCtrl.text,
      'country': extCountryCtrl.text,
      'notes': extNotesCtrl.text,
      'rating': _extRating.toInt(),
      'date': DateTime.now().toIso8601String(),
    });

    // Clear and Refresh
    extBlendCtrl.clear();
    extCafeCtrl.clear();
    extCityCtrl.clear();
    extCountryCtrl.clear();
    extNotesCtrl.clear();
    setState(() => _extRating = 3.0);
    _refreshAll();
  }

  // --- LOGIC: DELETE ---
  void _deleteEntry(int id, String table) async {
    await DatabaseHelper.instance.deleteItem(id, table);
    _refreshAll();
    _showSnack("Deleted!");
  }

  // --- LOGIC: EXPORT CSV ---
  void _exportCSV(String type) async {
    List<Map<String, dynamic>> data;
    String fileName;
    List<List<dynamic>> rows = [];

    if (type == 'home') {
      data = homeLogs;
      fileName = "home_coffee_logs.csv";
      rows.add(["ID", "Shot", "Brand", "Blend", "Review", "Rating", "Date"]);
      for (var row in data) {
        rows.add([
          row['id'],
          row['shot'],
          row['brand'],
          row['blend'],
          row['review'],
          row['rating'],
          row['date']
        ]);
      }
    } else {
      data = extLogs;
      fileName = "cafe_visits_logs.csv";
      rows.add([
        "ID",
        "Blend",
        "Cafe",
        "City",
        "Country",
        "Notes",
        "Rating",
        "Date"
      ]);
      for (var row in data) {
        rows.add([
          row['id'],
          row['blend'],
          row['cafe'],
          row['city'],
          row['country'],
          row['notes'],
          row['rating'],
          row['date']
        ]);
      }
    }

    String csvData = const ListToCsvConverter().convert(rows);
    final directory = await getTemporaryDirectory();
    final path = "${directory.path}/$fileName";
    final file = File(path);
    await file.writeAsString(csvData);
    await Share.shareXFiles([XFile(path)], text: 'Exporting $type logs');
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  void _showCleaningAlert(int count) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("⚠️ CLEAN MACHINE"),
        content: Text("Count: $count shots.\nTime to clean!"),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context), child: const Text("OK"))
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Coffee Ratings"),
        backgroundColor: Colors.brown,
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(icon: Icon(Icons.coffee_maker), text: "Home"),
            Tab(icon: Icon(Icons.store), text: "Out"),
          ],
        ),
        actions: [
          PopupMenuButton<String>(
            onSelected: _exportCSV,
            itemBuilder: (context) => [
              const PopupMenuItem(
                  value: 'home', child: Text("Export Home Logs")),
              const PopupMenuItem(
                  value: 'external', child: Text("Export Cafe Logs")),
            ],
            icon: const Icon(Icons.download),
          )
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // --- TAB 1: HOME ---
          _buildTab(
            inputs: [
              _txt(homeShotCtrl, 'Shot Type'),
              _row(_txt(homeBrandCtrl, 'Brand'), _txt(homeBlendCtrl, 'Blend')),
              _txt(homeReviewCtrl, 'Review'),
              _slider((v) => setState(() => _homeRating = v), _homeRating),
              _btn("Log Home Shot", _addHomeCoffee),
            ],
            list: homeLogs,
            isHome: true,
          ),

          // --- TAB 2: EXTERNAL ---
          _buildTab(
            inputs: [
              _row(_txt(extCafeCtrl, 'Cafe Name'), _txt(extBlendCtrl, 'Blend')),
              _row(_txt(extCityCtrl, 'City'), _txt(extCountryCtrl, 'Country')),
              _txt(extNotesCtrl, 'Notes'),
              _slider((v) => setState(() => _extRating = v), _extRating),
              _btn("Log Cafe Visit", _addExternalCoffee),
            ],
            list: extLogs,
            isHome: false,
          ),
        ],
      ),
    );
  }

  // --- HELPER WIDGETS ---
  Widget _buildTab(
      {required List<Widget> inputs,
      required List<Map<String, dynamic>> list,
      required bool isHome}) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(children: inputs),
        ),
        const Divider(thickness: 2),
        Expanded(
          child: ListView.builder(
            itemCount: list.length,
            itemBuilder: (context, index) {
              final item = list[index];
              final date = DateTime.parse(item['date']);
              final dateStr = DateFormat('MM/dd HH:mm').format(date);

              // Define subtitles based on which tab we are in
              String title = isHome
                  ? "${item['brand']} - ${item['blend']}"
                  : "${item['cafe']} (${item['city']})";
              String subtitle = isHome
                  ? "${item['shot']}\n${item['review']}"
                  : "${item['blend']}\n${item['notes']}";

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Colors.brown,
                    child: Text("${item['rating']}",
                        style: const TextStyle(color: Colors.white)),
                  ),
                  title: Text(title,
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text("$subtitle\n$dateStr"),
                  isThreeLine: true,
                  trailing: IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    onPressed: () => _deleteEntry(
                        item['id'], isHome ? 'home_coffee' : 'external_coffee'),
                  ),
                ),
              );
            },
          ),
        )
      ],
    );
  }

  Widget _txt(TextController ctrl, String label) => Padding(
        padding: const EdgeInsets.only(bottom: 8.0),
        child: TextField(
            controller: ctrl,
            decoration: InputDecoration(
                labelText: label, border: const OutlineInputBorder())),
      );

  Widget _row(Widget w1, Widget w2) => Row(children: [
        Expanded(child: w1),
        const SizedBox(width: 10),
        Expanded(child: w2)
      ]);

  Widget _slider(Function(double) onChange, double val) => Row(
        children: [
          const Text("Rating: "),
          Expanded(
              child: Slider(
                  value: val,
                  min: 1,
                  max: 5,
                  divisions: 4,
                  label: val.round().toString(),
                  onChanged: onChange,
                  activeColor: Colors.brown)),
          Text("${val.toInt()}/5"),
        ],
      );

  Widget _btn(String text, VoidCallback press) => SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: press,
          style: ElevatedButton.styleFrom(
              backgroundColor: Colors.brown, foregroundColor: Colors.white),
          child: Text(text),
        ),
      );
}

// Just a type alias to make the helper method cleaner
typedef TextController = TextEditingController;
