import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:avatar_glow/avatar_glow.dart';
import 'package:audio_waveforms/audio_waveforms.dart';
import '../services/whisper_service.dart';
import '../services/audio_service.dart';
import '../models/transcription_model.dart';
import '../models/language_model.dart';
import '../utils/constants.dart';
import '../widgets/language_selector.dart';
import '../widgets/transcription_card.dart';
import '../widgets/audio_visualizer.dart';
import '../utils/logger.dart';

class SpeechScreen extends StatefulWidget {
  const SpeechScreen({super.key});

  @override
  State<SpeechScreen> createState() => _SpeechScreenState();
}

class _SpeechScreenState extends State<SpeechScreen>
    with TickerProviderStateMixin {
  final WhisperService _whisperService = WhisperService();
  final AudioService _audioService = AudioService();
  
  // Controllers
  late AnimationController _pulseController;
  late AnimationController _waveController;
  RecorderController? _recorderController;
  
  // State variables
  bool _isRecording = false;
  bool _isTranscribing = false;
  bool _serverAvailable = false;
  String _selectedLanguage = 'auto';
  String _selectedModel = 'base';
  TranscriptionResult? _lastResult;
  List<TranscriptionResult> _transcriptionHistory = [];
  String? _currentRecordingPath;
  Duration _recordingDuration = Duration.zero;

  @override
  void initState() {
    super.initState();
    AppLogger.info('SpeechScreen initializing', tag: 'SpeechScreen');
    _initializeControllers();
    _checkServerStatus();
    _initializeRecorderController();
  }

  void _initializeControllers() {
    AppLogger.info('Initializing animation controllers', tag: 'SpeechScreen');
    _pulseController = AnimationController(
      duration: const Duration(seconds: 1),
      vsync: this,
    );
    
    _waveController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );
  }

  void _initializeRecorderController() {
    AppLogger.info('Initializing recorder controller', tag: 'SpeechScreen');
    try {
      _recorderController = RecorderController()
        ..androidEncoder = AndroidEncoder.aac
        ..androidOutputFormat = AndroidOutputFormat.mpeg4
        ..iosEncoder = IosEncoder.kAudioFormatMPEG4AAC
        ..sampleRate = 16000;
      AppLogger.info('Recorder controller initialized successfully', tag: 'SpeechScreen');
    } catch (e) {
      AppLogger.error('Error initializing recorder controller', 
        tag: 'SpeechScreen',
        error: e,
        stackTrace: StackTrace.current,
      );
    }
  }

  Future<void> _checkServerStatus() async {
    AppLogger.info('Checking server status', tag: 'SpeechScreen');
    
    // ADDED: Try to get ngrok URL from environment or use default
    final ngrokUrl = const String.fromEnvironment('NGROK_URL', defaultValue: '');
    if (ngrokUrl.isNotEmpty) {
      AppLogger.info('Using ngrok URL: $ngrokUrl', tag: 'SpeechScreen');
      _whisperService.updateBaseUrl(ngrokUrl);
    }
    
    final isAvailable = await _whisperService.checkServerHealth();
    
    AppLogger.info('Server status check completed - Available: $isAvailable', tag: 'SpeechScreen');
    
    setState(() {
      _serverAvailable = isAvailable;
    });
    
    if (!isAvailable) {
      AppLogger.warning('Server not available', tag: 'SpeechScreen');
      _showSnackBar(
        'Server not available. Start Python backend first.',
        Colors.orange,
      );
    } else {
      AppLogger.info('Server is available and ready', tag: 'SpeechScreen');
    }
  }

  Future<void> _toggleRecording() async {
    AppLogger.info('Toggle recording - Current state: $_isRecording', tag: 'SpeechScreen');
    if (_isRecording) {
      await _stopRecording();
    } else {
      await _startRecording();
    }
  }

  Future<void> _startRecording() async {
    AppLogger.info('Starting recording process', tag: 'SpeechScreen');
    try {
      if (!_serverAvailable) {
        AppLogger.warning('Cannot start recording - server not available', tag: 'SpeechScreen');
        _showSnackBar('Server not available', Colors.red);
        return;
      }

      AppLogger.info('Calling audio service to start recording', tag: 'SpeechScreen');
      final recordingPath = await _audioService.startRecording();
      
      if (recordingPath != null) {
        AppLogger.info('Recording started successfully at: $recordingPath', tag: 'SpeechScreen');
        setState(() {
          _isRecording = true;
          _currentRecordingPath = recordingPath;
          _recordingDuration = Duration.zero;
        });

        _pulseController.repeat();
        _waveController.repeat();
        _startRecordingTimer();
        
        // Start waveform recording if available
        if (_recorderController != null) {
          AppLogger.info('Starting waveform recording', tag: 'SpeechScreen');
          await _recorderController!.record(path: recordingPath);
        }
      } else {
        AppLogger.error('Failed to start recording - null path returned', tag: 'SpeechScreen');
        _showSnackBar('Failed to start recording', Colors.red);
      }
    } catch (e) {
      AppLogger.error('Error starting recording', 
        tag: 'SpeechScreen',
        error: e,
        stackTrace: StackTrace.current,
      );
      _showSnackBar('Recording error: $e', Colors.red);
    }
  }

  Future<void> _stopRecording() async {
    AppLogger.info('Stopping recording process', tag: 'SpeechScreen');
    try {
      final recordingPath = await _audioService.stopRecording();
      
      AppLogger.info('Recording stopped, path: $recordingPath', tag: 'SpeechScreen');
      
      setState(() {
        _isRecording = false;
      });

      _pulseController.stop();
      _waveController.stop();
      
      // Stop waveform recording
      if (_recorderController != null && _recorderController!.isRecording) {
        AppLogger.info('Stopping waveform recording', tag: 'SpeechScreen');
        await _recorderController!.stop();
      }

      if (recordingPath != null) {
        AppLogger.info('Starting transcription for: $recordingPath', tag: 'SpeechScreen');
        await _transcribeAudio(recordingPath);
      } else {
        AppLogger.warning('No recording path available for transcription', tag: 'SpeechScreen');
        _showSnackBar('No recording found', Colors.orange);
      }
    } catch (e) {
      AppLogger.error('Error stopping recording', 
        tag: 'SpeechScreen',
        error: e,
        stackTrace: StackTrace.current,
      );
      setState(() {
        _isRecording = false;
        _isTranscribing = false;
      });
      _showSnackBar('Stop recording error: $e', Colors.red);
    }
  }

  Future<void> _transcribeAudio(String audioPath) async {
    AppLogger.info('Starting transcription for: $audioPath', tag: 'SpeechScreen');
    setState(() {
      _isTranscribing = true;
    });

    try {
      final file = File(audioPath);
      if (!await file.exists()) {
        AppLogger.error('Audio file not found: $audioPath', tag: 'SpeechScreen');
        throw Exception('Audio file not found');
      }
      
      final fileSize = await file.length();
      AppLogger.info('Audio file validated - Size: $fileSize bytes', tag: 'SpeechScreen');

      AppLogger.info('Calling whisper service for transcription', 
        tag: 'SpeechScreen',
        data: {
          'language': _selectedLanguage,
          'modelSize': _selectedModel,
          'fileSize': fileSize,
        }
      );
      
      final response = await _whisperService.transcribeAudio(
        audioFile: file,
        language: _selectedLanguage,
        modelSize: _selectedModel,
      );

      AppLogger.info('Transcription response received', 
        tag: 'SpeechScreen',
        data: {
          'success': response?.success,
          'hasResult': response?.result != null,
          'message': response?.message,
        }
      );

      if (response != null && response.success && response.result != null) {
        AppLogger.info('Transcription successful', 
          tag: 'SpeechScreen',
          data: {
            'textLength': response.result!.text.length,
            'language': response.result!.language,
            'segmentCount': response.result!.segments.length,
          }
        );
        
        setState(() {
          _lastResult = response.result;
          _transcriptionHistory.insert(0, response.result!);
          
          // Keep only last 20 results
          if (_transcriptionHistory.length > 20) {
            _transcriptionHistory = _transcriptionHistory.take(20).toList();
          }
        });

        _showSnackBar('Transcription completed!', Colors.green);
      } else {
        final errorMsg = response?.message ?? 'Transcription failed';
        AppLogger.error('Transcription failed: $errorMsg', tag: 'SpeechScreen');
        _showSnackBar(
          errorMsg,
          Colors.red,
        );
      }
    } catch (e) {
      AppLogger.error('Transcription error', 
        tag: 'SpeechScreen',
        error: e,
        stackTrace: StackTrace.current,
      );
      _showSnackBar('Transcription error: $e', Colors.red);
    } finally {
      setState(() {
        _isTranscribing = false;
      });
      
      // Clean up audio file
      try {
        AppLogger.info('Cleaning up audio file: $audioPath', tag: 'SpeechScreen');
        await File(audioPath).delete();
      } catch (e) {
        AppLogger.warning('Failed to delete temp file', tag: 'SpeechScreen', error: e);
      }
    }
  }

  void _startRecordingTimer() {
    if (_isRecording) {
      Future.delayed(const Duration(seconds: 1), () {
        if (_isRecording) {
          setState(() {
            _recordingDuration = _recordingDuration + const Duration(seconds: 1);
          });
          _startRecordingTimer();
        }
      });
    }
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    String minutes = twoDigits(duration.inMinutes);
    String seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }

  void _showSnackBar(String message, Color color) {
    AppLogger.info('Showing snackbar: $message', tag: 'SpeechScreen');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _clearHistory() {
    AppLogger.info('Clearing transcription history', tag: 'SpeechScreen');
    setState(() {
      _transcriptionHistory.clear();
      _lastResult = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Whisper STT'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        elevation: 0,
        actions: [
          // Server status indicator
          Container(
            margin: const EdgeInsets.only(right: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: _serverAvailable ? Colors.green : Colors.red,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  _serverAvailable ? 'Online' : 'Offline',
                  style: TextStyle(
                    fontSize: 12,
                    color: _serverAvailable ? Colors.green : Colors.red,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: _checkServerStatus,
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh server status',
          ),
          IconButton(
            onPressed: _clearHistory,
            icon: const Icon(Icons.clear_all),
            tooltip: 'Clear history',
          ),
          // ADDED: Settings button for ngrok URL
          IconButton(
            onPressed: () => _showSettingsDialog(),
            icon: const Icon(Icons.settings),
            tooltip: 'Settings',
          ),
        ],
      ),
      body: Column(
        children: [
          // Settings Section
          Container(
            padding: const EdgeInsets.all(16),
            color: Theme.of(context).colorScheme.surface,
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: LanguageSelector(
                        selectedLanguage: _selectedLanguage,
                        onLanguageChanged: (language) {
                          AppLogger.info('Language changed to: $language', tag: 'SpeechScreen');
                          setState(() {
                            _selectedLanguage = language;
                          });
                        },
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _selectedModel,
                        decoration: const InputDecoration(
                          labelText: 'Model',
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                        ),
                        items: AppConstants.modelSizes.entries.map((entry) {
                          return DropdownMenuItem(
                            value: entry.key,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(entry.value['name']!),
                                Text(
                                  '${entry.value['size']} • ${entry.value['accuracy']}',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: Colors.grey,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                        onChanged: (value) {
                          if (value != null) {
                            AppLogger.info('Model changed to: $value', tag: 'SpeechScreen');
                            setState(() {
                              _selectedModel = value;
                            });
                          }
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Recording Section
          Expanded(
            flex: 2,
            child: Container(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Status Text
                  Text(
                    _isTranscribing
                        ? 'Transcribing...'
                        : _isRecording
                            ? 'Recording...'
                            : 'Tap to start recording',
                    style: Theme.of(context).textTheme.headlineSmall,
                    textAlign: TextAlign.center,
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Recording Duration
                  if (_isRecording)
                    Text(
                      _formatDuration(_recordingDuration),
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: Colors.red,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  
                  const SizedBox(height: 32),
                  
                  // Recording Button with Animation
                  GestureDetector(
                    onTap: _isTranscribing ? null : _toggleRecording,
                    child: AvatarGlow(
                      animate: _isRecording,
                      glowColor: _isRecording ? Colors.red : Colors.blue,
                      duration: const Duration(milliseconds: 2000),
                      child: Container(
                        width: 120,
                        height: 120,
                        decoration: BoxDecoration(
                          color: _isTranscribing
                              ? Colors.grey
                              : _isRecording
                                  ? Colors.red
                                  : Colors.blue,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.2),
                              blurRadius: 10,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: Icon(
                          _isTranscribing
                              ? Icons.hourglass_empty
                              : _isRecording
                                  ? Icons.stop
                                  : Icons.mic,
                          size: 48,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 32),
                  
                  // Audio Visualizer
                  if (_isRecording && _recorderController != null)
                    SizedBox(
                      height: 80,
                      child: AudioWaveforms(
                        size: Size(MediaQuery.of(context).size.width - 48, 80),
                        recorderController: _recorderController!,
                        waveStyle: const WaveStyle(
                          waveColor: Colors.blue,
                          extendWaveform: true,
                          showMiddleLine: false,
                        ),
                      ),
                    ),
                  
                  // Progress indicator for transcription
                  if (_isTranscribing)
                    const Padding(
                      padding: EdgeInsets.only(top: 16),
                      child: LinearProgressIndicator(),
                    ),
                ],
              ),
            ),
          ),

          // Results Section
          Expanded(
            flex: 3,
            child: Container(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(24),
                  topRight: Radius.circular(24),
                ),
              ),
              child: Column(
                children: [
                  // Section Header
                  Container(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Icon(
                          Icons.history,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Transcription Results',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const Spacer(),
                        Text(
                          '${_transcriptionHistory.length} results',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  
                  const Divider(height: 1),
                  
                  // Results List
                  Expanded(
                    child: _transcriptionHistory.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.mic_none,
                                  size: 64,
                                  color: Colors.grey[400],
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'No transcriptions yet',
                                  style: TextStyle(
                                    fontSize: 18,
                                    color: Colors.grey[600],
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Start recording to see results here',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey[500],
                                  ),
                                ),
                              ],
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.all(16),
                            itemCount: _transcriptionHistory.length,
                            itemBuilder: (context, index) {
                              return TranscriptionCard(
                                result: _transcriptionHistory[index],
                                isLatest: index == 0,
                                onCopy: (text) {
                                  AppLogger.info('Text copied to clipboard', tag: 'SpeechScreen');
                                  // Implement clipboard copy
                                  _showSnackBar('Copied to clipboard', Colors.green);
                                },
                                onDelete: () {
                                  AppLogger.info('Deleting transcription at index: $index', tag: 'SpeechScreen');
                                  setState(() {
                                    _transcriptionHistory.removeAt(index);
                                  });
                                },
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  // ADDED: Settings dialog for ngrok URL
  void _showSettingsDialog() {
    final TextEditingController urlController = TextEditingController(
      text: _whisperService.baseUrl,
    );
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Server Settings'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: urlController,
              decoration: const InputDecoration(
                labelText: 'Server URL',
                hintText: 'https://your-ngrok-url.ngrok.io',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Enter your ngrok URL or server address',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final newUrl = urlController.text.trim();
              if (newUrl.isNotEmpty) {
                AppLogger.info('Updating server URL to: $newUrl', tag: 'SpeechScreen');
                _whisperService.updateBaseUrl(newUrl);
                Navigator.pop(context);
                _checkServerStatus();
              }
            },
            child: const Text('Update'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    AppLogger.info('Disposing SpeechScreen', tag: 'SpeechScreen');
    _pulseController.dispose();
    _waveController.dispose();
    _recorderController?.dispose();
    _audioService.dispose();
    super.dispose();
  }
}