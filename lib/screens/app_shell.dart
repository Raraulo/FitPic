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

  final Set<int> _visitedTabs = {0};

  Widget _screen(int index) {
    switch (index) {
      case 0:
        return HomeScreen(
          services: widget.services,
          onSuggest: () => _changeTab(2),
          onProfile: () => _changeTab(3),
        );
      case 1:
        return ClosetScreen(services: widget.services, onChanged: _refresh);
      case 2:
        return SuggestScreen(services: widget.services, onChanged: _refresh);
      default:
        return ProfileScreen(services: widget.services, onChanged: _refresh);
    }
  }

  void _refresh() {
    setState(() {});
  }

  void _changeTab(int index) {
    if (_currentIndex == index) return;

    setState(() {
      _currentIndex = index;
      _visitedTabs.add(index);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.canvas,
      body: SafeArea(
        child: IndexedStack(
          index: _currentIndex,
          children: List.generate(
              4,
              (index) => _visitedTabs.contains(index)
                  ? TickerMode(
                      enabled: index == _currentIndex, child: _screen(index))
                  : const SizedBox.shrink()),
        ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Container(
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          decoration: BoxDecoration(
            color: AppTheme.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: AppTheme.line),
            boxShadow: [
              BoxShadow(
                color: AppTheme.cocoa.withValues(alpha: 0.08),
                blurRadius: 24,
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
              backgroundColor: AppTheme.white,
              selectedItemColor: AppTheme.accent,
              unselectedItemColor: AppTheme.muted,
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
                  icon: Icon(Icons.whatshot_outlined),
                  activeIcon: Icon(Icons.whatshot),
                  label: 'Outfits',
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
