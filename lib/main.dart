import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import 'features/autoclicker/pages/auto_clicker_home_page.dart';

const _bilibiliPink = Color(0xFFFB7299);
const _bilibiliPinkSoft = Color(0xFFFFECF2);
const _bilibiliPinkMuted = Color(0xFFFFF5F8);

void main() {
  runApp(const AutoClickerApp());
}

class AutoClickerApp extends StatelessWidget {
  const AutoClickerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ShadApp.custom(
      themeMode: ThemeMode.light,
      theme: ShadThemeData(
        brightness: Brightness.light,
        colorScheme: const ShadRoseColorScheme.light(
          background: Color(0xFFFFFBFC),
          primary: _bilibiliPink,
          primaryForeground: Colors.white,
          secondary: _bilibiliPinkSoft,
          secondaryForeground: Color(0xFF3F1D2B),
          muted: _bilibiliPinkMuted,
          mutedForeground: Color(0xFF7B6470),
          accent: _bilibiliPinkSoft,
          accentForeground: Color(0xFF3F1D2B),
          input: Color(0xFFFFD6E2),
          ring: _bilibiliPink,
          selection: Color(0xFFFFD6E2),
          custom: {
            'bilibiliPink': _bilibiliPink,
            'targetRing': Color(0xFFFF9FBA),
          },
        ),
      ),
      appBuilder: (context) {
        final materialTheme = Theme.of(context);
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          title: '粉点连点器',
          theme: materialTheme.copyWith(
            appBarTheme: materialTheme.appBarTheme.copyWith(
              centerTitle: false,
              backgroundColor: materialTheme.colorScheme.surface,
              foregroundColor: materialTheme.colorScheme.onSurface,
              elevation: 0,
            ),
          ),
          localizationsDelegates: const [
            GlobalShadLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
          ],
          supportedLocales: const [Locale('zh', 'CN'), Locale('en', 'US')],
          builder: (context, child) {
            return ShadAppBuilder(child: child!);
          },
          home: const AutoClickerHomePage(),
        );
      },
    );
  }
}
