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
    _initializeControllers();
    _checkServerStatus();
    _initializeRecorderController();
  }

  void _initializeControllers() {
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
  _recorderController = RecorderController()
    ..androidEncoder = AndroidEncoder.aac  // CHANGED: wav -> aac
    ..androidOutputFormat = AndroidOutputFormat.mpeg4
    ..iosEncoder = IosEncoder.kAudioFormatLinearPCM         // CHANGED: kAudioFormatLinearPCM -> aac
    ..sampleRate = 16000;
}

  Future<void> _checkServerStatus() async {
    final isAvailable = await _whisperService.checkServerHealth();
    setState(() {
      _serverAvailable = isAvailable;
    });
    
    if (!isAvailable) {
      _showSnackBar(
        'Server not available. Start Python backend first.',
        Colors.orange,
      );
    }
  }

  Future<void> _toggleRecording() async {
    if (_isRecording) {
      await _stopRecording();
    } else {
      await _startRecording();
    }
  }

  Future<void> _startRecording() async {
    try {
      if (!_serverAvailable) {
        _showSnackBar('Server not available', Colors.red);
        return;
      }

      final recordingPath = await _audioService.startRecording();
      if (recordingPath != null) {
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
          await _recorderController!.record(path: recordingPath);
        }
      } else {
        _showSnackBar('Failed to start recording', Colors.red);
      }
    } catch (e) {
      _showSnackBar('Recording error: $e', Colors.red);
    }
  }

  Future<void> _stopRecording() async {
    try {
      final recordingPath = await _audioService.stopRecording();
      
      setState(() {
        _isRecording = false;
      });

      _pulseController.stop();
      _waveController.stop();
      
      // Stop waveform recording
      if (_recorderController != null && _recorderController!.isRecording) {
        await _recorderController!.stop();
      }

      if (recordingPath != null) {
        await _transcribeAudio(recordingPath);
      } else {
        _showSnackBar('No recording found', Colors.orange);
      }
    } catch (e) {
      setState(() {
        _isRecording = false;
        _isTranscribing = false;
      });
      _showSnackBar('Stop recording error: $e', Colors.red);
    }
  }

  Future<void> _transcribeAudio(String audioPath) async {
    setState(() {
      _isTranscribing = true;
    });

    try {
      final file = File(audioPath);
      if (!await file.exists()) {
        throw Exception('Audio file not found');
      }

      final response = await _whisperService.transcribeAudio(
        audioFile: file,
        language: _selectedLanguage,
        modelSize: _selectedModel,
      );

      if (response != null && response.success && response.result != null) {
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
        _showSnackBar(
          response?.message ?? 'Transcription failed',
          Colors.red,
        );
      }
    } catch (e) {
      _showSnackBar('Transcription error: $e', Colors.red);
    } finally {
      setState(() {
        _isTranscribing = false;
      });
      
      // Clean up audio file
      try {
        await File(audioPath).delete();
      } catch (e) {
        print('Failed to delete temp file: $e');
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
                                  // Implement clipboard copy
                                  _showSnackBar('Copied to clipboard', Colors.green);
                                },
                                onDelete: () {
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

  @override
  void dispose() {
    _pulseController.dispose();
    _waveController.dispose();
    _recorderController?.dispose();
    _audioService.dispose();
    super.dispose();
  }
}