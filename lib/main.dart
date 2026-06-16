import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_downloader/flutter_downloader.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import 'features/autoclicker/pages/auto_clicker_home_page.dart';

const _bilibiliPink = Color(0xFFFB7299);

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  _bootstrap();
}

@pragma('vm:entry-point')
void downloadCallback(String id, int status, int progress) {
  IsolateNameServer.lookupPortByName('autoclicker_downloader_port')
      ?.send([id, status, progress]);
}

Future<void> _bootstrap() async {
  await FlutterDownloader.initialize(debug: false);
  FlutterDownloader.registerCallback(downloadCallback);
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
          primary: _bilibiliPink,
          primaryForeground: Colors.white,
          secondaryForeground: Color(0xFF3F1D2B),
          mutedForeground: Color(0xFF7B6470),
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
