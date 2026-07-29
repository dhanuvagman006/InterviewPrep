import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// Natural-sounding speech via Gemini's speech-generation model.
/// Uses the same API key as the interviewer. Returns WAV bytes ready to play.
class GeminiTtsService {
  static const _base = 'https://generativelanguage.googleapis.com/v1beta/models';
  static const ttsModel = 'gemini-2.5-flash-preview-tts';

  /// Prebuilt Gemini voices that suit an interviewer.
  static const voices = <String, String>{
    'Charon': 'Deep, informative (male)',
    'Kore': 'Firm, confident (female)',
    'Puck': 'Upbeat, friendly (male)',
    'Aoede': 'Breezy, natural (female)',
    'Fenrir': 'Excitable, energetic (male)',
    'Leda': 'Youthful, bright (female)',
  };

  static Future<String> selectedVoice() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('tts_voice') ?? 'Charon';
  }

  static Future<void> setVoice(String voice) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('tts_voice', voice);
  }

  /// 'device' pseudo-voice means: use the phone's built-in TTS instead.
  static Future<bool> useGemini() async => (await selectedVoice()) != 'device';

  /// Synthesize [text] and return playable WAV bytes.
  /// Throws on network/API errors — callers should fall back to device TTS.
  static Future<Uint8List> synthesize(String text) async {
    final prefs = await SharedPreferences.getInstance();
    final key = prefs.getString('gemini_api_key') ?? '';
    if (key.isEmpty) throw Exception('No API key');
    final voice = await selectedVoice();

    final body = {
      'contents': [
        {
          'parts': [
            {
              // A light style instruction makes delivery warmer and more human.
              'text':
                  'Say this in the warm, measured, professional tone of a friendly job interviewer speaking naturally: $text'
            }
          ]
        }
      ],
      'generationConfig': {
        'responseModalities': ['AUDIO'],
        'speechConfig': {
          'voiceConfig': {
            'prebuiltVoiceConfig': {'voiceName': voice}
          }
        }
      }
    };

    final res = await http
        .post(
          Uri.parse('$_base/$ttsModel:generateContent'),
          headers: {'Content-Type': 'application/json', 'x-goog-api-key': key},
          body: jsonEncode(body),
        )
        .timeout(const Duration(seconds: 45));

    if (res.statusCode != 200) {
      throw Exception('TTS error ${res.statusCode}');
    }
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    final parts = (((data['candidates'] as List?)?.firstOrNull
            as Map<String, dynamic>?)?['content'] as Map<String, dynamic>?)?['parts'] as List?;
    final inline =
        (parts ?? []).map((p) => (p as Map)['inlineData']).whereType<Map>().firstOrNull;
    if (inline == null) throw Exception('TTS returned no audio');

    final pcm = base64Decode(inline['data'] as String);
    final mime = (inline['mimeType'] as String?) ?? 'audio/L16;rate=24000';
    final rateMatch = RegExp(r'rate=(\d+)').firstMatch(mime);
    final sampleRate = rateMatch != null ? int.parse(rateMatch.group(1)!) : 24000;
    return _pcm16ToWav(pcm, sampleRate: sampleRate);
  }

  /// Wrap raw 16-bit mono PCM in a WAV container.
  static Uint8List _pcm16ToWav(Uint8List pcm, {int sampleRate = 24000}) {
    const channels = 1;
    const bitsPerSample = 16;
    final byteRate = sampleRate * channels * bitsPerSample ~/ 8;
    final blockAlign = channels * bitsPerSample ~/ 8;
    final dataSize = pcm.length;
    final fileSize = 36 + dataSize;

    final header = BytesBuilder();
    void writeString(String s) => header.add(ascii.encode(s));
    void writeU32(int v) =>
        header.add(Uint8List(4)..buffer.asByteData().setUint32(0, v, Endian.little));
    void writeU16(int v) =>
        header.add(Uint8List(2)..buffer.asByteData().setUint16(0, v, Endian.little));

    writeString('RIFF');
    writeU32(fileSize);
    writeString('WAVE');
    writeString('fmt ');
    writeU32(16);
    writeU16(1); // PCM
    writeU16(channels);
    writeU32(sampleRate);
    writeU32(byteRate);
    writeU16(blockAlign);
    writeU16(bitsPerSample);
    writeString('data');
    writeU32(dataSize);
    header.add(pcm);
    return header.toBytes();
  }
}
