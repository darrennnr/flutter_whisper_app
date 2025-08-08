import 'dart:io';
import 'dart:typed_data';
import 'package:record/record.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

class AudioService {
  static final AudioService _instance = AudioService._internal();
  factory AudioService() => _instance;
  AudioService._internal();

  final AudioRecorder _recorder = AudioRecorder();
  bool _isRecording = false;
  String? _currentRecordingPath;

  // Audio quality settings
  static const RecordConfig _recordConfig = RecordConfig(
    encoder: AudioEncoder.wav,
    sampleRate: 16000, // Optimal for Whisper
    bitRate: 256000,
    numChannels: 1, // Mono
  );

  bool get isRecording => _isRecording;
  String? get currentRecordingPath => _currentRecordingPath;

  Future<bool> hasPermission() async {
    final status = await Permission.microphone.status;
    return status.isGranted;
  }

  Future<bool> requestPermission() async {
    final status = await Permission.microphone.request();
    return status.isGranted;
  }

  Future<String?> startRecording() async {
    try {
      if (!await hasPermission()) {
        if (!await requestPermission()) {
          throw Exception('Microphone permission not granted');
        }
      }

      if (_isRecording) {
        await stopRecording();
      }

      // Generate unique filename
      final directory = await getTemporaryDirectory();
      final filename = 'recording_${const Uuid().v4()}.wav';
      _currentRecordingPath = '${directory.path}/$filename';

      // Start recording
      await _recorder.start(_recordConfig, path: _currentRecordingPath!);
      _isRecording = true;

      return _currentRecordingPath;
    } catch (e) {
      print('Error starting recording: $e');
      _isRecording = false;
      _currentRecordingPath = null;
      return null;
    }
  }

  Future<String?> stopRecording() async {
    try {
      if (!_isRecording) return null;

      final path = await _recorder.stop();
      _isRecording = false;

      if (path != null && await File(path).exists()) {
        _currentRecordingPath = path;
        return path;
      } else {
        _currentRecordingPath = null;
        return null;
      }
    } catch (e) {
      print('Error stopping recording: $e');
      _isRecording = false;
      _currentRecordingPath = null;
      return null;
    }
  }

  Future<void> cancelRecording() async {
    try {
      if (_isRecording) {
        await _recorder.stop();
        _isRecording = false;
      }

      if (_currentRecordingPath != null) {
        final file = File(_currentRecordingPath!);
        if (await file.exists()) {
          await file.delete();
        }
        _currentRecordingPath = null;
      }
    } catch (e) {
      print('Error canceling recording: $e');
    }
  }

  Future<bool> isAmplitudeSupported() async {
    return await _recorder.hasPermission() && await _recorder.isEncoderSupported(AudioEncoder.wav);
  }

  Stream<Amplitude> getAmplitudeStream() {
    return _recorder.onAmplitudeChanged(const Duration(milliseconds: 100));
  }

  Future<Duration?> getRecordingDuration(String filePath) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) return null;

      // Simple duration calculation for WAV files
      // This is a basic implementation - you might want to use a more robust solution
      final bytes = await file.readAsBytes();
      if (bytes.length < 44) return null; // WAV header is 44 bytes

      // Extract sample rate from WAV header (bytes 24-27)
      final sampleRate = ByteData.view(bytes.buffer).getUint32(24, Endian.little);
      
      // Calculate duration based on file size and sample rate
      final audioDataSize = bytes.length - 44; // Subtract WAV header size
      final bytesPerSample = 2; // 16-bit samples
      final numChannels = 1; // Mono
      final numSamples = audioDataSize ~/ (bytesPerSample * numChannels);
      final durationSeconds = numSamples / sampleRate;

      return Duration(milliseconds: (durationSeconds * 1000).round());
    } catch (e) {
      print('Error getting recording duration: $e');
      return null;
    }
  }

  void dispose() {
    _recorder.dispose();
  }
}