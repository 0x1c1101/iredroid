import 'package:flutter/material.dart';
import 'screens/main_screen.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'IReDroid',
      theme: ThemeData(
        // Flipper Zero inspired theme - Orange and dark colors
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFFFF8C00), // Flipper Zero orange
          secondary: Color(0xFFFF8C00),
          surface: Color(0xFF1E1E1E), // Dark surface
          background: Color(0xFF121212), // Very dark background
          onPrimary: Colors.black,
          onSecondary: Colors.black,
          onSurface: Colors.white,
          onBackground: Colors.white,
        ),
        useMaterial3: true,
        // App bar theme
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF1E1E1E),
          foregroundColor: Color(0xFFFF8C00),
          elevation: 0,
        ),
        // Tab bar theme  
        tabBarTheme: const TabBarThemeData(
          labelColor: Color(0xFFFF8C00),
          unselectedLabelColor: Colors.grey,
          indicator: UnderlineTabIndicator(
            borderSide: BorderSide(color: Color(0xFFFF8C00), width: 2),
          ),
        ),
        // Card theme
        cardTheme: const CardThemeData(
          color: Color(0xFF2D2D2D),
          elevation: 2,
        ),
        // Elevated button theme
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFFF8C00),
            foregroundColor: Colors.black,
          ),
        ),
        // Disable animations for faster performance
        pageTransitionsTheme: const PageTransitionsTheme(
          builders: {
            TargetPlatform.android: FadeUpwardsPageTransitionsBuilder(),
            TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          },
        ),
      ),
      // Disable debug banner
      debugShowCheckedModeBanner: false,
      // Disable animations globally
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(
            // Disable animations
            disableAnimations: true,
          ),
          child: child!,
        );
      },
      home: const MainScreen(),
    );
  }
}
