import 'dart:io';
import 'dart:typed_data';
import 'package:record/record.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import '../utils/logger.dart';

class AudioService {
  static final AudioService _instance = AudioService._internal();
  factory AudioService() => _instance;
  AudioService._internal() {
    AppLogger.info('AudioService initialized', tag: 'AudioService');
  }

  final AudioRecorder _recorder = AudioRecorder();
  bool _isRecording = false;
  String? _currentRecordingPath;

  // Audio quality settings
  static const RecordConfig _recordConfig = RecordConfig(
    encoder: AudioEncoder.aacLc, // CHANGED: wav -> aacLc for better Android compatibility
    sampleRate: 16000, // Optimal for Whisper
    bitRate: 128000, // CHANGED: Reduced bitrate for better compatibility
    numChannels: 1, // Mono
  );

  bool get isRecording => _isRecording;
  String? get currentRecordingPath => _currentRecordingPath;

  Future<bool> hasPermission() async {
    AppLogger.info('Checking microphone permission', tag: 'AudioService');
    final status = await Permission.microphone.status;
    AppLogger.info('Microphone permission status: $status', tag: 'AudioService');
    return status.isGranted;
  }

  Future<bool> requestPermission() async {
    AppLogger.info('Requesting microphone permission', tag: 'AudioService');
    final status = await Permission.microphone.request();
    AppLogger.info('Microphone permission request result: $status', tag: 'AudioService');
    return status.isGranted;
  }

  Future<String?> startRecording() async {
    AppLogger.info('Starting audio recording', tag: 'AudioService');
    try {
      if (!await hasPermission()) {
        AppLogger.warning('No microphone permission, requesting...', tag: 'AudioService');
        if (!await requestPermission()) {
          AppLogger.error('Microphone permission denied', tag: 'AudioService');
          throw Exception('Microphone permission not granted');
        }
      }

      if (_isRecording) {
        AppLogger.warning('Already recording, stopping previous recording', tag: 'AudioService');
        await stopRecording();
      }

      // Generate unique filename
      final directory = await getTemporaryDirectory();
      final filename = 'recording_${const Uuid().v4()}.m4a'; // CHANGED: .wav -> .m4a for AAC
      _currentRecordingPath = '${directory.path}/$filename';
      
      AppLogger.info('Recording path: $_currentRecordingPath', tag: 'AudioService');

      // Start recording
      AppLogger.info('Starting recorder with config: ${_recordConfig.toString()}', tag: 'AudioService');
      await _recorder.start(_recordConfig, path: _currentRecordingPath!);
      _isRecording = true;
      
      AppLogger.info('Recording started successfully', tag: 'AudioService');

      return _currentRecordingPath;
    } catch (e) {
      AppLogger.error('Error starting recording', 
        tag: 'AudioService',
        error: e,
        stackTrace: StackTrace.current,
      );
      _isRecording = false;
      _currentRecordingPath = null;
      return null;
    }
  }

  Future<String?> stopRecording() async {
    AppLogger.info('Stopping audio recording', tag: 'AudioService');
    try {
      if (!_isRecording) {
        AppLogger.warning('Not currently recording', tag: 'AudioService');
        return null;
      }

      final path = await _recorder.stop();
      _isRecording = false;
      
      AppLogger.info('Recording stopped, path: $path', tag: 'AudioService');

      if (path != null && await File(path).exists()) {
        final file = File(path);
        final fileSize = await file.length();
        AppLogger.info('Recording file created successfully - Size: $fileSize bytes', tag: 'AudioService');
        
        if (fileSize == 0) {
          AppLogger.error('Recording file is empty', tag: 'AudioService');
          await file.delete();
          _currentRecordingPath = null;
          return null;
        }
        
        _currentRecordingPath = path;
        return path;
      } else {
        AppLogger.error('Recording file not found or does not exist', tag: 'AudioService');
        _currentRecordingPath = null;
        return null;
      }
    } catch (e) {
      AppLogger.error('Error stopping recording', 
        tag: 'AudioService',
        error: e,
        stackTrace: StackTrace.current,
      );
      _isRecording = false;
      _currentRecordingPath = null;
      return null;
    }
  }

  Future<void> cancelRecording() async {
    AppLogger.info('Canceling audio recording', tag: 'AudioService');
    try {
      if (_isRecording) {
        await _recorder.stop();
        _isRecording = false;
        AppLogger.info('Recording stopped for cancellation', tag: 'AudioService');
      }

      if (_currentRecordingPath != null) {
        final file = File(_currentRecordingPath!);
        if (await file.exists()) {
          await file.delete();
          AppLogger.info('Recording file deleted', tag: 'AudioService');
        }
        _currentRecordingPath = null;
      }
    } catch (e) {
      AppLogger.error('Error canceling recording', tag: 'AudioService', error: e);
    }
  }

  Future<bool> isAmplitudeSupported() async {
    AppLogger.info('Checking amplitude support', tag: 'AudioService');
    try {
      final hasPermission = await _recorder.hasPermission();
      final encoderSupported = await _recorder.isEncoderSupported(AudioEncoder.aacLc);
      final supported = hasPermission && encoderSupported;
      
      AppLogger.info('Amplitude support - Permission: $hasPermission, Encoder: $encoderSupported, Overall: $supported', 
        tag: 'AudioService');
      
      return supported;
    } catch (e) {
      AppLogger.error('Error checking amplitude support', tag: 'AudioService', error: e);
      return false;
    }
  }

  Stream<Amplitude> getAmplitudeStream() {
    AppLogger.info('Getting amplitude stream', tag: 'AudioService');
    return _recorder.onAmplitudeChanged(const Duration(milliseconds: 100));
  }

  Future<Duration?> getRecordingDuration(String filePath) async {
    AppLogger.info('Getting recording duration for: $filePath', tag: 'AudioService');
    try {
      final file = File(filePath);
      if (!await file.exists()) return null;

      // Simple duration calculation for audio files
      final bytes = await file.readAsBytes();
      if (bytes.length < 100) return null; // Basic header check

      // Rough estimation for AAC files (this is approximate)
      final fileSizeKB = bytes.length / 1024;
      final estimatedDurationSeconds = fileSizeKB / 16; // Rough estimate for 128kbps AAC

      final duration = Duration(milliseconds: (estimatedDurationSeconds * 1000).round());
      AppLogger.info('Estimated duration: ${duration.inSeconds}s', tag: 'AudioService');
      
      return duration;
    } catch (e) {
      AppLogger.error('Error getting recording duration', tag: 'AudioService', error: e);
      return null;
    }
  }

  void dispose() {
    AppLogger.info('Disposing AudioService', tag: 'AudioService');
    _recorder.dispose();
  }
}