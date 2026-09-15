import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter/services.dart';
import 'providers/theme_provider.dart';
import 'providers/history_provider.dart';
import 'providers/device_scanner_provider.dart';
import 'providers/wifi_analyzer_provider.dart';
import 'providers/network_info_provider.dart';
import 'screens/main_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => HistoryProvider()),
        ChangeNotifierProvider(create: (_) => DeviceScannerProvider()),
        ChangeNotifierProvider(create: (_) => WifiAnalyzerProvider()),
        ChangeNotifierProvider(create: (_) => NetworkInfoProvider()),
      ],
      child: const WifiQrGeneratorApp(),
    ),
  );
}

class WifiQrGeneratorApp extends StatelessWidget {
  const WifiQrGeneratorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        // --- Premium 60-30-10 Color Themes ---
        // 60% Background, 30% Surfaces/Cards, 10% Accent (Electric Blue)
        const Color electricBlue = Color(0xFF00D4FF);

        final lightTheme = ThemeData(
          brightness: Brightness.light,
          primaryColor: electricBlue,
          scaffoldBackgroundColor: const Color(0xFFF8FAFC), // 60% Light Background
          cardColor: const Color(0xFFFFFFFF), // 30% Light Surface
          colorScheme: const ColorScheme.light(
            primary: electricBlue, // 10% Accent
            secondary: electricBlue,
            surface: Color(0xFFFFFFFF),
            onSurface: Color(0xFF0F172A),
          ),
          textTheme: GoogleFonts.poppinsTextTheme(ThemeData.light().textTheme),
          useMaterial3: true,
          appBarTheme: const AppBarTheme(
            backgroundColor: Color(0xFFFFFFFF),
            foregroundColor: Color(0xFF0F172A),
            elevation: 0,
            centerTitle: true,
            iconTheme: IconThemeData(color: Color(0xFF0F172A)),
          ),
        );

        final darkTheme = ThemeData(
          brightness: Brightness.dark,
          primaryColor: electricBlue,
          scaffoldBackgroundColor: const Color(0xFF0F172A), // 60% Dark Background (Deep Navy)
          cardColor: const Color(0xFF1E293B), // 30% Dark Surface
          colorScheme: const ColorScheme.dark(
            primary: electricBlue, // 10% Accent
            secondary: electricBlue,
            surface: Color(0xFF1E293B),
            onSurface: Color(0xFFF8FAFC),
          ),
          textTheme: GoogleFonts.poppinsTextTheme(ThemeData.dark().textTheme),
          useMaterial3: true,
          appBarTheme: const AppBarTheme(
            backgroundColor: Color(0xFF0F172A),
            foregroundColor: Color(0xFFF8FAFC),
            elevation: 0,
            centerTitle: true,
            iconTheme: IconThemeData(color: Color(0xFFF8FAFC)),
          ),
        );

        return MaterialApp(
          title: 'Guest Wi-Fi QR Generator',
          theme: lightTheme,
          darkTheme: darkTheme,
          themeMode: themeProvider.isDarkMode ? ThemeMode.dark : ThemeMode.light,
          home: const MainScreen(),
          debugShowCheckedModeBanner: false,
          builder: (context, child) {
            return AnnotatedRegion<SystemUiOverlayStyle>(
              value: themeProvider.isDarkMode 
                  ? SystemUiOverlayStyle.light 
                  : SystemUiOverlayStyle.dark,
              child: Container(
                color: Theme.of(context).scaffoldBackgroundColor,
                child: SafeArea(
                  child: child!,
                ),
              ),
            );
          },
        );
      },
    );
  }
}
