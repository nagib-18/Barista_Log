import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../db_helper.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});
  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool _cleaningReminder = true;
  int _shotsSinceReset = 0;
  final _tempCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _tempCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final val = await DatabaseHelper.instance.getSetting('cleaning_reminder');
    final count = await DatabaseHelper.instance.getShotsSinceReset();
    final temp = await DatabaseHelper.instance.getSetting('default_brew_temp');
    if (!mounted) return;
    setState(() {
      _cleaningReminder = val != 'false';
      _shotsSinceReset = count;
      _tempCtrl.text = temp ?? '93';
    });
  }

  void _toggle(bool v) async {
    await DatabaseHelper.instance.setSetting('cleaning_reminder', v.toString());
    setState(() => _cleaningReminder = v);
  }

  void _saveBrewTemp() async {
    final v = _tempCtrl.text.trim();
    await DatabaseHelper.instance.setSetting('default_brew_temp', v);
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text("Default brew temp saved!")));
    }
  }

  void _confirmResetCounter() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Reset Cleaning Counter"),
        content: const Text(
            "This will reset the shot counter used for cleaning reminders. Your shot history is not deleted."),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () async {
              await DatabaseHelper.instance.resetCleaningCounter();
              if (mounted) Navigator.pop(context);
              _load();
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Cleaning counter reset!")),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.brown),
            child: const Text("Reset", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // ── Brew Temperature ──
        Card(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(children: [
                  Icon(Icons.thermostat, color: Colors.brown),
                  SizedBox(width: 8),
                  Text("Default Brew Temperature",
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ]),
                const SizedBox(height: 4),
                const Text("Pre-filled on every new shot log",
                    style: TextStyle(color: Colors.grey, fontSize: 13)),
                const SizedBox(height: 10),
                Row(children: [
                  Expanded(
                    child: TextField(
                      controller: _tempCtrl,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                        labelText: 'Temperature (°C)',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: _saveBrewTemp,
                    style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.brown,
                        foregroundColor: Colors.white),
                    child: const Text("Save"),
                  ),
                ]),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),

        // ── Cleaning Reminder ──
        Card(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: SwitchListTile(
            title: const Text("Cleaning Reminder"),
            subtitle: Text(
                "Alert every 120 shots  (since last reset: $_shotsSinceReset shots)"),
            value: _cleaningReminder,
            onChanged: _toggle,
            activeThumbColor: Colors.brown,
            secondary: const Icon(Icons.cleaning_services),
          ),
        ),
        const SizedBox(height: 8),

        // ── Reset Counter ──
        Card(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: ListTile(
            leading: const Icon(Icons.restart_alt, color: Colors.brown),
            title: const Text("Reset Cleaning Counter"),
            subtitle: const Text("Mark machine as cleaned — resets the shot count"),
            trailing: const Icon(Icons.chevron_right),
            onTap: _confirmResetCounter,
          ),
        ),
        const SizedBox(height: 16),

        // ── Support ──
        Card(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: ListTile(
            leading: const Icon(Icons.coffee, color: Colors.brown),
            title: const Text("Support the Developer"),
            subtitle: const Text("Buy me a coffee \u2615"),
            trailing: const Icon(Icons.open_in_new),
            onTap: () => launchUrl(
              Uri.parse('https://buymeacoffee.com/mzcoffee'),
              mode: LaunchMode.externalApplication,
            ),
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
                "Barista Log v4.0\nYour personal coffee tracking companion.",
                style: TextStyle(color: Colors.grey),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
