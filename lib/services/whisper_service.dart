import 'dart:io';
import 'package:dio/dio.dart';
import 'package:http/http.dart' as http;
import '../models/transcription_model.dart';
import '../utils/constants.dart';

class WhisperService {
  static const String baseUrl = 'http://localhost:8000'; // Change for production
  late final Dio _dio;

  WhisperService() {
    _dio = Dio(BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 120),
      sendTimeout: const Duration(seconds: 60),
    ));
    
    // Add interceptors for logging
    _dio.interceptors.add(LogInterceptor(
      requestBody: false, // Don't log file uploads
      responseBody: true,
      logPrint: (obj) => print('API: $obj'),
    ));
  }

  Future<bool> checkServerHealth() async {
    try {
      final response = await _dio.get('/health');
      return response.statusCode == 200;
    } catch (e) {
      print('Server health check failed: $e');
      return false;
    }
  }

  Future<ApiResponse?> transcribeAudio({
    required File audioFile,
    String language = 'auto',
    String modelSize = 'base',
  }) async {
    try {
      // Prepare form data
      FormData formData = FormData.fromMap({
        'audio_file': await MultipartFile.fromFile(
          audioFile.path,
          filename: 'audio.wav',
        ),
        'language': language,
        'model_size': modelSize,
      });

      final response = await _dio.post(
        '/transcribe',
        data: formData,
        options: Options(
          headers: {
            'Content-Type': 'multipart/form-data',
          },
        ),
      );

      if (response.statusCode == 200) {
        return ApiResponse.fromJson(response.data);
      } else {
        return ApiResponse(
          success: false,
          message: 'HTTP ${response.statusCode}: ${response.statusMessage}',
          error: 'Request failed',
        );
      }
       } on DioException catch (e) {
      String errorMessage = 'Unknown error occurred';
      
      if (e.type == DioExceptionType.connectionTimeout) {  // CHANGED: connectTimeout -> connectionTimeout
        errorMessage = 'Connection timeout - check if server is running';
      } else if (e.type == DioExceptionType.receiveTimeout) {
        errorMessage = 'Response timeout - audio file might be too large';
      } else if (e.type == DioExceptionType.connectionError) {
        errorMessage = 'Cannot connect to server';
      } else if (e.response != null) {
        errorMessage = e.response!.data['message'] ?? e.response!.statusMessage ?? errorMessage;
      }

      return ApiResponse(
        success: false,
        message: errorMessage,
        error: e.type.toString(),
      );
    } catch (e) {
      return ApiResponse(
        success: false,
        message: 'Unexpected error: $e',
        error: 'unknown_error',
      );
    }
  }

  Future<Map<String, dynamic>?> getSupportedLanguages() async {
    try {
      final response = await _dio.get('/languages');
      return response.data;
    } catch (e) {
      print('Error getting languages: $e');
      return null;
    }
  }

  Future<Map<String, dynamic>?> getAvailableModels() async {
    try {
      final response = await _dio.get('/models');
      return response.data;
    } catch (e) {
      print('Error getting models: $e');
      return null;
    }
  }
}