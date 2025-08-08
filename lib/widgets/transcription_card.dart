import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/transcription_model.dart';
import '../models/language_model.dart';
import '../utils/constants.dart';
import '../utils/logger.dart';

class TranscriptionCard extends StatefulWidget {
  final TranscriptionResult result;
  final bool isLatest;
  final ValueChanged<String>? onCopy;
  final VoidCallback? onDelete;

  const TranscriptionCard({
    super.key,
    required this.result,
    this.isLatest = false,
    this.onCopy,
    this.onDelete,
  });

  @override
  State<TranscriptionCard> createState() => _TranscriptionCardState();
}

class _TranscriptionCardState extends State<TranscriptionCard> {
  bool _showSegments = false;

  Language? get _detectedLanguage {
    return AppConstants.supportedLanguages.firstWhere(
      (lang) => lang.code == widget.result.language,
      orElse: () => AppConstants.supportedLanguages.first,
    );
  }

  Color get _confidenceColor {
    final confidence = widget.result.languageConfidence;
    if (confidence >= 0.8) return Colors.green;
    if (confidence >= 0.6) return Colors.orange;
    return Colors.red;
  }

  String get _confidenceText {
    final confidence = widget.result.languageConfidence;
    if (confidence >= 0.8) return 'High';
    if (confidence >= 0.6) return 'Medium';
    return 'Low';
  }

  Future<void> _copyToClipboard() async {
    AppLogger.info('Copying text to clipboard', tag: 'TranscriptionCard');
    await Clipboard.setData(ClipboardData(text: widget.result.text));
    if (widget.onCopy != null) {
      widget.onCopy!(widget.result.text);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isRTL = _detectedLanguage?.isRTL ?? false;
    
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: widget.isLatest ? 4 : 2,
      child: Container(
        decoration: widget.isLatest
            ? BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Theme.of(context).colorScheme.primary,
                  width: 2,
                ),
              )
            : null,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Row
              Row(
                children: [
                  // Language Info
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _detectedLanguage?.flag ?? '🌐',
                          style: const TextStyle(fontSize: 16),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _detectedLanguage?.name ?? 'Unknown',
                          style: TextStyle(
                            fontSize: 12,
                            color: Theme.of(context).colorScheme.primary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(width: 8),
                  
                  // Confidence Badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: _confidenceColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: _confidenceColor,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _confidenceText,
                          style: TextStyle(
                            fontSize: 11,
                            color: _confidenceColor,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  const Spacer(),
                  
                  // Model Badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.grey.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      widget.result.modelSize.toUpperCase(),
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  
                  // Actions
                  PopupMenuButton<String>(
                    onSelected: (value) {
                      AppLogger.info('Transcription card action: $value', tag: 'TranscriptionCard');
                      switch (value) {
                        case 'copy':
                          _copyToClipboard();
                          break;
                        case 'segments':
                          setState(() {
                            _showSegments = !_showSegments;
                          });
                          break;
                        case 'delete':
                          widget.onDelete?.call();
                          break;
                      }
                    },
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: 'copy',
                        child: Row(
                          children: [
                            Icon(Icons.copy, size: 20),
                            SizedBox(width: 8),
                            Text('Copy'),
                          ],
                        ),
                      ),
                      PopupMenuItem(
                        value: 'segments',
                        child: Row(
                          children: [
                            Icon(
                              _showSegments ? Icons.visibility_off : Icons.visibility,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Text(_showSegments ? 'Hide Segments' : 'Show Segments'),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(Icons.delete, size: 20, color: Colors.red),
                            SizedBox(width: 8),
                            Text('Delete', style: TextStyle(color: Colors.red)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              
              const SizedBox(height: 12),
              
              // Main Text
              Directionality(
                textDirection: isRTL ? TextDirection.rtl : TextDirection.ltr,
                child: Text(
                  widget.result.text,
                  style: const TextStyle(
                    fontSize: 16,
                    height: 1.4,
                  ),
                ),
              ),
              
              // Segments (if expanded)
              if (_showSegments && widget.result.segments.isNotEmpty) ...[
                const SizedBox(height: 16),
                const Divider(),
                const SizedBox(height: 8),
                Text(
                  'Segments',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                ...widget.result.segments.map((segment) {
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: Colors.grey.withOpacity(0.3),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              '${_formatTime(segment.start)} - ${_formatTime(segment.end)}',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const Spacer(),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: _getConfidenceColor(segment.confidence).withOpacity(0.2),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                '${(segment.confidence * 100).toStringAsFixed(1)}%',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: _getConfidenceColor(segment.confidence),
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Directionality(
                          textDirection: isRTL ? TextDirection.rtl : TextDirection.ltr,
                          child: Text(
                            segment.text,
                            style: const TextStyle(fontSize: 14),
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ],
            ],
          ),
        ),
      ),
    );
  }

  String _formatTime(double seconds) {
    final minutes = (seconds / 60).floor();
    final remainingSeconds = (seconds % 60).floor();
    return '${minutes.toString().padLeft(2, '0')}:${remainingSeconds.toString().padLeft(2, '0')}';
  }

  Color _getConfidenceColor(double confidence) {
    if (confidence >= 0.8) return Colors.green;
    if (confidence >= 0.6) return Colors.orange;
    return Colors.red;
  }
}