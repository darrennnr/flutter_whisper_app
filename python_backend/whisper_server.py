import whisper
import torch
import os
import tempfile
import asyncio
import gc
import time
from fastapi import FastAPI, File, UploadFile, Form
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
import librosa
import numpy as np
from pydub import AudioSegment
import logging
from typing import Optional

# Setup logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

app = FastAPI(title="Whisper STT API", version="2.0.0")

# Enable CORS
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

class WhisperSTT:
    def __init__(self):
        # Load ALL available Whisper models for maximum accuracy
        self.models = {
            'tiny': None,
            'tiny.en': None,
            'base': None,
            'base.en': None,
            'small': None,
            'small.en': None,
            'medium': None,
            'medium.en': None,
            'large': None,        # Added missing models
            'large-v1': None,     # Added missing models
            'large-v2': None,     # Added missing models
            'large-v3': None      # Added latest model (best accuracy)
        }
        self.current_model = None
        self.model_size = 'base'  # Default
        
        # Enhanced language configurations with better prompts
        self.supported_languages = {
            'en': {'name': 'English', 'code': 'en'},
            'id': {'name': 'Indonesian', 'code': 'id'}, 
            'ar': {'name': 'Arabic', 'code': 'ar'},
            'ms': {'name': 'Malay', 'code': 'ms'},
            'zh': {'name': 'Chinese', 'code': 'zh'},
            'ja': {'name': 'Japanese', 'code': 'ja'},
            'ko': {'name': 'Korean', 'code': 'ko'},
            'auto': {'name': 'Auto Detect', 'code': 'auto'}
        }
        
        # Initialize with base model
        self._load_model('base')
    
    def _load_model(self, model_size='base'):
        """Load Whisper model with specified size and better error handling"""
        try:
            if model_size not in self.models:
                logger.warning(f"Model {model_size} not available, falling back to base")
                model_size = 'base'
                
            if self.models[model_size] is None:
                logger.info(f"Loading Whisper {model_size} model...")
                device = "cuda" if torch.cuda.is_available() else "cpu"
                
                # Try to load model with error handling for unavailable models
                try:
                    self.models[model_size] = whisper.load_model(model_size, device=device)
                    logger.info(f"Model {model_size} loaded successfully on {device}")
                except Exception as model_error:
                    logger.error(f"Failed to load {model_size}: {model_error}")
                    # Fallback to smaller model
                    fallback_models = ['base', 'tiny', 'small']
                    for fallback in fallback_models:
                        if fallback != model_size:
                            try:
                                self.models[fallback] = whisper.load_model(fallback, device=device)
                                model_size = fallback
                                logger.info(f"Fallback to {fallback} successful")
                                break
                            except:
                                continue
            
            self.current_model = self.models[model_size]
            self.model_size = model_size
            return True
        except Exception as e:
            logger.error(f"Critical error loading any model: {str(e)}")
            return False
    
    def preprocess_audio(self, audio_file_path, preserve_full_audio=True):
        """Enhanced audio preprocessing with option to preserve full audio"""
        try:
            # Load audio with librosa (automatically converts to 16kHz mono)
            audio, sr = librosa.load(audio_file_path, sr=16000, mono=True)
            
            if preserve_full_audio:
                # Minimal preprocessing to preserve full audio content
                # Only normalize without aggressive trimming
                audio = librosa.util.normalize(audio)
                
                # Very gentle noise reduction
                audio = librosa.effects.preemphasis(audio, coef=0.95)
                
                # Only remove extreme silence (very low threshold)
                audio, _ = librosa.effects.trim(audio, top_db=10)
            else:
                # More aggressive preprocessing for noisy audio
                audio = librosa.util.normalize(audio)
                audio, _ = librosa.effects.trim(audio, top_db=20)
                audio = librosa.effects.preemphasis(audio)
            
            return audio
        except Exception as e:
            logger.error(f"Error preprocessing audio: {str(e)}")
            return None
    
    def detect_language(self, audio):
        """Enhanced language detection with better confidence scoring"""
        try:
            # Use longer audio sample for better detection
            audio_tensor = whisper.pad_or_trim(audio)
            mel = whisper.log_mel_spectrogram(audio_tensor).to(self.current_model.device)
            
            _, probs = self.current_model.detect_language(mel)
            detected_lang = max(probs, key=probs.get)
            confidence = probs[detected_lang]
            
            # Log top 3 language candidates for debugging
            sorted_langs = sorted(probs.items(), key=lambda x: x[1], reverse=True)[:3]
            logger.info(f"Language detection - Top 3: {sorted_langs}")
            
            return detected_lang, confidence
        except Exception as e:
            logger.error(f"Error detecting language: {str(e)}")
            return 'en', 0.5
    
    def transcribe_audio(self, audio_file_path, language=None, model_size='base', high_accuracy=True):
        """Enhanced transcription with optimized parameters for different content types"""
        try:
            # Load model if different size requested
            if model_size != self.model_size:
                if not self._load_model(model_size):
                    return None
            
            # Enhanced preprocessing - preserve full audio for religious/formal content
            preserve_full = language == 'ar' or 'quran' in str(audio_file_path).lower() or 'surah' in str(audio_file_path).lower()
            audio = self.preprocess_audio(audio_file_path, preserve_full_audio=preserve_full)
            
            if audio is None:
                return None
            
            # Detect language if not specified
            detected_language = None
            language_confidence = 0.0
            
            if language is None or language == 'auto':
                detected_language, language_confidence = self.detect_language(audio)
                language = detected_language
            
            # Enhanced transcription options based on language and model
            base_options = {
                'language': language,
                'task': 'transcribe',
                'temperature': 0.0 if high_accuracy else [0.0, 0.2, 0.4, 0.6, 0.8],
                'fp16': torch.cuda.is_available(),
                'condition_on_previous_text': True,
                'initial_prompt': self._get_language_prompt(language),
                'suppress_tokens': [-1],
            }
            
            # Model-specific and language-specific optimizations
            if model_size in ['large', 'large-v1', 'large-v2', 'large-v3']:
                # Large models - maximum accuracy settings
                options = {
                    **base_options,
                    'beam_size': 5,
                    'best_of': 5,
                    'patience': 2.0,
                    'compression_ratio_threshold': 2.4,
                    'logprob_threshold': -1.0,
                    'no_speech_threshold': 0.3,  # Lower threshold for better detection
                }
            elif model_size in ['medium', 'medium.en']:
                # Medium models - balanced settings
                options = {
                    **base_options,
                    'beam_size': 3,
                    'best_of': 3,
                    'patience': 1.5,
                    'compression_ratio_threshold': 2.4,
                    'logprob_threshold': -1.0,
                    'no_speech_threshold': 0.4,  # FIXED: Lower threshold for medium model
                }
            else:
                # Smaller models - faster settings
                options = {
                    **base_options,
                    'beam_size': 1,
                    'best_of': 1,
                    'patience': 1.0,
                    'compression_ratio_threshold': 2.4,
                    'logprob_threshold': -1.0,
                    'no_speech_threshold': 0.5,
                }
            
            # Language-specific adjustments
            if language == 'ar':
                # Arabic-specific optimizations
                options['no_speech_threshold'] = 0.2  # Even lower for Arabic
                options['compression_ratio_threshold'] = 3.0
                options['logprob_threshold'] = -1.2
            elif language == 'id':
                # Indonesian-specific optimizations
                options['no_speech_threshold'] = 0.3
                options['compression_ratio_threshold'] = 2.8
            
            logger.info(f"Transcribing with model {model_size}, language {language}, options: {options}")
            
            # Perform transcription
            result = self.current_model.transcribe(audio, **options)
            
            # Enhanced segment processing with confidence calculation
            segments = []
            total_confidence = 0.0
            segment_count = 0
            
            for segment in result.get('segments', []):
                if segment['text'].strip():  # Only include non-empty segments
                    confidence = segment.get('avg_logprob', 0.0)
                    segments.append({
                        'start': segment['start'],
                        'end': segment['end'],
                        'text': segment['text'].strip(),
                        'confidence': confidence,
                        'no_speech_prob': segment.get('no_speech_prob', 0.0)
                    })
                    total_confidence += confidence
                    segment_count += 1
            
            # Calculate overall confidence
            overall_confidence = total_confidence / segment_count if segment_count > 0 else 0.0
            
            # Enhanced result with quality metrics
            enhanced_result = {
                'text': result['text'].strip(),
                'language': result.get('language', language),
                'detected_language': detected_language,
                'language_confidence': language_confidence,
                'segments': segments,
                'model_size': model_size,
                'overall_confidence': overall_confidence,
                'segment_count': segment_count,
                'audio_duration': len(audio) / 16000,  # Duration in seconds
                'quality_metrics': {
                    'avg_confidence': overall_confidence,
                    'segment_count': segment_count,
                    'text_length': len(result['text'].strip()),
                    'words_per_segment': len(result['text'].split()) / max(segment_count, 1)
                }
            }
            
            # Log transcription quality
            logger.info(f"Transcription completed - Duration: {enhanced_result['audio_duration']:.2f}s, "
                       f"Segments: {segment_count}, Confidence: {overall_confidence:.3f}, "
                       f"Text length: {len(result['text'])}")
            
            return enhanced_result
            
        except Exception as e:
            logger.error(f"Error in transcription: {str(e)}")
            return None
    
    def _get_language_prompt(self, language):
        """Enhanced language-specific prompts for better accuracy"""
        prompts = {
            'en': "The following is a clear English speech with proper pronunciation and grammar.",
            'id': "Berikut adalah percakapan dalam bahasa Indonesia yang jelas dengan pengucapan dan tata bahasa yang benar.",
            'ar': "التالي هو خطاب واضح باللغة العربية مع النطق والقواعد الصحيحة. قرآن كريم، آيات، سورة.",
            'ms': "Berikut adalah perbualan dalam bahasa Melayu yang jelas dengan sebutan dan tatabahasa yang betul.",
            'zh': "以下是清晰的中文语音，具有正确的发音和语法。",
            'ja': "以下は明確な日本語の音声で、正しい発音と文法を持っています。",
            'ko': "다음은 올바른 발음과 문법을 가진 명확한 한국어 음성입니다."
        }
        return prompts.get(language, "The following is clear speech with proper pronunciation.")

# Global whisper instance
whisper_stt = WhisperSTT()

def safe_delete_file(file_path, max_retries=5, delay=0.1):
    """Enhanced file deletion with better error handling"""
    for attempt in range(max_retries):
        try:
            if os.path.exists(file_path):
                os.chmod(file_path, 0o777)  # Ensure file is writable
                os.unlink(file_path)
                logger.debug(f"Successfully deleted: {file_path}")
            return True
        except PermissionError as e:
            logger.warning(f"Attempt {attempt + 1}: Could not delete {file_path}: {e}")
            if attempt < max_retries - 1:
                time.sleep(delay * (2 ** attempt))  # Exponential backoff
                gc.collect()  # Force garbage collection
        except Exception as e:
            logger.error(f"Unexpected error deleting {file_path}: {e}")
            break
    
    logger.error(f"Failed to delete {file_path} after {max_retries} attempts")
    return False

@app.post("/transcribe")
async def transcribe_audio(
    audio_file: UploadFile = File(...),
    language: str = Form('auto'),
    model_size: str = Form('base'),
    high_accuracy: bool = Form(True)
):
    """Enhanced transcription endpoint with better error handling and options"""
    temp_files = []
    
    try:
        # Enhanced input validation
        available_models = list(whisper_stt.models.keys())
        if model_size not in available_models:
            logger.warning(f"Invalid model {model_size}, using base")
            model_size = 'base'
        
        if language not in whisper_stt.supported_languages:
            logger.warning(f"Invalid language {language}, using auto")
            language = 'auto'
        
        logger.info(f"Processing file: {audio_file.filename}, Language: {language}, Model: {model_size}")
        
        # Validate file size (max 25MB)
        content = await audio_file.read()
        if len(content) > 25 * 1024 * 1024:
            return JSONResponse({
                'success': False,
                'error': 'File too large',
                'message': 'Audio file must be less than 25MB'
            }, status_code=400)
        
        # Enhanced file handling
        file_extension = os.path.splitext(audio_file.filename)[1].lower()
        if not file_extension:
            file_extension = '.wav'
        
        # Create temp file with better naming
        temp_fd, temp_file_path = tempfile.mkstemp(
            suffix=file_extension, 
            prefix=f'whisper_{int(time.time())}_'
        )
        temp_files.append(temp_file_path)
        
        try:
            # Write and close file descriptor properly
            with os.fdopen(temp_fd, 'wb') as tmp_file:
                tmp_file.write(content)
            
            final_audio_path = temp_file_path
            
            # Enhanced audio conversion with better format support
            if file_extension not in ['.wav', '.flac']:
                try:
                    wav_fd, wav_path = tempfile.mkstemp(
                        suffix='.wav', 
                        prefix=f'whisper_converted_{int(time.time())}_'
                    )
                    os.close(wav_fd)
                    temp_files.append(wav_path)
                    
                    # Convert with optimized settings
                    audio_segment = AudioSegment.from_file(
                        temp_file_path,
                        format=file_extension[1:]  # Remove the dot
                    )
                    
                    # Optimize audio for Whisper
                    if audio_segment.frame_rate != 16000:
                        audio_segment = audio_segment.set_frame_rate(16000)
                    if audio_segment.channels != 1:
                        audio_segment = audio_segment.set_channels(1)
                    
                    # Export with high quality
                    audio_segment.export(
                        wav_path, 
                        format='wav',
                        parameters=["-ar", "16000", "-ac", "1"]
                    )
                    
                    del audio_segment
                    gc.collect()
                    await asyncio.sleep(0.1)
                    
                    final_audio_path = wav_path
                    
                except Exception as conv_error:
                    logger.error(f"Audio conversion error: {conv_error}")
                    return JSONResponse({
                        'success': False,
                        'error': 'Audio conversion failed',
                        'message': f'Could not convert audio format: {str(conv_error)}'
                    }, status_code=400)
            
            # Perform enhanced transcription
            start_time = time.time()
            result = whisper_stt.transcribe_audio(
                final_audio_path, 
                language, 
                model_size, 
                high_accuracy=high_accuracy
            )
            processing_time = time.time() - start_time
            
            if result:
                # Add processing time to result
                result['processing_time'] = processing_time
                result['file_info'] = {
                    'filename': audio_file.filename,
                    'size_bytes': len(content),
                    'format': file_extension
                }
                
                return JSONResponse({
                    'success': True,
                    'result': result,
                    'message': f'Transcription completed successfully in {processing_time:.2f}s'
                })
            else:
                return JSONResponse({
                    'success': False,
                    'error': 'Transcription failed',
                    'message': 'Could not process audio file'
                }, status_code=400)
                
        except Exception as process_error:
            logger.error(f"Processing error: {process_error}")
            return JSONResponse({
                'success': False,
                'error': 'Processing failed',
                'message': f'Audio processing error: {str(process_error)}'
            }, status_code=500)
            
    except Exception as e:
        logger.error(f"API Error: {str(e)}")
        return JSONResponse({
            'success': False,
            'error': str(e),
            'message': 'Internal server error'
        }, status_code=500)
        
    finally:
        # Enhanced cleanup
        for temp_file in temp_files:
            safe_delete_file(temp_file)

@app.get("/languages")
async def get_supported_languages():
    """Get enhanced supported languages"""
    return JSONResponse({
        'success': True,
        'languages': whisper_stt.supported_languages
    })

@app.get("/models")
async def get_available_models():
    """Get comprehensive model information"""
    return JSONResponse({
        'success': True,
        'models': {
            'tiny': {'size': '39 MB', 'speed': 'fastest', 'accuracy': 'lowest', 'multilingual': True},
            # 'tiny.en': {'size': '39 MB', 'speed': 'fastest', 'accuracy': 'lowest', 'multilingual': False},
            'base': {'size': '74 MB', 'speed': 'fast', 'accuracy': 'good', 'multilingual': True},
            # 'base.en': {'size': '74 MB', 'speed': 'fast', 'accuracy': 'good', 'multilingual': False},
            'small': {'size': '244 MB', 'speed': 'medium', 'accuracy': 'better', 'multilingual': True},
            # 'small.en': {'size': '244 MB', 'speed': 'medium', 'accuracy': 'better', 'multilingual': False},
            'medium': {'size': '769 MB', 'speed': 'slow', 'accuracy': 'high', 'multilingual': True},
            # 'medium.en': {'size': '769 MB', 'speed': 'slow', 'accuracy': 'high', 'multilingual': False},
            # 'large': {'size': '1550 MB', 'speed': 'slowest', 'accuracy': 'highest', 'multilingual': True},
            # 'large-v1': {'size': '1550 MB', 'speed': 'slowest', 'accuracy': 'highest', 'multilingual': True},
            # 'large-v2': {'size': '1550 MB', 'speed': 'slowest', 'accuracy': 'highest', 'multilingual': True},
            'large-v3': {'size': '1550 MB', 'speed': 'slowest', 'accuracy': 'best_available', 'multilingual': True}
        }
    })

@app.get("/health")
async def health_check():
    """Enhanced health check with system information"""
    device_info = {
        'device': 'cuda' if torch.cuda.is_available() else 'cpu',
        'cuda_available': torch.cuda.is_available()
    } 
    
    if torch.cuda.is_available():
        device_info.update({
            'cuda_device_count': torch.cuda.device_count(),
            'cuda_device_name': torch.cuda.get_device_name(0) if torch.cuda.device_count() > 0 else None,
            'cuda_memory_allocated': torch.cuda.memory_allocated(0) if torch.cuda.device_count() > 0 else None
        })
    
    return JSONResponse({
        'success': True,
        'message': 'Enhanced Whisper STT API is running',
        'current_model': whisper_stt.model_size,
        'device_info': device_info,
        'loaded_models': [k for k, v in whisper_stt.models.items() if v is not None],
        'version': '2.0.0'
    })

@app.post("/batch-transcribe")
async def batch_transcribe(
    audio_files: list[UploadFile] = File(...),
    language: str = Form('auto'),
    model_size: str = Form('base')
):
    """Batch transcription endpoint for multiple files"""
    if len(audio_files) > 10:
        return JSONResponse({
            'success': False,
            'error': 'Too many files',
            'message': 'Maximum 10 files per batch'
        }, status_code=400)
    
    results = []
    for i, audio_file in enumerate(audio_files):
        try:
            # Process each file individually
            temp_files = []
            content = await audio_file.read()
            
            file_extension = os.path.splitext(audio_file.filename)[1].lower()
            if not file_extension:
                file_extension = '.wav'
            
            temp_fd, temp_file_path = tempfile.mkstemp(
                suffix=file_extension,
                prefix=f'batch_{i}_{int(time.time())}_'
            )
            temp_files.append(temp_file_path)
            
            with os.fdopen(temp_fd, 'wb') as tmp_file:
                tmp_file.write(content)
            
            result = whisper_stt.transcribe_audio(temp_file_path, language, model_size)
            
            if result:
                result['file_index'] = i
                result['filename'] = audio_file.filename
                results.append({
                    'success': True,
                    'result': result
                })
            else:
                results.append({
                    'success': False,
                    'filename': audio_file.filename,
                    'error': 'Transcription failed'
                })
            
            # Cleanup
            for temp_file in temp_files:
                safe_delete_file(temp_file)
                
        except Exception as e:
            results.append({
                'success': False,
                'filename': audio_file.filename,
                'error': str(e)
            })
    
    successful = sum(1 for r in results if r['success'])
    
    return JSONResponse({
        'success': True,
        'message': f'Batch processing completed: {successful}/{len(audio_files)} successful',
        'results': results,
        'summary': {
            'total': len(audio_files),
            'successful': successful,
            'failed': len(audio_files) - successful
        }
    })

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000, workers=1)