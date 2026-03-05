import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
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

  // ── Home filters ──
  List<String> _brands = [], _blends = [], _shots = [];
  String? _selBrand, _selBlend, _selShot;

  // ── External filters ──
  List<String> _cities = [], _countries = [];
  String? _selCity, _selCountry;

  @override
  void initState() {
    super.initState();
    _loadFilters().then((_) => _loadStats());
  }

  Future<void> _loadFilters() async {
    final db = DatabaseHelper.instance;
    final brands = await db.getDistinctHomeValues('brand');
    final blends = await db.getDistinctHomeValues('blend');
    final shots = await db.getDistinctHomeValues('shot');
    final cities = await db.getDistinctExternalValues('city');
    final countries = await db.getDistinctExternalValues('country');
    if (!mounted) return;
    setState(() {
      _brands = brands;
      _blends = blends;
      _shots = shots;
      _cities = cities;
      _countries = countries;
    });
  }

  Future<void> _loadStats() async {
    setState(() => _loading = true);
    final h = await DatabaseHelper.instance.getHomeStats(
      brand: _selBrand,
      blend: _selBlend,
      shot: _selShot,
    );
    final e = await DatabaseHelper.instance.getExternalStats(
      city: _selCity,
      country: _selCountry,
    );
    if (!mounted) return;
    setState(() {
      homeStats = h;
      extStats = e;
      _loading = false;
    });
  }

  void _resetHomeFilters() {
    setState(() {
      _selBrand = null;
      _selBlend = null;
      _selShot = null;
    });
    _loadStats();
  }

  void _resetExtFilters() {
    setState(() {
      _selCity = null;
      _selCountry = null;
    });
    _loadStats();
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
              onRefresh: () async {
                await _loadFilters();
                await _loadStats();
              },
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // ── Home Espresso filters ──
                  _sectionCard(
                    icon: Icons.filter_alt,
                    title: "Home Filters",
                    children: [
                      _dropdown('Roaster', _brands, _selBrand, (v) {
                        setState(() => _selBrand = v);
                        _loadStats();
                      }),
                      _dropdown('Blend', _blends, _selBlend, (v) {
                        setState(() => _selBlend = v);
                        _loadStats();
                      }),
                      _dropdown('Shot Type', _shots, _selShot, (v) {
                        setState(() => _selShot = v);
                        _loadStats();
                      }),
                      if (_selBrand != null ||
                          _selBlend != null ||
                          _selShot != null)
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: _resetHomeFilters,
                            child: const Text("Clear filters"),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // ── Home Espresso stats ──
                  _sectionCard(
                    icon: Icons.coffee,
                    title: "Home Espresso",
                    children: [
                      _stat("Total Shots", '${homeStats['total'] ?? 0}'),
                      _stat("Average Rating", _fmt(homeStats['avgRating'])),
                      if (homeStats['bestBlend'] != null)
                        _stat("Best Blend",
                            '${homeStats['bestBlend']}  (${_fmt(homeStats['bestBlendRating'])} avg)'),
                      if (homeStats['bestBrand'] != null)
                        _stat("Best Roaster",
                            '${homeStats['bestBrand']}  (${_fmt(homeStats['bestBrandRating'])} avg)'),
                      if ((homeStats['avgRatio'] as num?) != null &&
                          (homeStats['avgRatio'] as num) > 0)
                        _stat("Avg Ratio", '1:${_fmt(homeStats['avgRatio'])}'),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // ── External filters ──
                  _sectionCard(
                    icon: Icons.filter_alt,
                    title: "Cafe Filters",
                    children: [
                      _dropdown('City', _cities, _selCity, (v) {
                        setState(() => _selCity = v);
                        _loadStats();
                      }),
                      _dropdown('Country', _countries, _selCountry, (v) {
                        setState(() => _selCountry = v);
                        _loadStats();
                      }),
                      if (_selCity != null || _selCountry != null)
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: _resetExtFilters,
                            child: const Text("Clear filters"),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // ── Cafe Visits stats ──
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
                            '${_fmt(c['avg_r'])} avg  \u00b7  ${c['cnt']} visits',
                          ),
                      ],
                    ),
                  ],

                  // ── Buy Me a Coffee ──
                  const SizedBox(height: 24),
                  Center(
                    child: OutlinedButton.icon(
                      onPressed: () => launchUrl(
                        Uri.parse('https://buymeacoffee.com/mzcoffee'),
                        mode: LaunchMode.externalApplication,
                      ),
                      icon: const Icon(Icons.coffee, color: Colors.brown),
                      label: const Text("Buy me a coffee \u2615",
                          style: TextStyle(color: Colors.brown)),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Colors.brown),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 24, vertical: 12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
    );
  }

  // ── Helper widgets ──────────────────────────────────────────────────
  Widget _dropdown(String label, List<String> items, String? value,
      ValueChanged<String?> onChanged) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: DropdownButtonFormField<String?>(
        value: value,
        isExpanded: true,
        decoration: InputDecoration(
          labelText: label,
          isDense: true,
          border: const OutlineInputBorder(),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        ),
        items: [
          DropdownMenuItem<String?>(value: null, child: Text('All $label')),
          ...items.map((v) => DropdownMenuItem(value: v, child: Text(v))),
        ],
        onChanged: onChanged,
      ),
    );
  }

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

  String _fmt(dynamic v) =>
      v != null ? (v as num).toStringAsFixed(1) : '\u2013';
}
