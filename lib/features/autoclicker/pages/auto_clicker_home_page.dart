import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../setting/pages/setting_page.dart';
import '../controllers/auto_clicker_controller.dart';
import 'configurations_page.dart';
import 'control_page.dart';

class AutoClickerHomePage extends StatefulWidget {
  const AutoClickerHomePage({super.key});

  @override
  State<AutoClickerHomePage> createState() => _AutoClickerHomePageState();
}

class _AutoClickerHomePageState extends State<AutoClickerHomePage> {
  final GlobalKey<UpdatePageState> _updatePageKey =
      GlobalKey<UpdatePageState>();
  late final AutoClickerController _controller;
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    _controller = AutoClickerController();
    _controller.addListener(_onControllerChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _bootstrap();
    });
  }

  @override
  void dispose() {
    _controller.removeListener(_onControllerChanged);
    _controller.dispose();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    await _controller.init();
    if (!mounted) return;

    _updatePageKey.currentState?.checkForUpdates(silentWhenUpToDate: true);
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
      UpdatePage(key: _updatePageKey, controller: _controller),
    ];

    return Scaffold(
      body: SafeArea(
        child: IndexedStack(index: _selectedIndex, children: pages),
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(
              color: theme.colorScheme.border.withValues(alpha: 0.8),
            ),
          ),
        ),
        child: NavigationBar(
          height: 48,
          selectedIndex: _selectedIndex,
          onDestinationSelected: (index) {
            setState(() {
              _selectedIndex = index;
            });
          },
          destinations: const [
            NavigationDestination(
              icon: Icon(LucideIcons.mousePointerClick),
              label: '控制',
            ),
            NavigationDestination(
              icon: Icon(LucideIcons.listChecks),
              label: '配置',
            ),
            NavigationDestination(
              icon: Icon(LucideIcons.settings2),
              label: '设置',
            ),
          ],
        ),
      ),
    );
  }
}
