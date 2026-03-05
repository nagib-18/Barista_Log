import 'package:flutter/material.dart';
import '../db_helper.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});
  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool _cleaningReminder = true;
  int _shotCount = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final val = await DatabaseHelper.instance.getSetting('cleaning_reminder');
    final count = await DatabaseHelper.instance.getHomeCount();
    if (!mounted) return;
    setState(() {
      _cleaningReminder = val != 'false'; // default: enabled
      _shotCount = count;
    });
  }

  void _toggle(bool v) async {
    await DatabaseHelper.instance.setSetting('cleaning_reminder', v.toString());
    setState(() => _cleaningReminder = v);
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: SwitchListTile(
            title: const Text("Cleaning Reminder"),
            subtitle:
                Text("Alert every 120 shots  (current: $_shotCount shots)"),
            value: _cleaningReminder,
            onChanged: _toggle,
            activeColor: Colors.brown,
            secondary: const Icon(Icons.cleaning_services),
          ),
        ),
        const SizedBox(height: 32),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("About",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              SizedBox(height: 8),
              Text(
                "Barista Log v2.0\nYour personal coffee tracking companion.",
                style: TextStyle(color: Colors.grey),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
