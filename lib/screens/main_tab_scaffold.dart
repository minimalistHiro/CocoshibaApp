import 'package:flutter/material.dart';

import 'account_page.dart';
import 'books_page.dart';
import 'calendar_page.dart';
import 'home_page.dart';
import 'qr_code_page.dart';

class MainTabScaffold extends StatefulWidget {
  const MainTabScaffold({super.key});

  @override
  State<MainTabScaffold> createState() => _MainTabScaffoldState();
}

class _MainTabScaffoldState extends State<MainTabScaffold> {
  int _selectedIndex = 0;

  final List<Widget> _pages = const [
    HomePage(),
    CalendarPage(),
    BooksPage(),
    AccountPage(),
  ];

  void _setTab(int index) {
    setState(() => _selectedIndex = index);
  }

  void _openQr() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const QrCodePage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tabs = [
      _TabItem(
        icon: Icons.home_outlined,
        label: 'ホーム',
        isActive: _selectedIndex == 0,
        onTap: () => _setTab(0),
      ),
      _TabItem(
        icon: Icons.calendar_today_outlined,
        label: 'カレンダー',
        isActive: _selectedIndex == 1,
        onTap: () => _setTab(1),
      ),
      _TabItem(
        icon: Icons.menu_book_outlined,
        label: '本',
        isActive: _selectedIndex == 2,
        onTap: () => _setTab(2),
      ),
      _TabItem(
        icon: Icons.person_outline,
        label: 'アカウント',
        isActive: _selectedIndex == 3,
        onTap: () => _setTab(3),
      ),
    ];

    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex,
        children: _pages,
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _openQr,
        child: const Icon(Icons.qr_code),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: BottomAppBar(
        shape: const CircularNotchedRectangle(),
        color: Colors.white,
        child: SafeArea(
          top: false,
          child: SizedBox(
            height: 68,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: Row(
                children: [
                  Expanded(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: tabs.take(2).toList(),
                    ),
                  ),
                  const SizedBox(width: 64),
                  Expanded(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: tabs.skip(2).toList(),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TabItem extends StatelessWidget {
  const _TabItem({
    required this.icon,
    required this.label,
    required this.onTap,
    required this.isActive,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool isActive;

  @override
  Widget build(BuildContext context) {
    final color = isActive
        ? Theme.of(context).colorScheme.primary
        : Colors.grey.shade500;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.translucent,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(color: color, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}
