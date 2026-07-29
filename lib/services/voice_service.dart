import 'dart:async';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

/// Voice layer for the interview call:
/// - speak(): reads the interviewer's question aloud (code blocks announced, not read).
/// - listen(): native speech-to-text with a live transcript; ~2.2s of silence after
///   real words finalizes the answer, giving a hands-free conversation loop.
class VoiceService {
  final FlutterTts _tts = FlutterTts();
  final stt.SpeechToText _stt = stt.SpeechToText();

  bool _sttReady = false;
  bool speaking = false;
  bool listening = false;

  String _finalText = '';
  String liveTranscript = '';
  Timer? _silenceTimer;
  void Function(String text)? _onFinal;
  void Function()? onStateChanged;

  Future<bool> init() async {
    final mic = await Permission.microphone.request();
    if (!mic.isGranted) return false;

    _sttReady = await _stt.initialize(
      onStatus: (status) {
        // The engine stops itself after pauses on some devices; restart while active.
        if (status == 'done' && listening) {
          _startRecognizer();
        }
      },
      onError: (_) {
        if (listening) _startRecognizer();
      },
    );

    await _tts.setLanguage('en-US');
    await _tts.setSpeechRate(0.5); // flutter_tts 0.5 ≈ normal speed on most devices
    await _tts.setPitch(1.0);
    await _tts.awaitSpeakCompletion(true);
    return _sttReady;
  }

  /// Speak [text] aloud. Code blocks are replaced with a spoken pointer.
  Future<void> speak(String text) async {
    final spoken = text
        .replaceAll(RegExp(r'```[\s\S]*?```'), " I've put the details on your screen. ")
        .replaceAll(RegExp(r'[*_#`>|]'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    if (spoken.isEmpty) return;

    speaking = true;
    onStateChanged?.call();
    try {
      await _tts.speak(spoken); // awaits completion (awaitSpeakCompletion)
    } finally {
      speaking = false;
      onStateChanged?.call();
    }
  }

  Future<void> stopSpeaking() async {
    await _tts.stop();
    speaking = false;
    onStateChanged?.call();
  }

  /// Open the microphone. Calls [onFinal] with the transcript after the
  /// candidate stops talking for ~2.2 seconds (or when finishNow() is called).
  Future<void> listen({required void Function(String text) onFinal}) async {
    if (!_sttReady || listening) return;
    await stopSpeaking();
    _onFinal = onFinal;
    _finalText = '';
    liveTranscript = '';
    listening = true;
    onStateChanged?.call();
    await _startRecognizer();
  }

  Future<void> _startRecognizer() async {
    if (!listening) return;
    try {
      await _stt.listen(
        onResult: (result) {
          if (result.finalResult) {
            _finalText = '${_finalText.isEmpty ? '' : '$_finalText '}${result.recognizedWords}';
            liveTranscript = _finalText;
          } else {
            liveTranscript =
                '${_finalText.isEmpty ? '' : '$_finalText '}${result.recognizedWords}';
          }
          onStateChanged?.call();

          _silenceTimer?.cancel();
          if (liveTranscript.trim().isNotEmpty) {
            _silenceTimer = Timer(const Duration(milliseconds: 2200), finishNow);
          }
        },
        listenOptions: stt.SpeechListenOptions(
          listenMode: stt.ListenMode.dictation,
          partialResults: true,
          cancelOnError: false,
        ),
        pauseFor: const Duration(seconds: 8),
        listenFor: const Duration(minutes: 3),
      );
    } catch (_) {
      // Recognizer occasionally throws if restarted too quickly; retry shortly.
      if (listening) {
        Future.delayed(const Duration(milliseconds: 400), _startRecognizer);
      }
    }
  }

  /// Finish the current answer immediately and deliver the transcript.
  void finishNow() {
    if (!listening) return;
    final text = liveTranscript.trim().isNotEmpty ? liveTranscript.trim() : _finalText.trim();
    _teardownListening();
    if (text.isNotEmpty) _onFinal?.call(text);
  }

  /// Cancel listening without sending anything.
  Future<void> cancelListening() async {
    _teardownListening();
  }

  void _teardownListening() {
    _silenceTimer?.cancel();
    listening = false;
    liveTranscript = '';
    _finalText = '';
    _stt.stop();
    onStateChanged?.call();
  }

  void dispose() {
    _silenceTimer?.cancel();
    _tts.stop();
    _stt.stop();
  }
}
