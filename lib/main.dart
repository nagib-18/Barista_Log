import 'package:flutter/material.dart';
import 'pages/espresso_in_page.dart';
import 'pages/espresso_out_page.dart';
import 'pages/roasts_page.dart';
import 'pages/settings_page.dart';
import 'pages/dashboard_page.dart';

void main() {
  runApp(const MaterialApp(
    debugShowCheckedModeBanner: false,
    home: MainApp(),
  ));
}

class MainApp extends StatefulWidget {
  const MainApp({super.key});
  @override
  State<MainApp> createState() => _MainAppState();
}

class _MainAppState extends State<MainApp> {
  int _currentIndex = 0;

  static const _titles = ['Espresso In', 'Espresso Out', 'Roasts', 'Settings'];

  Widget _buildCurrentPage() {
    switch (_currentIndex) {
      case 0:
        return const EspressoInPage();
      case 1:
        return const EspressoOutPage();
      case 2:
        return const RoastsPage();
      case 3:
        return const SettingsPage();
      default:
        return const EspressoInPage();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_titles[_currentIndex]),
        backgroundColor: Colors.brown,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.analytics_outlined),
            tooltip: 'Dashboard',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const DashboardPage()),
            ),
          ),
        ],
      ),
      body: _buildCurrentPage(),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (i) => setState(() => _currentIndex = i),
        type: BottomNavigationBarType.fixed,
        selectedItemColor: Colors.brown,
        unselectedItemColor: Colors.grey,
        items: const [
          BottomNavigationBarItem(
              icon: Icon(Icons.coffee), label: 'Espresso In'),
          BottomNavigationBarItem(
              icon: Icon(Icons.store), label: 'Espresso Out'),
          BottomNavigationBarItem(
              icon: Icon(Icons.inventory_2), label: 'Roasts'),
          BottomNavigationBarItem(
              icon: Icon(Icons.settings), label: 'Settings'),
        ],
      ),
    );
  }
}
