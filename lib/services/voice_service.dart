import 'dart:async';
import 'dart:typed_data';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'gemini_tts_service.dart';

/// Voice layer for the interview call:
/// - speak(): reads the interviewer's question aloud (code blocks announced, not read).
/// - listen(): native speech-to-text with a live transcript; ~2.2s of silence after
///   real words finalizes the answer, giving a hands-free conversation loop.
class VoiceService {
  final FlutterTts _tts = FlutterTts();
  final stt.SpeechToText _stt = stt.SpeechToText();
  final AudioPlayer _player = AudioPlayer();

  bool _sttReady = false;
  bool speaking = false;
  bool listening = false;

  String _finalText = '';
  String liveTranscript = '';
  Timer? _silenceTimer;
  void Function(String text)? _onFinal;
  void Function()? onStateChanged;

  /// Fired the moment audio actually starts playing (used to sync captions).
  void Function()? onSpeechStart;

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

  /// Speak [text] aloud. Prefers Gemini's natural voice; falls back to the
  /// device's built-in TTS if that fails (offline, quota, etc.).
  ///
  /// Latency: the text is split into sentence chunks and synthesis is
  /// PIPELINED — the first (short) chunk is synthesized and played right away
  /// while the following chunks are generated in the background. This cuts
  /// time-to-first-word to roughly the synthesis time of one sentence.
  Future<void> speak(String text) async {
    final spoken = text
        .replaceAll(RegExp(r'```[\s\S]*?```'), " I've put the details on your screen. ")
        .replaceAll(RegExp(r'[*_#`>|]'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    if (spoken.isEmpty) return;

    speaking = true;
    onStateChanged?.call();
    var announcedStart = false;
    void announce() {
      if (!announcedStart) {
        announcedStart = true;
        onSpeechStart?.call();
      }
    }

    try {
      var playedNatural = false;
      if (await GeminiTtsService.useGemini()) {
        try {
          final chunks = _chunkSentences(spoken);
          // Kick off synthesis of chunk 0; then, while each chunk plays,
          // synthesize the next one in parallel.
          Future<Uint8List>? nextSynth = GeminiTtsService.synthesize(chunks[0]);
          for (var i = 0; i < chunks.length; i++) {
            final wav = await nextSynth!;
            if (!speaking) return; // stopSpeaking() while synthesizing
            nextSynth = i + 1 < chunks.length
                ? GeminiTtsService.synthesize(chunks[i + 1])
                : null;
            announce();
            await _playWav(wav);
            if (!speaking) return;
          }
          playedNatural = true;
        } catch (_) {
          playedNatural = false; // fall through to device TTS
        }
      }
      if (!playedNatural && speaking) {
        announce();
        await _tts.speak(spoken); // awaits completion (awaitSpeakCompletion)
      }
    } finally {
      speaking = false;
      onStateChanged?.call();
    }
  }

  Future<void> _playWav(Uint8List wav) async {
    final done = Completer<void>();
    late final StreamSubscription sub;
    sub = _player.onPlayerComplete.listen((_) {
      if (!done.isCompleted) done.complete();
      sub.cancel();
    });
    await _player.play(BytesSource(wav));
    await done.future;
  }

  /// Split into speakable chunks: the first is a single sentence (fast to
  /// synthesize), later ones merge sentences up to ~220 chars.
  List<String> _chunkSentences(String text) {
    final sentences = RegExp(r'[^.!?]+[.!?]+|\S[^.!?]*$')
        .allMatches(text)
        .map((m) => m.group(0)!.trim())
        .where((s) => s.isNotEmpty)
        .toList();
    if (sentences.isEmpty) return [text];

    final chunks = <String>[sentences.first];
    var buf = '';
    for (final s in sentences.skip(1)) {
      if (buf.isNotEmpty && (buf.length + s.length) > 220) {
        chunks.add(buf.trim());
        buf = s;
      } else {
        buf = buf.isEmpty ? s : '$buf $s';
      }
    }
    if (buf.trim().isNotEmpty) chunks.add(buf.trim());
    return chunks;
  }

  Future<void> stopSpeaking() async {
    speaking = false;
    await _player.stop();
    await _tts.stop();
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
    _player.dispose();
    _tts.stop();
    _stt.stop();
  }
}
