import '../models/language_model.dart';

class AppConstants {
  // API Configuration
  static const String defaultApiUrl = 'http://localhost:8000';
  static const Duration connectionTimeout = Duration(seconds: 30);
  static const Duration receiveTimeout = Duration(seconds: 120);
  
  // Audio Configuration
  static const int sampleRate = 16000;
  static const int bitRate = 256000;
  static const Duration maxRecordingDuration = Duration(minutes: 10);
  
  // UI Configuration
  static const Duration animationDuration = Duration(milliseconds: 300);
  static const double defaultBorderRadius = 12.0;
  
  // Supported Languages
  static const List<Language> supportedLanguages = [
    Language(
      code: 'auto',
      name: 'Auto Detect',
      nativeName: 'Auto',
      flag: '🌐',
    ),
    Language(
      code: 'en',
      name: 'English',
      nativeName: 'English',
      flag: '🇺🇸',
    ),
    Language(
      code: 'id',
      name: 'Indonesian',
      nativeName: 'Bahasa Indonesia',
      flag: '🇮🇩',
    ),
    Language(
      code: 'ar',
      name: 'Arabic',
      nativeName: 'العربية',
      flag: '🇸🇦',
      isRTL: true,
    ),
  ];
  
  // Model Sizes
  static const Map<String, Map<String, String>> modelSizes = {
    'tiny': {
      'name': 'Tiny',
      'size': '39 MB',
      'speed': 'Fastest',
      'accuracy': 'Basic'
    },
    'base': {
      'name': 'Base',
      'size': '74 MB', 
      'speed': 'Fast',
      'accuracy': 'Good'
    },
    'small': {
      'name': 'Small',
      'size': '244 MB',
      'speed': 'Medium',
      'accuracy': 'Better'
    },
    'medium': {
      'name': 'Medium',
      'size': '769 MB',
      'speed': 'Slow',
      'accuracy': 'Best'
    },
  };
  
  // Error Messages
  static const Map<String, String> errorMessages = {
    'connection_error': 'Cannot connect to server. Make sure the Python backend is running.',
    'permission_denied': 'Microphone permission is required for speech recognition.',
    'recording_failed': 'Failed to record audio. Please try again.',
    'transcription_failed': 'Failed to transcribe audio. Please check your connection.',
    'file_not_found': 'Audio file not found. Please record audio first.',
    'server_error': 'Server error occurred. Please try again later.',
  };
}