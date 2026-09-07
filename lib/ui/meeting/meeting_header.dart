import 'package:flutter/material.dart';

import '../../models/meeting.dart';
import '../../utils/timestamps.dart';
import '../core/app_theme.dart';
import '../core/surfaces.dart';
import '../core/delete_meeting_button.dart';

class MeetingHeader extends StatelessWidget {
  const MeetingHeader({
    super.key,
    required this.meeting,
    required this.busy,
    required this.processing,
    required this.detail,
    required this.saveState,
    required this.onBack,
    required this.onRename,
    required this.onDelete,
    required this.onImport,
    required this.onAnalyze,
    required this.onExport,
    required this.onCancel,
  });
  final Meeting meeting;
  final bool busy;
  final bool processing;
  final String detail;
  final String saveState;
  final VoidCallback onBack;
  final VoidCallback onRename;
  final VoidCallback onDelete;
  final VoidCallback onImport;
  final VoidCallback onAnalyze;
  final VoidCallback onExport;
  final VoidCallback onCancel;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: .start,
    children: [
      Row(
        children: [
          TextButton.icon(
            onPressed: onBack,
            icon: const Icon(Icons.arrow_back, size: 16),
            label: const Text('Bibliothèque'),
          ),
          const Spacer(),
          BadgeLabel(meeting.status.label),
          const SizedBox(width: 10),
          const Icon(Icons.lock_outline, color: muted, size: 14),
        ],
      ),
      const SizedBox(height: 8),
      Row(
        children: [
          Expanded(
            child: Text(
              meeting.title,
              maxLines: 2,
              overflow: .ellipsis,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: .w600,
                letterSpacing: -.7,
              ),
            ),
          ),
          IconButton(
            tooltip: 'Renommer le meeting',
            onPressed: onRename,
            icon: const Icon(Icons.edit_outlined, size: 18),
          ),
          DeleteMeetingButton(
            meeting: meeting,
            onDelete: busy ? null : onDelete,
          ),
        ],
      ),
      const SizedBox(height: 8),
      Text(
        "${meeting.created.day}/${meeting.created.month}/${meeting.created.year}  ·  ${meeting.duration == 0 ? 'Prêt à prendre des notes' : timeLabel(meeting.duration)}  ·  $saveState",
        style: const TextStyle(color: muted, fontSize: 12),
      ),
      const SizedBox(height: 14),
      Wrap(
        spacing: 10,
        runSpacing: 8,
        children: [
          if (meeting.media.isEmpty)
            FilledButton.icon(
              onPressed: !busy ? onImport : null,
              icon: const Icon(Icons.attach_file, size: 18),
              label: const Text("Rattacher l'enregistrement OBS"),
            ),
          if (meeting.media.isNotEmpty && meeting.summary.isEmpty)
            FilledButton.icon(
              key: const ValueKey('analyze'),
              onPressed: !busy ? onAnalyze : null,
              icon: const Icon(Icons.auto_awesome, size: 18),
              label: Text(
                meeting.segments.isEmpty
                    ? 'Transcrire et résumer'
                    : 'Générer un nouveau résumé',
              ),
            ),
          if (meeting.summary.isNotEmpty)
            FilledButton.icon(
              onPressed: !busy ? onExport : null,
              icon: const Icon(Icons.ios_share, size: 17),
              label: const Text('Exporter le compte rendu'),
            )
          else
            OutlinedButton.icon(
              onPressed: !busy ? onExport : null,
              icon: const Icon(Icons.ios_share, size: 17),
              label: const Text('Exporter'),
            ),
          if (meeting.media.isNotEmpty && meeting.summary.isNotEmpty)
            TextButton.icon(
              key: const ValueKey('analyze'),
              onPressed: !busy ? onAnalyze : null,
              icon: const Icon(Icons.refresh, size: 16),
              label: const Text('Régénérer le résumé'),
            ),
          if (processing)
            TextButton.icon(
              onPressed: onCancel,
              icon: const Icon(Icons.stop_circle_outlined, size: 18),
              label: const Text('Arrêter le traitement'),
            ),
        ],
      ),
      if (processing)
        Padding(
          padding: const EdgeInsets.only(top: 18),
          child: Column(
            crossAxisAlignment: .start,
            children: [
              const LinearProgressIndicator(minHeight: 3),
              const SizedBox(height: 10),
              Text(
                '${meeting.status.label} · $detail',
                style: const TextStyle(color: accent, fontSize: 12),
              ),
            ],
          ),
        ),
      if (meeting.error.isNotEmpty)
        Padding(
          padding: const EdgeInsets.only(top: 12),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xff38282b),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.info_outline,
                  color: Color(0xffffb4ab),
                  size: 18,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: SelectableText(
                    meeting.error,
                    maxLines: 3,
                    style: const TextStyle(
                      color: Color(0xffffb4ab),
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
    ],
  );
}
