import 'package:flutter/material.dart';

import '../main.dart';
import '../theme/app_theme.dart';
import 'closet_screen.dart';
import 'home_screen.dart';
import 'profile_screen.dart';
import 'suggest_screen.dart';

class AppShell extends StatefulWidget {
  const AppShell({
    super.key,
    required this.services,
  });

  final AppServices services;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _currentIndex = 0;

  late final List<Widget> _screens;

  @override
  void initState() {
    super.initState();

    _screens = [
      HomeScreen(
        services: widget.services,
        onSuggest: () => _changeTab(2),
        onProfile: () => _changeTab(3),
      ),
      ClosetScreen(
        services: widget.services,
        onChanged: _refresh,
      ),
      SuggestScreen(
        services: widget.services,
        onChanged: _refresh,
      ),
      ProfileScreen(
        services: widget.services,
        onChanged: _refresh,
      ),
    ];
  }

  void _refresh() {
    setState(() {});
  }

  void _changeTab(int index) {
    if (_currentIndex == index) return;

    setState(() {
      _currentIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.white,

      body: SafeArea(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 250),
          child: IndexedStack(
            key: ValueKey(_currentIndex),
            index: _currentIndex,
            children: _screens,
          ),
        ),
      ),

      bottomNavigationBar: SafeArea(
        top: false,
        child: Container(
          margin: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: AppTheme.darkBrown.withOpacity(.15),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(.08),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: BottomNavigationBar(
              currentIndex: _currentIndex,
              onTap: _changeTab,
              type: BottomNavigationBarType.fixed,
              elevation: 0,
              backgroundColor: Colors.white,
              selectedItemColor: AppTheme.darkBrown,
              unselectedItemColor: Colors.grey.shade500,
              selectedFontSize: 13,
              unselectedFontSize: 12,
              showUnselectedLabels: true,
              items: const [
                BottomNavigationBarItem(
                  icon: Icon(Icons.home_rounded),
                  activeIcon: Icon(Icons.home),
                  label: 'Inicio',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.checkroom_outlined),
                  activeIcon: Icon(Icons.checkroom),
                  label: 'Armario',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.auto_awesome_outlined),
                  activeIcon: Icon(Icons.auto_awesome),
                  label: 'IA',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.person_outline),
                  activeIcon: Icon(Icons.person),
                  label: 'Perfil',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}