import 'package:flutter/material.dart';
import '../utils/constants.dart';
import '../models/language_model.dart';

class LanguageSelector extends StatelessWidget {
  final String selectedLanguage;
  final ValueChanged<String> onLanguageChanged;

  const LanguageSelector({
    super.key,
    required this.selectedLanguage,
    required this.onLanguageChanged,
  });

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      value: selectedLanguage,
      decoration: const InputDecoration(
        labelText: 'Language',
        border: OutlineInputBorder(),
        contentPadding: EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 8,
        ),
      ),
      items: AppConstants.supportedLanguages.map((Language language) {
        return DropdownMenuItem<String>(
          value: language.code,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                language.flag,
                style: const TextStyle(fontSize: 20),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      language.name,
                      style: const TextStyle(fontSize: 14),
                    ),
                    if (language.nativeName != language.name)
                      Text(
                        language.nativeName,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        );
      }).toList(),
      onChanged: (String? value) {
        if (value != null) {
          onLanguageChanged(value);
        }
      },
    );
  }
}