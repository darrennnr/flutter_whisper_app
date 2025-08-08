import 'dart:io';
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:http/http.dart' as http;
import '../models/transcription_model.dart';
import '../utils/constants.dart';
import '../utils/logger.dart';

class WhisperService {
  // CHANGED: Make baseUrl configurable for ngrok
  static String baseUrl = 'http://localhost:8000'; // Default for local
  late final Dio _dio;

  WhisperService() {
    AppLogger.info('Initializing WhisperService with baseUrl: $baseUrl', tag: 'WhisperService');
    _dio = Dio(BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 120),
      sendTimeout: const Duration(seconds: 60),
      headers: {
        'Accept': 'application/json',
        'User-Agent': 'Flutter-WhisperApp/1.0',
      },
    ));
    
    // Add interceptors for logging
    _dio.interceptors.add(LogInterceptor(
      requestBody: false, // Don't log file uploads
      responseBody: true,
      logPrint: (obj) => AppLogger.network('$obj', tag: 'DIO'),
    ));
    
    // Add custom interceptor for detailed logging
    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) {
        AppLogger.network('REQUEST: ${options.method} ${options.uri}', 
          tag: 'WhisperService',
          data: {
            'headers': options.headers,
            'queryParameters': options.queryParameters,
          }
        );
        handler.next(options);
      },
      onResponse: (response, handler) {
        AppLogger.network('RESPONSE: ${response.statusCode} ${response.requestOptions.uri}',
          tag: 'WhisperService',
          data: {
            'statusCode': response.statusCode,
            'headers': response.headers.map,
            'data': response.data is String ? response.data : 'Binary/Complex data',
          }
        );
        handler.next(response);
      },
      onError: (error, handler) {
        AppLogger.error('REQUEST ERROR: ${error.requestOptions.uri}',
          tag: 'WhisperService',
          error: error,
          stackTrace: error.stackTrace,
        );
        handler.next(error);
      },
    ));
  }
  
  // ADDED: Method to update base URL for ngrok
  void updateBaseUrl(String newBaseUrl) {
    AppLogger.info('Updating baseUrl from $baseUrl to $newBaseUrl', tag: 'WhisperService');
    baseUrl = newBaseUrl;
    _dio.options.baseUrl = newBaseUrl;
  }

  Future<bool> checkServerHealth() async {
    AppLogger.info('Checking server health at: $baseUrl/health', tag: 'WhisperService');
    try {
      final stopwatch = Stopwatch()..start();
      final response = await _dio.get('/health');
      stopwatch.stop();
      
      final isHealthy = response.statusCode == 200;
      AppLogger.info('Health check completed in ${stopwatch.elapsedMilliseconds}ms - Status: ${isHealthy ? 'HEALTHY' : 'UNHEALTHY'}',
        tag: 'WhisperService',
      );
      
      if (isHealthy && response.data != null) {
        AppLogger.info('Server info: ${response.data}', tag: 'WhisperService');
      }
      
      return isHealthy;
    } catch (e) {
      AppLogger.error('Server health check failed', 
        tag: 'WhisperService',
        error: e,
        stackTrace: StackTrace.current,
      );
      return false;
    }
  }

  Future<ApiResponse?> transcribeAudio({
    required File audioFile,
    String language = 'auto',
    String modelSize = 'base',
  }) async {
    AppLogger.info('Starting transcription', 
      tag: 'WhisperService',
      data: {
        'audioFilePath': audioFile.path,
        'audioFileSize': await audioFile.length(),
        'language': language,
        'modelSize': modelSize,
      }
    );
    
    try {
      // Validate audio file
      if (!await audioFile.exists()) {
        throw Exception('Audio file does not exist: ${audioFile.path}');
      }
      
      final fileSize = await audioFile.length();
      AppLogger.info('Audio file validated - Size: ${fileSize} bytes', tag: 'WhisperService');
      
      if (fileSize == 0) {
        throw Exception('Audio file is empty');
      }
      
      if (fileSize > 25 * 1024 * 1024) { // 25MB limit
        throw Exception('Audio file too large: ${fileSize} bytes (max 25MB)');
      }
      
      // Prepare form data
      AppLogger.info('Preparing form data for upload', tag: 'WhisperService');
      FormData formData = FormData.fromMap({
        'audio_file': await MultipartFile.fromFile(
          audioFile.path,
          filename: audioFile.path.split('/').last,
        ),
        'language': language,
        'model_size': modelSize,
      });
      
      AppLogger.info('Form data prepared, sending request to /transcribe', tag: 'WhisperService');

      final stopwatch = Stopwatch()..start();
      final response = await _dio.post(
        '/transcribe',
        data: formData,
        options: Options(
          headers: {
            'Content-Type': 'multipart/form-data',
            'Accept': 'application/json',
          },
        ),
      );
      stopwatch.stop();
      
      AppLogger.info('Transcription request completed in ${stopwatch.elapsedMilliseconds}ms', tag: 'WhisperService');

      if (response.statusCode == 200) {
        AppLogger.info('Transcription successful, parsing response', tag: 'WhisperService');
        
        if (response.data == null) {
          throw Exception('Empty response from server');
        }
        
        // Log response structure for debugging
        AppLogger.debug('Response data type: ${response.data.runtimeType}', tag: 'WhisperService');
        
        return ApiResponse.fromJson(response.data);
      } else {
        AppLogger.warning('Transcription failed with status: ${response.statusCode}', 
          tag: 'WhisperService',
          error: response.statusMessage,
        );
        return ApiResponse(
          success: false,
          message: 'HTTP ${response.statusCode}: ${response.statusMessage}',
          error: 'Request failed',
        );
      }
    } on DioException catch (e) {
      AppLogger.error('DioException during transcription', 
        tag: 'WhisperService',
        error: e,
        stackTrace: e.stackTrace,
      );
      
      String errorMessage = 'Unknown error occurred';
      
      if (e.type == DioExceptionType.connectionTimeout) {  // CHANGED: connectTimeout -> connectionTimeout
        errorMessage = 'Connection timeout - check if server is running';
      } else if (e.type == DioExceptionType.receiveTimeout) {
        errorMessage = 'Response timeout - audio file might be too large';
      } else if (e.type == DioExceptionType.connectionError) {
        errorMessage = 'Cannot connect to server';
      } else if (e.type == DioExceptionType.badResponse) {
        errorMessage = 'Bad response from server: ${e.response?.statusCode}';
        if (e.response?.data != null) {
          AppLogger.error('Bad response data: ${e.response!.data}', tag: 'WhisperService');
        }
      } else if (e.response != null) {
        try {
          if (e.response!.data is Map<String, dynamic>) {
            errorMessage = e.response!.data['message'] ?? e.response!.statusMessage ?? errorMessage;
          } else {
            errorMessage = e.response!.statusMessage ?? errorMessage;
          }
        } catch (parseError) {
          AppLogger.error('Error parsing error response', tag: 'WhisperService', error: parseError);
        }
      }
      
      AppLogger.error('Final error message: $errorMessage', tag: 'WhisperService');

      return ApiResponse(
        success: false,
        message: errorMessage,
        error: e.type.toString(),
      );
    } catch (e) {
      AppLogger.error('Unexpected error during transcription', 
        tag: 'WhisperService',
        error: e,
        stackTrace: StackTrace.current,
      );
      return ApiResponse(
        success: false,
        message: 'Unexpected error: $e',
        error: 'unknown_error',
      );
    }
  }

  Future<Map<String, dynamic>?> getSupportedLanguages() async {
    AppLogger.info('Fetching supported languages', tag: 'WhisperService');
    try {
      final response = await _dio.get('/languages');
      AppLogger.info('Languages fetched successfully', tag: 'WhisperService');
      return response.data;
    } catch (e) {
      AppLogger.error('Error getting languages', tag: 'WhisperService', error: e);
      return null;
    }
  }

  Future<Map<String, dynamic>?> getAvailableModels() async {
    AppLogger.info('Fetching available models', tag: 'WhisperService');
    try {
      final response = await _dio.get('/models');
      AppLogger.info('Models fetched successfully', tag: 'WhisperService');
      return response.data;
    } catch (e) {
      AppLogger.error('Error getting models', tag: 'WhisperService', error: e);
      return null;
    }
  }
}