import 'package:flutter/material.dart';

import '../../models/meeting.dart';
import '../../utils/timestamps.dart';
import '../core/app_theme.dart';

class TranscriptPane extends StatefulWidget {
  const TranscriptPane({
    super.key,
    required this.meeting,
    required this.onSeek,
    required this.onEditSpeaker,
    required this.onEditText,
  });
  final Meeting meeting;
  final ValueChanged<int> onSeek;
  final ValueChanged<Segment> onEditSpeaker;
  final ValueChanged<Segment> onEditText;
  @override
  State<TranscriptPane> createState() => _TranscriptPaneState();
}

class _TranscriptPaneState extends State<TranscriptPane> {
  Meeting get meeting => widget.meeting;
  String transcriptSearch = '';
  @override
  Widget build(BuildContext context) {
    final visible = meeting.segments
        .where(
          (s) => '${s.speaker} ${s.text}'.toLowerCase().contains(
            transcriptSearch.toLowerCase(),
          ),
        )
        .toList();
    return Column(
      children: [
        const SizedBox(height: 14),
        TextField(
          key: const ValueKey('transcript-search'),
          onChanged: (s) => setState(() => transcriptSearch = s),
          decoration: const InputDecoration(
            prefixIcon: Icon(Icons.search, size: 18),
            hintText: 'Rechercher dans la conversation',
            isDense: true,
          ),
        ),
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 12),
          child: Text(
            'Les noms sont attribués manuellement dans cette version. Cliquez sur une étiquette pour identifier la voix.',
            style: TextStyle(color: muted, fontSize: 11, height: 1.5),
          ),
        ),
        Expanded(
          child: meeting.segments.isEmpty
              ? const Center(
                  child: Text(
                    "La transcription apparaîtra après l'analyse.",
                    style: TextStyle(color: muted),
                  ),
                )
              : ListView.builder(
                  itemCount: visible.length,
                  itemBuilder: (_, i) {
                    final s = visible[i];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 18),
                      child: Column(
                        crossAxisAlignment: .start,
                        children: [
                          Row(
                            children: [
                              TextButton(
                                onPressed: () => widget.onSeek(s.start),
                                child: Text(
                                  timeLabel(s.start),
                                  style: const TextStyle(fontSize: 12),
                                ),
                              ),
                              TextButton.icon(
                                onPressed: () => widget.onEditSpeaker(s),
                                icon: const Icon(
                                  Icons.person_outline,
                                  size: 15,
                                ),
                                label: Text(
                                  s.speaker.isEmpty
                                      ? 'Attribuer un nom'
                                      : s.speaker,
                                  style: const TextStyle(
                                    color: muted,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                              const Spacer(),
                              IconButton(
                                tooltip: 'Corriger ce passage',
                                onPressed: () => widget.onEditText(s),
                                icon: const Icon(Icons.edit_outlined, size: 15),
                              ),
                            ],
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            child: SelectableText(
                              s.text,
                              style: const TextStyle(height: 1.8, fontSize: 14),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}
