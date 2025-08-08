import whisper
import torch
import librosa
import numpy as np

class LanguageDetector:
    def __init__(self):
        self.model = whisper.load_model("tiny")  # Fast model for detection
        
        # Language confidence thresholds
        self.confidence_thresholds = {
            'high': 0.8,
            'medium': 0.6,
            'low': 0.4
        }
    
    def detect_language_advanced(self, audio_path, top_k=3):
        """Advanced language detection with multiple candidates"""
        try:
            # Load and preprocess audio
            audio, _ = librosa.load(audio_path, sr=16000)
            audio = whisper.pad_or_trim(audio)
            
            # Create mel spectrogram
            mel = whisper.log_mel_spectrogram(audio).to(self.model.device)
            
            # Detect language probabilities
            _, probs = self.model.detect_language(mel)
            
            # Get top k languages
            sorted_langs = sorted(probs.items(), key=lambda x: x[1], reverse=True)
            
            result = {
                'primary': {
                    'language': sorted_langs[0][0],
                    'confidence': sorted_langs[0][1],
                    'confidence_level': self._get_confidence_level(sorted_langs[0][1])
                },
                'alternatives': []
            }
            
            # Add alternatives
            for lang, conf in sorted_langs[1:top_k]:
                result['alternatives'].append({
                    'language': lang,
                    'confidence': conf,
                    'confidence_level': self._get_confidence_level(conf)
                })
            
            return result
            
        except Exception as e:
            print(f"Language detection error: {e}")
            return None
    
    def _get_confidence_level(self, confidence):
        """Convert confidence score to level"""
        if confidence >= self.confidence_thresholds['high']:
            return 'high'
        elif confidence >= self.confidence_thresholds['medium']:
            return 'medium'
        elif confidence >= self.confidence_thresholds['low']:
            return 'low'
        else:
            return 'very_low'