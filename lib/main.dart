import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'screens/speech_screen.dart';
import 'utils/logger.dart';

void main() {
  // Initialize logging
  WidgetsFlutterBinding.ensureInitialized();
  
  // Set up error handling
  FlutterError.onError = (FlutterErrorDetails details) {
    AppLogger.error('Flutter Error', 
      tag: 'FlutterError',
      error: details.exception,
      stackTrace: details.stack,
    );
  };
  
  AppLogger.info('Starting Flutter Whisper App', tag: 'Main');
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    AppLogger.info('Building MyApp', tag: 'MyApp');
    return MaterialApp(
      title: 'Flutter Whisper STT',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.deepPurple,
          brightness: Brightness.light,
        ),
        useMaterial3: true,
        appBarTheme: const AppBarTheme(
          centerTitle: true,
          elevation: 0,
        ),
        cardTheme: const CardThemeData(  // CHANGED: CardTheme -> CardThemeData
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(12)),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 12,
          ),
        ),
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.deepPurple,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: const SpeechScreen(),
    );
  }
}