import 'package:flutter/material.dart';

import '../../models/meeting.dart';
import '../../utils/timestamps.dart';
import '../core/app_theme.dart';
import 'speakers_panel.dart';

class TranscriptPane extends StatefulWidget {
  const TranscriptPane({
    super.key,
    required this.meeting,
    required this.onSeek,
    required this.onEditSpeaker,
    required this.onEditText,
    this.busy = false,
    this.onDetectSpeakers,
    this.onRenameSpeaker,
  });
  final Meeting meeting;
  final ValueChanged<int> onSeek;
  final ValueChanged<Segment> onEditSpeaker;
  final ValueChanged<Segment> onEditText;
  final bool busy;
  final ValueChanged<int>? onDetectSpeakers;
  final ValueChanged<String>? onRenameSpeaker;
  @override
  State<TranscriptPane> createState() => _TranscriptPaneState();
}

class _TranscriptPaneState extends State<TranscriptPane> {
  Meeting get meeting => widget.meeting;
  String transcriptSearch = '';
  bool uncertainOnly = false;
  @override
  Widget build(BuildContext context) {
    final visible = meeting.segments
        .where(
          (s) =>
              (!uncertainOnly || s.speakerUncertain) &&
              '${meeting.speakerLabel(s)} ${s.text}'.toLowerCase().contains(
                transcriptSearch.toLowerCase(),
              ),
        )
        .toList();
    return Column(
      children: [
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: TextField(
                key: const ValueKey('transcript-search'),
                onChanged: (s) => setState(() => transcriptSearch = s),
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.search, size: 18),
                  hintText: 'Rechercher dans la conversation',
                  isDense: true,
                ),
              ),
            ),
            if (meeting.speakersDetected)
              IconButton(
                key: const ValueKey('uncertain-speakers'),
                tooltip:
                    '${meeting.segments.where((s) => s.speakerUncertain).length} passages : voix à vérifier',
                isSelected: uncertainOnly,
                onPressed: () => setState(() => uncertainOnly = !uncertainOnly),
                icon: const Icon(Icons.filter_alt_outlined, size: 20),
                selectedIcon: const Icon(Icons.filter_alt, size: 20),
              ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: SpeakersPanel(
            meeting: meeting,
            busy: widget.busy,
            onDetect: widget.onDetectSpeakers,
            onRename: widget.onRenameSpeaker,
            onSeek: widget.onSeek,
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
                              Flexible(
                                child: TextButton.icon(
                                  onPressed: widget.busy
                                      ? null
                                      : () => widget.onEditSpeaker(s),
                                  icon: const Icon(
                                    Icons.person_outline,
                                    size: 15,
                                  ),
                                  label: Text(
                                    meeting.speakerLabel(s).isEmpty
                                        ? (s.speakerUncertain
                                              ? 'Voix à vérifier'
                                              : 'Attribuer un nom')
                                        : meeting.speakerLabel(s),
                                    maxLines: 1,
                                    overflow: .ellipsis,
                                    style: const TextStyle(
                                      color: muted,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ),
                              const Spacer(),
                              IconButton(
                                tooltip: 'Corriger ce passage',
                                onPressed: widget.busy
                                    ? null
                                    : () => widget.onEditText(s),
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
