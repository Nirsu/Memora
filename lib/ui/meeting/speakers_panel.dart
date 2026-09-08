import 'package:flutter/material.dart';

import '../../models/meeting.dart';
import '../core/app_theme.dart';

class SpeakersPanel extends StatefulWidget {
  const SpeakersPanel({
    super.key,
    required this.meeting,
    required this.busy,
    required this.onDetect,
    required this.onRename,
    required this.onSeek,
  });
  final Meeting meeting;
  final bool busy;
  final ValueChanged<int>? onDetect;
  final ValueChanged<String>? onRename;
  final ValueChanged<int> onSeek;
  @override
  State<SpeakersPanel> createState() => _SpeakersPanelState();
}

class _SpeakersPanelState extends State<SpeakersPanel> {
  late int count = widget.meeting.expectedSpeakers.clamp(0, 20);
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: .start,
    children: [
      Wrap(
        spacing: 12,
        runSpacing: 8,
        crossAxisAlignment: .center,
        children: [
          OutlinedButton.icon(
            key: const ValueKey('detect-speakers'),
            onPressed:
                widget.busy ||
                    widget.meeting.segments.isEmpty ||
                    widget.onDetect == null
                ? null
                : () => widget.onDetect!(count),
            icon: const Icon(Icons.groups_outlined, size: 18),
            label: Text(
              widget.meeting.speakersDetected
                  ? 'Relancer la détection'
                  : 'Détecter les intervenants',
            ),
          ),
          DropdownButton<int>(
            key: const ValueKey('speaker-count'),
            value: count,
            items: [
              const DropdownMenuItem(
                value: 0,
                child: Text('Nombre de voix : auto'),
              ),
              for (var i = 1; i <= 20; i++)
                DropdownMenuItem(
                  value: i,
                  child: Text('$i intervenant${i == 1 ? '' : 's'}'),
                ),
            ],
            onChanged: widget.busy
                ? null
                : (value) => setState(() => count = value ?? 0),
            style: const TextStyle(color: muted, fontSize: 12),
          ),
        ],
      ),
      const SizedBox(height: 8),
      Text(
        widget.meeting.speakersDetected
            ? 'Écoutez chaque voix, puis nommez-la une fois pour tous ses passages. Détection expérimentale : certaines voix peuvent être fusionnées ou dédoublées.'
            : 'Les voix seront regroupées automatiquement. Si vous connaissez leur nombre, indiquez-le pour aider la détection.',
        style: const TextStyle(color: muted, fontSize: 11, height: 1.5),
      ),
      if (widget.meeting.speakerError.isNotEmpty)
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text(
            widget.meeting.speakerError,
            style: const TextStyle(color: Color(0xffffb4ab), fontSize: 12),
          ),
        ),
      const SizedBox(height: 8),
      // Keep the transcript usable even when an automatic run finds too many voices.
      ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 150),
        child: SingleChildScrollView(
          child: Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              for (final voice in widget.meeting.speakerNames.entries)
                Builder(
                  builder: (_) {
                    final passages =
                        widget.meeting.segments
                            .where(
                              (s) =>
                                  s.speakerId == voice.key && s.speaker.isEmpty,
                            )
                            .toList()
                          ..sort(
                            (a, b) =>
                                (b.end - b.start).compareTo(a.end - a.start),
                          );
                    return DecoratedBox(
                      decoration: BoxDecoration(
                        color: selectedSurface,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: .min,
                        children: [
                          IconButton(
                            tooltip: 'Écouter ${voice.value}',
                            onPressed: passages.isEmpty
                                ? null
                                : () => widget.onSeek(passages.first.start),
                            icon: const Icon(Icons.play_arrow, size: 18),
                          ),
                          TextButton(
                            onPressed: widget.busy || widget.onRename == null
                                ? null
                                : () => widget.onRename!(voice.key),
                            child: Text(
                              '${voice.value} · ${passages.length}',
                              style: const TextStyle(fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
            ],
          ),
        ),
      ),
    ],
  );
}
