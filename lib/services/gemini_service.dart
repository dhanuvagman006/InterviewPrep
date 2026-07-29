import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class GeminiService {
  static const _base = 'https://generativelanguage.googleapis.com/v1beta/models';

  static Future<String> _apiKey() async {
    final prefs = await SharedPreferences.getInstance();
    final key = prefs.getString('gemini_api_key') ?? '';
    if (key.isEmpty) {
      throw Exception('No Gemini API key set. Add one in Settings (free at aistudio.google.com).');
    }
    return key;
  }

  static Future<String> model() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('gemini_model') ?? 'gemini-2.5-flash';
  }

  /// messages: list of {'role': 'user'|'assistant', 'content': '...'}
  static Future<String> generate({
    String? system,
    required List<Map<String, String>> messages,
    int maxTokens = 1500,
    bool json = false,
  }) async {
    final key = await _apiKey();
    final m = await model();

    final contents = <Map<String, dynamic>>[];
    for (final msg in messages) {
      contents.add({
        'role': msg['role'] == 'assistant' ? 'model' : 'user',
        'parts': [
          {'text': msg['content']}
        ],
      });
    }
    // Gemini requires the conversation to start with a user turn.
    if (contents.isNotEmpty && contents.first['role'] == 'model') {
      contents.insert(0, {
        'role': 'user',
        'parts': [
          {'text': '(Earlier conversation continues below.)'}
        ],
      });
    }

    final body = <String, dynamic>{
      'contents': contents,
      'generationConfig': {
        'maxOutputTokens': maxTokens,
        'temperature': 0.9,
        if (json) 'responseMimeType': 'application/json',
      },
      if (system != null)
        'systemInstruction': {
          'parts': [
            {'text': system}
          ]
        },
    };

    final res = await http
        .post(
          Uri.parse('$_base/$m:generateContent'),
          headers: {'Content-Type': 'application/json', 'x-goog-api-key': key},
          body: jsonEncode(body),
        )
        .timeout(const Duration(seconds: 90));

    if (res.statusCode != 200) {
      final snippet = res.body.length > 300 ? res.body.substring(0, 300) : res.body;
      throw Exception('Gemini API error ${res.statusCode}: $snippet');
    }
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    final parts = (((data['candidates'] as List?)?.firstOrNull
            as Map<String, dynamic>?)?['content'] as Map<String, dynamic>?)?['parts'] as List?;
    final text = (parts ?? []).map((p) => (p as Map)['text'] ?? '').join();
    if (text.trim().isEmpty) throw Exception('Gemini returned an empty response');
    return text;
  }
}
