import 'package:flutter/material.dart';
import 'screens/home_screen.dart';

void main() {
  runApp(SecureVideoPlayerApp());
}

class SecureVideoPlayerApp extends StatelessWidget {
  const SecureVideoPlayerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Secure Video Player',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        // Modern gradient color scheme for professional look
        primarySwatch: Colors.deepPurple,
        primaryColor: Color(0xFF6C63FF),
        hintColor: Color(0xFF00D4AA),
        scaffoldBackgroundColor: Color(0xFF0F0F23),
        cardColor: Color(0xFF1A1A2E),
        dividerColor: Color(0xFF16213E),

        // Custom app bar theme
        appBarTheme: AppBarTheme(
          backgroundColor: Color(0xFF0F0F23),
          elevation: 0,
          centerTitle: true,
          iconTheme: IconThemeData(color: Colors.white),
          titleTextStyle: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),

        // Modern text theme
        textTheme: TextTheme(
          titleLarge: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
          bodyLarge: TextStyle(color: Colors.white70),
          bodyMedium: TextStyle(color: Colors.white54),
        ),

        // Custom elevated button theme
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            foregroundColor: Colors.white,
            backgroundColor: Color(0xFF6C63FF),
            elevation: 8,
            shadowColor: Color(0xFF6C63FF).withOpacity(0.3),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          ),
        ),

        // Icon theme
        iconTheme: IconThemeData(color: Colors.white70),

        // Input decoration theme
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Color(0xFF1A1A2E),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          labelStyle: TextStyle(color: Colors.white70),
          hintStyle: TextStyle(color: Colors.white54),
        ),
      ),
      home: HomeScreen(),
    );
  }
}