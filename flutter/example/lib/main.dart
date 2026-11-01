// A demo that plays both roles so you can try every kind of result from one app:
//   * YOUR SERVER: it calls the xtliveness API with an API key. In a real app this part lives on your backend, never in the app.
//   * YOUR APP: it opens the check with the package and then asks for the verdict.
// A TEST key (xtl_test_...) is free and needs no real photos. A LIVE key (xtl_live_...) runs real, billed checks.
import 'package:flutter/material.dart';

import 'conn.dart';
import 'tabs/connect.dart';
import 'tabs/identity.dart';
import 'tabs/liveness.dart';
import 'tabs/search.dart';
import 'ui.dart';

void main() => runApp(const DemoApp());

class DemoApp extends StatelessWidget {
  const DemoApp({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = ColorScheme.fromSeed(seedColor: brand);
    return MaterialApp(
      title: 'xtliveness demo',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(useMaterial3: true, colorScheme: scheme, scaffoldBackgroundColor: const Color(0xFFF6F8F8)),
      darkTheme: ThemeData(useMaterial3: true, colorScheme: ColorScheme.fromSeed(seedColor: brand, brightness: Brightness.dark)),
      home: const Shell(),
    );
  }
}

class Shell extends StatefulWidget {
  const Shell({super.key});
  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> {
  final _conn = Conn();
  int _tab = 0;

  static const _titles = ['Connect', 'Liveness', 'Face search', 'Identity'];

  @override
  void initState() {
    super.initState();
    if (_conn.hasKey) _tab = 1;   // a key was given at build time: go straight to the checks
  }

  @override
  void dispose() {
    _conn.dispose();
    super.dispose();
  }

  void _goConnect() => setState(() => _tab = 0);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: Padding(padding: const EdgeInsets.all(10), child: ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.asset('assets/icon.png', errorBuilder: (_, __, ___) => const SizedBox.shrink()))),
        title: Text(_titles[_tab]),
        centerTitle: false,
        actions: [Padding(padding: const EdgeInsets.only(right: 12), child: ListenableBuilder(listenable: _conn, builder: (c, _) => KeyBadge(conn: _conn)))],
      ),
      body: SafeArea(
        child: IndexedStack(index: _tab, children: [
          ConnectTab(conn: _conn),
          LivenessTab(conn: _conn, goConnect: _goConnect),
          SearchTab(conn: _conn, goConnect: _goConnect),
          IdentityTab(conn: _conn, goConnect: _goConnect),
        ]),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.link), label: 'Connect'),
          NavigationDestination(icon: Icon(Icons.face_retouching_natural), label: 'Liveness'),
          NavigationDestination(icon: Icon(Icons.groups_outlined), label: 'Search'),
          NavigationDestination(icon: Icon(Icons.badge_outlined), label: 'Identity'),
        ],
      ),
    );
  }
}
