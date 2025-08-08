// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'transcription_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

TranscriptionSegment _$TranscriptionSegmentFromJson(
        Map<String, dynamic> json) =>
    TranscriptionSegment(
      start: (json['start'] as num).toDouble(),
      end: (json['end'] as num).toDouble(),
      text: json['text'] as String,
      confidence: (json['confidence'] as num).toDouble(),
    );

Map<String, dynamic> _$TranscriptionSegmentToJson(
        TranscriptionSegment instance) =>
    <String, dynamic>{
      'start': instance.start,
      'end': instance.end,
      'text': instance.text,
      'confidence': instance.confidence,
    };

TranscriptionResult _$TranscriptionResultFromJson(Map<String, dynamic> json) =>
    TranscriptionResult(
      text: json['text'] as String,
      language: json['language'] as String,
      detectedLanguage: json['detected_language'] as String?,
      languageConfidence: (json['language_confidence'] as num).toDouble(),
      segments: (json['segments'] as List<dynamic>)
          .map((e) => TranscriptionSegment.fromJson(e as Map<String, dynamic>))
          .toList(),
      modelSize: json['model_size'] as String,
    );

Map<String, dynamic> _$TranscriptionResultToJson(
        TranscriptionResult instance) =>
    <String, dynamic>{
      'text': instance.text,
      'language': instance.language,
      'detected_language': instance.detectedLanguage,
      'language_confidence': instance.languageConfidence,
      'segments': instance.segments,
      'model_size': instance.modelSize,
    };

ApiResponse _$ApiResponseFromJson(Map<String, dynamic> json) => ApiResponse(
      success: json['success'] as bool,
      result: json['result'] == null
          ? null
          : TranscriptionResult.fromJson(
              json['result'] as Map<String, dynamic>),
      error: json['error'] as String?,
      message: json['message'] as String,
    );

Map<String, dynamic> _$ApiResponseToJson(ApiResponse instance) =>
    <String, dynamic>{
      'success': instance.success,
      'result': instance.result,
      'error': instance.error,
      'message': instance.message,
    };
