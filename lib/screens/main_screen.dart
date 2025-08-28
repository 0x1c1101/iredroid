import 'package:flutter/material.dart';
import 'custom_tab.dart';
import 'flipper_tab.dart';
import 'fuzzer_tab.dart';
import 'settings_tab.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> with TickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('IReDroid'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.add_circle_outline), text: 'Custom'),
            Tab(icon: Icon(Icons.devices), text: 'Flipper'),
            Tab(icon: Icon(Icons.shuffle), text: 'Fuzzer'),
            Tab(icon: Icon(Icons.settings), text: 'Settings'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          CustomTab(),
          FlipperTab(),
          FuzzerTab(),
          SettingsTab(),
        ],
      ),
    );
  }
}
