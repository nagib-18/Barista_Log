import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../db_helper.dart';

class MapPage extends StatefulWidget {
  const MapPage({super.key});
  @override
  State<MapPage> createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> {
  List<Map<String, dynamic>> _roasts = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final data = await DatabaseHelper.instance.getRoastsWithCoords();
    if (!mounted) return;
    setState(() {
      _roasts = data;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Coffee Origins'),
        backgroundColor: Colors.brown,
        foregroundColor: Colors.white,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Colors.brown))
          : _roasts.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.map_outlined,
                            size: 64, color: Colors.brown),
                        const SizedBox(height: 16),
                        const Text(
                          'No origins mapped yet.',
                          style: TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Add a roast with an Origin field\n(e.g. "Addis Ababa, Ethiopia")\nto see it pinned here.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                      ],
                    ),
                  ),
                )
              : FlutterMap(
                  options: MapOptions(
                    initialCenter: _centerOf(_roasts),
                    initialZoom: _roasts.length == 1 ? 5 : 2,
                  ),
                  children: [
                    TileLayer(
                      urlTemplate:
                          'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.example.barista_log',
                    ),
                    MarkerLayer(markers: _buildMarkers(context)),
                  ],
                ),
    );
  }

  LatLng _centerOf(List<Map<String, dynamic>> roasts) {
    if (roasts.length == 1) {
      return LatLng(
        (roasts[0]['origin_lat'] as num).toDouble(),
        (roasts[0]['origin_lng'] as num).toDouble(),
      );
    }
    final lat =
        roasts.map((r) => (r['origin_lat'] as num).toDouble()).reduce((a, b) => a + b) /
            roasts.length;
    final lng =
        roasts.map((r) => (r['origin_lng'] as num).toDouble()).reduce((a, b) => a + b) /
            roasts.length;
    return LatLng(lat, lng);
  }

  List<Marker> _buildMarkers(BuildContext context) {
    return _roasts.map((r) {
      final lat = (r['origin_lat'] as num).toDouble();
      final lng = (r['origin_lng'] as num).toDouble();
      final label = '${r['brand'] ?? ''} – ${r['blend'] ?? ''}'.trim();
      final origin = r['origin'] as String? ?? '';

      return Marker(
        point: LatLng(lat, lng),
        width: 40,
        height: 40,
        child: GestureDetector(
          onTap: () => _showInfo(context, label, origin, r),
          child: const Icon(Icons.coffee, color: Colors.brown, size: 32),
        ),
      );
    }).toList();
  }

  void _showInfo(BuildContext ctx, String label, String origin,
      Map<String, dynamic> r) {
    final remaining =
        (r['remaining_weight'] as num?)?.toStringAsFixed(1) ?? '?';
    final total = (r['total_weight'] as num?)?.toStringAsFixed(1) ?? '?';
    showModalBottomSheet(
      context: ctx,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label.isEmpty ? 'Unnamed Roast' : label,
                style:
                    const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Row(children: [
              const Icon(Icons.location_on, size: 14, color: Colors.brown),
              const SizedBox(width: 4),
              Text(origin, style: const TextStyle(color: Colors.brown)),
            ]),
            const SizedBox(height: 8),
            Text('${remaining}g / ${total}g remaining',
                style: const TextStyle(color: Colors.grey)),
            if ((r['region'] as String?)?.isNotEmpty == true)
              Text('Region: ${r['region']}',
                  style: const TextStyle(color: Colors.grey)),
            if ((r['notes'] as String?)?.isNotEmpty == true) ...[
              const SizedBox(height: 4),
              Text(r['notes'] as String),
            ],
          ],
        ),
      ),
    );
  }
}
