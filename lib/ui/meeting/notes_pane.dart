import 'dart:async';

import 'package:flutter/material.dart';

import '../../models/meeting.dart';
import '../../utils/timestamps.dart';
import '../core/app_theme.dart';

class NotesPane extends StatefulWidget {
  const NotesPane({
    super.key,
    required this.meeting,
    required this.markerStart,
    required this.onToggleMarker,
    required this.onChanged,
    required this.position,
  });
  final Meeting meeting;
  final DateTime? markerStart;
  final VoidCallback onToggleMarker;
  final ValueChanged<String> onChanged;
  final int Function() position;
  @override
  State<NotesPane> createState() => _NotesPaneState();
}

class _NotesPaneState extends State<NotesPane> {
  Meeting get meeting => widget.meeting;

  late final notes = TextEditingController(text: meeting.notes);
  Timer? clock;
  @override
  void initState() {
    super.initState();
    clock = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && widget.markerStart != null) setState(() {});
    });
  }

  void mark() {
    final ms = meeting.media.isNotEmpty
        ? widget.position()
        : widget.markerStart == null
        ? 0
        : DateTime.now().difference(widget.markerStart!).inMilliseconds;
    final text =
        '${notes.text}${notes.text.endsWith('\n') || notes.text.isEmpty ? '' : '\n'}[${timeLabel(ms)}] Moment important : ';
    notes.text = text;
    notes.selection = TextSelection.collapsed(offset: text.length);
    widget.onChanged(text);
  }

  @override
  void dispose() {
    clock?.cancel();
    notes.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 14),
    child: Column(
      crossAxisAlignment: .start,
      children: [
        Wrap(
          spacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            if (meeting.media.isEmpty)
              TextButton.icon(
                onPressed: widget.onToggleMarker,
                icon: Icon(
                  widget.markerStart == null
                      ? Icons.timer_outlined
                      : Icons.stop_circle_outlined,
                  size: 18,
                ),
                label: Text(
                  widget.markerStart == null
                      ? 'Démarrer le repère temps'
                      : timeLabel(
                          DateTime.now()
                              .difference(widget.markerStart!)
                              .inMilliseconds,
                        ),
                ),
              ),
            TextButton.icon(
              key: const ValueKey('mark-moment'),
              onPressed: mark,
              icon: const Icon(Icons.bookmark_add_outlined, size: 18),
              label: const Text('Moment important'),
            ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Text(
            meeting.media.isEmpty
                ? "OBS enregistre séparément. Démarrez le repère temps au même instant qu'OBS pour annoter vos notes."
                : "Vos notes personnelles restent intactes quand vous régénérez un résumé.",
            style: const TextStyle(color: muted, fontSize: 11, height: 1.5),
          ),
        ),
        Expanded(
          child: TextField(
            key: const ValueKey('notes-editor'),
            controller: notes,
            expands: true,
            maxLines: null,
            minLines: null,
            textAlignVertical: .top,
            style: const TextStyle(height: 1.9, fontSize: 15),
            decoration: const InputDecoration(
              hintText: 'Un ordre du jour, une idée, une question…\n\nCet espace est à vous.',
            ),
            onChanged: widget.onChanged,
          ),
        ),
      ],
    ),
  );
}
