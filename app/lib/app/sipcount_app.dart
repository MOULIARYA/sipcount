import 'package:flutter/material.dart';

import '../features/settings/presentation/settings_page.dart';
import '../features/tracking/application/tracker.dart';
import '../features/tracking/presentation/today_page.dart';
import 'theme.dart';

class SipcountApp extends StatelessWidget {
  const SipcountApp({super.key, required this.tracker});
  final Tracker tracker;

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'Sipcount',
        debugShowCheckedModeBanner: false,
        theme: sipcountTheme(),
        themeMode: ThemeMode.dark,
        home: _Shell(tracker: tracker),
      );
}

class _Shell extends StatefulWidget {
  const _Shell({required this.tracker});
  final Tracker tracker;

  @override
  State<_Shell> createState() => _ShellState();
}

class _ShellState extends State<_Shell> with WidgetsBindingObserver {
  int _tab = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Returning from the Accessibility settings screen → re-check the toggle.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) widget.tracker.refreshListenerState();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        body: IndexedStack(
          index: _tab,
          children: [TodayPage(tracker: widget.tracker), SettingsPage(tracker: widget.tracker)],
        ),
        bottomNavigationBar: NavigationBar(
          selectedIndex: _tab,
          onDestinationSelected: (i) => setState(() => _tab = i),
          destinations: const [
            NavigationDestination(icon: Icon(Icons.water_drop_outlined), selectedIcon: Icon(Icons.water_drop), label: 'Today'),
            NavigationDestination(icon: Icon(Icons.tune), label: 'Settings'),
          ],
        ),
      );
}
