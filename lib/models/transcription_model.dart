import 'package:json_annotation/json_annotation.dart';
import 'package:equatable/equatable.dart';
import '../models/language_model.dart';  // ADD this import

part 'transcription_model.g.dart';

@JsonSerializable()
class TranscriptionSegment extends Equatable {
  final double start;
  final double end;
  final String text;
  final double confidence;

  const TranscriptionSegment({
    required this.start,
    required this.end,
    required this.text,
    required this.confidence,
  });

  factory TranscriptionSegment.fromJson(Map<String, dynamic> json) =>
      _$TranscriptionSegmentFromJson(json);

  Map<String, dynamic> toJson() => _$TranscriptionSegmentToJson(this);

  @override
  List<Object> get props => [start, end, text, confidence];
}

@JsonSerializable()
class TranscriptionResult extends Equatable {
  final String text;
  final String language;
  @JsonKey(name: 'detected_language')
  final String? detectedLanguage;
  @JsonKey(name: 'language_confidence')
  final double languageConfidence;
  final List<TranscriptionSegment> segments;
  @JsonKey(name: 'model_size')
  final String modelSize;

  const TranscriptionResult({
    required this.text,
    required this.language,
    this.detectedLanguage,
    required this.languageConfidence,
    required this.segments,
    required this.modelSize,
  });

  factory TranscriptionResult.fromJson(Map<String, dynamic> json) =>
      _$TranscriptionResultFromJson(json);

  Map<String, dynamic> toJson() => _$TranscriptionResultToJson(this);

  @override
  List<Object?> get props => [
        text,
        language,
        detectedLanguage,
        languageConfidence,
        segments,
        modelSize,
      ];
}

@JsonSerializable()
class ApiResponse extends Equatable {
  final bool success;
  final TranscriptionResult? result;
  final String? error;
  final String message;

  const ApiResponse({
    required this.success,
    this.result,
    this.error,
    required this.message,
  });

  factory ApiResponse.fromJson(Map<String, dynamic> json) =>
      _$ApiResponseFromJson(json);

  Map<String, dynamic> toJson() => _$ApiResponseToJson(this);

  @override
  List<Object?> get props => [success, result, error, message];
}