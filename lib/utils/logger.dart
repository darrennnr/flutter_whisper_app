import 'dart:developer' as developer;
import 'package:flutter/foundation.dart';

class AppLogger {
  static const String _tag = 'WhisperApp';
  
  static void debug(String message, {String? tag, Object? error, StackTrace? stackTrace}) {
    final logTag = tag ?? _tag;
    final logMessage = '[$logTag] DEBUG: $message';
    
    if (kDebugMode) {
      print(logMessage);
      if (error != null) {
        print('[$logTag] ERROR: $error');
      }
      if (stackTrace != null) {
        print('[$logTag] STACK: $stackTrace');
      }
    }
    
    developer.log(
      message,
      name: logTag,
      level: 500, // DEBUG level
      error: error,
      stackTrace: stackTrace,
    );
  }
  
  static void info(String message, {String? tag}) {
    final logTag = tag ?? _tag;
    final logMessage = '[$logTag] INFO: $message';
    
    if (kDebugMode) {
      print(logMessage);
    }
    
    developer.log(
      message,
      name: logTag,
      level: 800, // INFO level
    );
  }
  
  static void warning(String message, {String? tag, Object? error}) {
    final logTag = tag ?? _tag;
    final logMessage = '[$logTag] WARNING: $message';
    
    if (kDebugMode) {
      print(logMessage);
      if (error != null) {
        print('[$logTag] WARNING ERROR: $error');
      }
    }
    
    developer.log(
      message,
      name: logTag,
      level: 900, // WARNING level
      error: error,
    );
  }
  
  static void error(String message, {String? tag, Object? error, StackTrace? stackTrace}) {
    final logTag = tag ?? _tag;
    final logMessage = '[$logTag] ERROR: $message';
    
    if (kDebugMode) {
      print(logMessage);
      if (error != null) {
        print('[$logTag] ERROR DETAILS: $error');
      }
      if (stackTrace != null) {
        print('[$logTag] STACK TRACE: $stackTrace');
      }
    }
    
    developer.log(
      message,
      name: logTag,
      level: 1000, // ERROR level
      error: error,
      stackTrace: stackTrace,
    );
  }
  
  static void network(String message, {String? tag, Map<String, dynamic>? data}) {
    final logTag = '${tag ?? _tag}_NETWORK';
    final logMessage = '[$logTag] $message';
    
    if (kDebugMode) {
      print(logMessage);
      if (data != null) {
        print('[$logTag] DATA: $data');
      }
    }
    
    developer.log(
      message,
      name: logTag,
      level: 800,
    );
  }
  
  static void audio(String message, {String? tag, Map<String, dynamic>? data}) {
    final logTag = '${tag ?? _tag}_AUDIO';
    final logMessage = '[$logTag] $message';
    
    if (kDebugMode) {
      print(logMessage);
      if (data != null) {
        print('[$logTag] DATA: $data');
      }
    }
    
    developer.log(
      message,
      name: logTag,
      level: 800,
    );
  }
}