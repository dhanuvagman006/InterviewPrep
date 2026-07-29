import 'dart:convert';
import 'package:uuid/uuid.dart';
import '../models/session.dart';
import 'gemini_service.dart';
import 'rounds.dart';
import 'storage_service.dart';

class TurnResult {
  final String message;
  final int roundIndex;
  final bool interviewComplete;
  final bool roundJustCompleted;
  TurnResult({
    required this.message,
    required this.roundIndex,
    required this.interviewComplete,
    required this.roundJustCompleted,
  });
}

class InterviewEngine {
  final InterviewSession session;
  InterviewEngine(this.session);

  static Future<InterviewEngine> create({
    required String difficulty,
    required String role,
    String? companyStyle,
    String? resumeText,
  }) async {
    final session = InterviewSession(
      id: const Uuid().v4(),
      createdAt: DateTime.now(),
      difficulty: difficulty,
      role: role,
      companyStyle: companyStyle,
      resumeText: resumeText,
    );
    await StorageService.saveSession(session);
    return InterviewEngine(session);
  }

  /// Send the candidate's message (or null to have the interviewer open).
  Future<TurnResult> handleTurn(String? userMessage) async {
    if (userMessage != null && userMessage.trim().isNotEmpty) {
      session.messages.add(
          ChatMessage(role: 'user', content: userMessage.trim(), roundIndex: session.roundIndex));
    }

    final profile = await StorageService.loadProfile();
    final system = baseSystemPrompt(session: session, profile: profile);

    final history = session.messages;
    final start = history.length > 30 ? history.length - 30 : 0;
    final window = history
        .sublist(start)
        .map((m) => {'role': m.role, 'content': m.content})
        .toList();
    if (window.isEmpty) {
      window.add({
        'role': 'user',
        'content': '(The candidate has joined the interview. Greet them and begin.)'
      });
    }

    final raw = await GeminiService.generate(system: system, messages: window);
    final parsed = _parseControl(raw);
    final visible = parsed.$1;
    final control = parsed.$2;

    session.messages
        .add(ChatMessage(role: 'assistant', content: visible, roundIndex: session.roundIndex));

    var interviewComplete = false;
    var roundJustCompleted = false;

    if (control != null) {
      final note = control['notes_append'];
      if (note is String && note.isNotEmpty) {
        session.interviewerNotes +=
            '${session.interviewerNotes.isEmpty ? '' : '\n'}[R${session.roundIndex + 1}] $note';
      }
      final q = control['question_asked'];
      if (q is String && q.isNotEmpty) session.askedQuestions.add(q);

      if (control['round_complete'] == true) {
        roundJustCompleted = true;
        session.roundSummaries.add(RoundSummary(
          round: rounds[session.roundIndex].title,
          score: (control['round_score'] as num?)?.toDouble(),
          summary: (control['round_summary'] as String?) ?? '',
        ));
        if (session.roundIndex < rounds.length - 1) {
          session.roundIndex += 1;
        } else {
          interviewComplete = true;
          session.status = 'completed';
          session.finishedAt = DateTime.now();
        }
      }
    }

    await StorageService.saveSession(session);
    return TurnResult(
      message: visible,
      roundIndex: session.roundIndex,
      interviewComplete: interviewComplete,
      roundJustCompleted: roundJustCompleted,
    );
  }

  (String, Map<String, dynamic>?) _parseControl(String text) {
    final match = RegExp(r'<control>([\s\S]*?)</control>').firstMatch(text);
    Map<String, dynamic>? control;
    if (match != null) {
      try {
        control = Map<String, dynamic>.from(jsonDecode(match.group(1)!.trim()));
      } catch (_) {
        control = null;
      }
    }
    final visible = text.replaceAll(RegExp(r'<control>[\s\S]*?</control>'), '').trim();
    return (visible.isEmpty ? 'Let\'s continue.' : visible, control);
  }

  Future<Map<String, dynamic>> generateReport() async {
    if (session.report != null) return session.report!;

    final digestBuffer = StringBuffer();
    for (final m in session.messages) {
      final content =
          m.content.length > 400 ? m.content.substring(0, 400) : m.content;
      digestBuffer.writeln('${m.role == 'user' ? 'CANDIDATE' : 'INTERVIEWER'}: $content');
    }
    var digest = digestBuffer.toString();
    if (digest.length > 24000) digest = digest.substring(digest.length - 24000);

    final profile = await StorageService.loadProfile();
    final prompt =
        reportPrompt(session: session, transcriptDigest: digest, profile: profile);

    final text = await GeminiService.generate(
      messages: [
        {'role': 'user', 'content': prompt}
      ],
      maxTokens: 4000,
      json: true,
    );
    final clean = text.replaceAll(RegExp(r'```json|```'), '').trim();
    final report = Map<String, dynamic>.from(jsonDecode(clean));

    session.report = report;
    session.status = 'completed';
    session.finishedAt ??= DateTime.now();
    await StorageService.saveSession(session);

    final updated = report['updated_profile'];
    if (updated is Map) {
      await StorageService.saveProfile(Map<String, dynamic>.from(updated));
    }
    return report;
  }
}
