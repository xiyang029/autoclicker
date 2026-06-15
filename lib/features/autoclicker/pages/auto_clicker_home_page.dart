import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../update/pages/update_page.dart';
import '../controllers/auto_clicker_controller.dart';
import 'configurations_page.dart';
import 'control_page.dart';

class AutoClickerHomePage extends StatefulWidget {
  const AutoClickerHomePage({super.key});

  @override
  State<AutoClickerHomePage> createState() => _AutoClickerHomePageState();
}

class _AutoClickerHomePageState extends State<AutoClickerHomePage> {
  late final AutoClickerController _controller;
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    _controller = AutoClickerController()..init();
    _controller.addListener(_onControllerChanged);
  }

  @override
  void dispose() {
    _controller.removeListener(_onControllerChanged);
    _controller.dispose();
    super.dispose();
  }

  void _onControllerChanged() {
    if (!mounted) return;
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    final pages = [
      ControlPage(controller: _controller),
      ConfigurationsPage(controller: _controller),
      UpdatePage(controller: _controller),
    ];

    return Scaffold(
      body: SafeArea(
        child: IndexedStack(index: _selectedIndex, children: pages),
      ),
      bottomNavigationBar: NavigationBar(
        height: 52,
        selectedIndex: _selectedIndex,
        backgroundColor: theme.colorScheme.background,
        indicatorColor: theme.colorScheme.secondary,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        onDestinationSelected: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(LucideIcons.mousePointerClick),
            selectedIcon: Icon(LucideIcons.mousePointerClick),
            label: '控制',
          ),
          NavigationDestination(
            icon: Icon(LucideIcons.listChecks),
            selectedIcon: Icon(LucideIcons.listChecks),
            label: '配置',
          ),
          NavigationDestination(
            icon: Icon(LucideIcons.download),
            selectedIcon: Icon(LucideIcons.download),
            label: '更新',
          ),
        ],
      ),
    );
  }
}
