import 'package:equatable/equatable.dart';

class Language extends Equatable {
  final String code;
  final String name;
  final String nativeName;
  final String flag;
  final bool isRTL;

  const Language({
    required this.code,
    required this.name,
    required this.nativeName,
    required this.flag,
    this.isRTL = false,
  });

  // Simple manual serialization - no code generation needed
  factory Language.fromJson(Map<String, dynamic> json) {
    return Language(
      code: json['code'] as String,
      name: json['name'] as String,
      nativeName: json['nativeName'] as String,
      flag: json['flag'] as String,
      isRTL: json['isRTL'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'code': code,
      'name': name,
      'nativeName': nativeName,
      'flag': flag,
      'isRTL': isRTL,
    };
  }

  @override
  List<Object> get props => [code, name, nativeName, flag, isRTL];
}