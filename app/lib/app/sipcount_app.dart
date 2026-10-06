import 'package:flutter/material.dart';

import '../features/about/presentation/about_page.dart';
import '../features/intro/presentation/intro_page.dart';
import '../features/settings/presentation/settings_page.dart';
import '../features/simulate/presentation/simulate_page.dart';
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
        home: _Root(tracker: tracker),
      );
}

/// The intro comes first and only once: until the age band is answered, sharing and sync have no
/// defensible setting, so the app does not guess one.
class _Root extends StatelessWidget {
  const _Root({required this.tracker});
  final Tracker tracker;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: tracker,
        builder: (context, _) =>
            tracker.introSeen ? _Shell(tracker: tracker) : IntroPage(tracker: tracker),
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
        // IndexedStack keeps each tab's scroll position, which matters most on Today: coming back
        // from Settings should not throw you to the top of the dashboard.
        body: IndexedStack(
          index: _tab,
          children: [
            TodayPage(tracker: widget.tracker),
            SimulatePage(tracker: widget.tracker),
            const AboutPage(),
            SettingsPage(tracker: widget.tracker),
          ],
        ),
        bottomNavigationBar: NavigationBar(
          selectedIndex: _tab,
          onDestinationSelected: (i) => setState(() => _tab = i),
          destinations: const [
            NavigationDestination(
                icon: Icon(Icons.water_drop_outlined), selectedIcon: Icon(Icons.water_drop), label: 'Today'),
            NavigationDestination(
                icon: Icon(Icons.bolt_outlined), selectedIcon: Icon(Icons.bolt), label: 'Simulate'),
            NavigationDestination(
                icon: Icon(Icons.lightbulb_outline), selectedIcon: Icon(Icons.lightbulb), label: 'About'),
            NavigationDestination(icon: Icon(Icons.tune), label: 'Settings'),
          ],
        ),
      );
}
