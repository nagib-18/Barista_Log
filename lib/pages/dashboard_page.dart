import 'package:flutter/material.dart';
import '../db_helper.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});
  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  Map<String, dynamic> homeStats = {};
  Map<String, dynamic> extStats = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final h = await DatabaseHelper.instance.getHomeStats();
    final e = await DatabaseHelper.instance.getExternalStats();
    if (!mounted) return;
    setState(() {
      homeStats = h;
      extStats = e;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Dashboard"),
        backgroundColor: Colors.brown,
        foregroundColor: Colors.white,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Colors.brown))
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // ── Home Espresso section ──
                  _sectionCard(
                    icon: Icons.coffee,
                    title: "Home Espresso",
                    children: [
                      _stat("Total Shots", '${homeStats['total'] ?? 0}'),
                      _stat("Average Rating", _fmt(homeStats['avgRating'])),
                      if (homeStats['bestBlend'] != null)
                        _stat("Best Blend",
                            '${homeStats['bestBlend']}  (${_fmt(homeStats['bestBlendRating'])} avg)'),
                      if ((homeStats['avgRatio'] as num?) != null &&
                          (homeStats['avgRatio'] as num) > 0)
                        _stat("Avg Ratio", '1:${_fmt(homeStats['avgRatio'])}'),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // ── Cafe Visits section ──
                  _sectionCard(
                    icon: Icons.store,
                    title: "Cafe Visits",
                    children: [
                      _stat("Total Visits", '${extStats['total'] ?? 0}'),
                      _stat("Average Rating", _fmt(extStats['avgRating'])),
                      if (extStats['bestCafe'] != null)
                        _stat("Best Cafe",
                            '${extStats['bestCafe']}  (${_fmt(extStats['bestCafeRating'])} avg)'),
                      if (extStats['bestCity'] != null)
                        _stat("Best City",
                            '${extStats['bestCity']}  (${_fmt(extStats['bestCityRating'])} avg)'),
                    ],
                  ),

                  // ── Ratings by City ──
                  if ((extStats['cityRatings'] as List?)?.isNotEmpty ??
                      false) ...[
                    const SizedBox(height: 16),
                    _sectionCard(
                      icon: Icons.location_city,
                      title: "Rating by City",
                      children: [
                        for (var c in extStats['cityRatings'] as List)
                          _stat(
                            '${c['city']}',
                            '${_fmt(c['avg_r'])} avg  ·  ${c['cnt']} visits',
                          ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
    );
  }

  // ── Helper widgets ──────────────────────────────────────────────────
  Widget _sectionCard(
      {required IconData icon,
      required String title,
      required List<Widget> children}) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(icon, color: Colors.brown),
              const SizedBox(width: 8),
              Text(title,
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.bold)),
            ]),
            const Divider(),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _stat(String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Flexible(child: Text(label, style: const TextStyle(fontSize: 15))),
            Text(value,
                style:
                    const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
          ],
        ),
      );

  String _fmt(dynamic v) => v != null ? (v as num).toStringAsFixed(1) : '–';
}
