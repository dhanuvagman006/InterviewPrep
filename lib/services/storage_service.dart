import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/session.dart';

class StorageService {
  static const _sessionsKey = 'sessions_v1';
  static const _profileKey = 'candidate_profile_v1';

  static Future<List<InterviewSession>> loadSessions() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_sessionsKey) ?? [];
    final sessions = <InterviewSession>[];
    for (final s in raw) {
      try {
        sessions.add(InterviewSession.decode(s));
      } catch (_) {/* skip corrupt entry */}
    }
    sessions.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return sessions;
  }

  static Future<void> saveSession(InterviewSession session) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_sessionsKey) ?? [];
    final list = raw.where((s) {
      try {
        return InterviewSession.decode(s).id != session.id;
      } catch (_) {
        return false;
      }
    }).toList();
    list.add(session.encode());
    await prefs.setStringList(_sessionsKey, list);
  }

  static Future<void> deleteSession(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_sessionsKey) ?? [];
    final list = raw.where((s) {
      try {
        return InterviewSession.decode(s).id != id;
      } catch (_) {
        return false;
      }
    }).toList();
    await prefs.setStringList(_sessionsKey, list);
  }

  static Future<Map<String, dynamic>> loadProfile() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_profileKey);
    if (raw == null) return {};
    try {
      return Map<String, dynamic>.from(jsonDecode(raw));
    } catch (_) {
      return {};
    }
  }

  static Future<void> saveProfile(Map<String, dynamic> profile) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_profileKey, jsonEncode(profile));
  }
}
