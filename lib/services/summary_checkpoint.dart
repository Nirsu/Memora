import 'dart:convert';
import 'dart:io';

import '../models/summary.dart';

/// Completed source chunks survive cancellation and application restarts.
class SummaryCheckpoint {
  SummaryCheckpoint(this.file, this.source);
  final File file;
  final String source;
  final List<List<SummaryItem>> parts = [];
  int nextCapture = 0;

  Future<void> load(Set<int> allowed) async {
    if (!await file.exists()) return;
    try {
      final data = jsonDecode(await file.readAsString()) as Map;
      if (data['source'] != source) return;
      final loaded = (data['parts'] as List)
          .map((part) => validatedItems({'items': part}, allowed))
          .toList();
      final cursor = data['nextCapture'] as int;
      if (cursor < 0) return;
      parts.addAll(loaded);
      nextCapture = cursor;
    } on FormatException {
      // A damaged cache must never prevent a fresh run from the transcript.
    } on TypeError {
      // Older checkpoint formats are disposable; source files are preserved.
    }
  }

  Future<void> save() async {
    final temporary = File('${file.path}.tmp');
    await temporary.writeAsString(
      jsonEncode({
        'source': source,
        'parts': parts,
        'nextCapture': nextCapture,
      }),
      flush: true,
    );
    await temporary.rename(file.path);
  }
}
