import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

/// The candidate's resume, stored once and reused for every interview
/// until the user replaces or removes it.
class StoredResume {
  final String fileName;
  final String text;
  final DateTime updatedAt;
  StoredResume({required this.fileName, required this.text, required this.updatedAt});
}

class ResumeService {
  static const _textKey = 'resume_text_v1';
  static const _nameKey = 'resume_filename_v1';
  static const _dateKey = 'resume_updated_v1';

  static Future<StoredResume?> load() async {
    final prefs = await SharedPreferences.getInstance();
    final text = prefs.getString(_textKey);
    if (text == null || text.trim().isEmpty) return null;
    return StoredResume(
      fileName: prefs.getString(_nameKey) ?? 'resume.pdf',
      text: text,
      updatedAt: DateTime.tryParse(prefs.getString(_dateKey) ?? '') ?? DateTime.now(),
    );
  }

  /// Opens the file picker for a PDF (or .txt), extracts its text, and stores it.
  /// Returns the stored resume, or null if the user cancelled.
  /// Throws with a readable message if the PDF has no extractable text.
  static Future<StoredResume?> pickAndStore() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'txt'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return null;

    final file = result.files.first;
    final bytes = file.bytes ?? await File(file.path!).readAsBytes();

    String text;
    if ((file.extension ?? '').toLowerCase() == 'txt') {
      text = String.fromCharCodes(bytes);
    } else {
      final doc = PdfDocument(inputBytes: bytes);
      try {
        text = PdfTextExtractor(doc).extractText();
      } finally {
        doc.dispose();
      }
    }

    text = text.trim();
    if (text.length < 40) {
      throw Exception(
          'Couldn\'t read text from that PDF — it may be a scanned image. Try an exported (text-based) PDF.');
    }
    if (text.length > 12000) text = text.substring(0, 12000);

    return _store(fileName: file.name, text: text);
  }

  static Future<StoredResume> _store({required String fileName, required String text}) async {
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now();
    await prefs.setString(_textKey, text);
    await prefs.setString(_nameKey, fileName);
    await prefs.setString(_dateKey, now.toIso8601String());
    return StoredResume(fileName: fileName, text: text, updatedAt: now);
  }

  static Future<void> remove() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_textKey);
    await prefs.remove(_nameKey);
    await prefs.remove(_dateKey);
  }
}
