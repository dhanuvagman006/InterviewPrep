import 'dart:convert';

class ChatMessage {
  final String role; // 'user' | 'assistant'
  final String content;
  final int roundIndex;
  ChatMessage({required this.role, required this.content, required this.roundIndex});

  Map<String, dynamic> toJson() => {'role': role, 'content': content, 'roundIndex': roundIndex};
  factory ChatMessage.fromJson(Map<String, dynamic> j) =>
      ChatMessage(role: j['role'], content: j['content'], roundIndex: j['roundIndex'] ?? 0);
}

class RoundSummary {
  final String round;
  final double? score;
  final String summary;
  RoundSummary({required this.round, this.score, required this.summary});

  Map<String, dynamic> toJson() => {'round': round, 'score': score, 'summary': summary};
  factory RoundSummary.fromJson(Map<String, dynamic> j) => RoundSummary(
      round: j['round'] ?? '', score: (j['score'] as num?)?.toDouble(), summary: j['summary'] ?? '');
}

class InterviewSession {
  final String id;
  final DateTime createdAt;
  DateTime? finishedAt;
  String status; // active | completed
  final String difficulty;
  final String role;
  final String? companyStyle;
  final String? resumeText;
  int roundIndex;
  String interviewerNotes;
  List<String> askedQuestions;
  List<RoundSummary> roundSummaries;
  List<ChatMessage> messages;
  Map<String, dynamic>? report;

  InterviewSession({
    required this.id,
    required this.createdAt,
    this.finishedAt,
    this.status = 'active',
    required this.difficulty,
    required this.role,
    this.companyStyle,
    this.resumeText,
    this.roundIndex = 0,
    this.interviewerNotes = '',
    List<String>? askedQuestions,
    List<RoundSummary>? roundSummaries,
    List<ChatMessage>? messages,
    this.report,
  })  : askedQuestions = askedQuestions ?? [],
        roundSummaries = roundSummaries ?? [],
        messages = messages ?? [];

  int? get durationMinutes =>
      finishedAt == null ? null : finishedAt!.difference(createdAt).inMinutes;

  Map<String, dynamic> toJson() => {
        'id': id,
        'createdAt': createdAt.toIso8601String(),
        'finishedAt': finishedAt?.toIso8601String(),
        'status': status,
        'difficulty': difficulty,
        'role': role,
        'companyStyle': companyStyle,
        'resumeText': resumeText,
        'roundIndex': roundIndex,
        'interviewerNotes': interviewerNotes,
        'askedQuestions': askedQuestions,
        'roundSummaries': roundSummaries.map((r) => r.toJson()).toList(),
        'messages': messages.map((m) => m.toJson()).toList(),
        'report': report,
      };

  factory InterviewSession.fromJson(Map<String, dynamic> j) => InterviewSession(
        id: j['id'],
        createdAt: DateTime.parse(j['createdAt']),
        finishedAt: j['finishedAt'] == null ? null : DateTime.parse(j['finishedAt']),
        status: j['status'] ?? 'active',
        difficulty: j['difficulty'] ?? 'intermediate',
        role: j['role'] ?? 'Software Engineer',
        companyStyle: j['companyStyle'],
        resumeText: j['resumeText'],
        roundIndex: j['roundIndex'] ?? 0,
        interviewerNotes: j['interviewerNotes'] ?? '',
        askedQuestions: (j['askedQuestions'] as List? ?? []).cast<String>(),
        roundSummaries: (j['roundSummaries'] as List? ?? [])
            .map((r) => RoundSummary.fromJson(Map<String, dynamic>.from(r)))
            .toList(),
        messages: (j['messages'] as List? ?? [])
            .map((m) => ChatMessage.fromJson(Map<String, dynamic>.from(m)))
            .toList(),
        report: j['report'] == null ? null : Map<String, dynamic>.from(j['report']),
      );

  String encode() => jsonEncode(toJson());
  static InterviewSession decode(String s) =>
      InterviewSession.fromJson(jsonDecode(s) as Map<String, dynamic>);
}
