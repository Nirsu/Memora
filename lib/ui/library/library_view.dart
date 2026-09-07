import 'package:flutter/material.dart';

import '../../models/meeting.dart';
import '../../utils/timestamps.dart';
import '../core/app_theme.dart';
import '../core/surfaces.dart';
import '../core/delete_meeting_button.dart';

class LibraryView extends StatelessWidget {
  const LibraryView({
    super.key,
    required this.meetings,
    required this.search,
    required this.busy,
    required this.onCreate,
    required this.onImport,
    required this.onGuide,
    required this.onSelect,
    required this.onDelete,
  });
  final List<Meeting> meetings;
  final String search;
  final bool busy;
  final VoidCallback onCreate;
  final VoidCallback onImport;
  final VoidCallback onGuide;
  final ValueChanged<Meeting> onSelect;
  final ValueChanged<Meeting> onDelete;
  @override
  Widget build(BuildContext context) {
    final visible = meetings
        .where((m) => m.title.toLowerCase().contains(search.toLowerCase()))
        .toList();
    return ListView(
      children: [
        Row(
          children: [
            const Icon(Icons.folder_open_outlined, size: 17, color: muted),
            const SizedBox(width: 10),
            const Text(
              'Espace personnel',
              style: TextStyle(color: muted, fontSize: 12),
            ),
            const Spacer(),
            Container(
              width: 6,
              height: 6,
              decoration: const BoxDecoration(
                color: Color(0xff86b99a),
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 7),
            const Text(
              'Sur cet ordinateur',
              style: TextStyle(color: muted, fontSize: 11),
            ),
          ],
        ),
        const SizedBox(height: 44),
        const Text(
          "Vos conversations,\nl'esprit libre.",
          style: TextStyle(
            fontSize: 38,
            height: 1.15,
            fontWeight: .w600,
            letterSpacing: -1.4,
          ),
        ),
        const SizedBox(height: 14),
        const Text(
          "Un endroit pour vos notes, vos enregistrements et ce qu'il faut retenir.",
          style: TextStyle(color: muted, fontSize: 14, height: 1.6),
        ),
        const SizedBox(height: 26),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            FilledButton.icon(
              key: const ValueKey('prepare-home'),
              onPressed: onCreate,
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text('Préparer mon meeting'),
            ),
            OutlinedButton.icon(
              key: const ValueKey('import-home'),
              onPressed: !busy ? onImport : null,
              icon: const Icon(Icons.file_upload_outlined, size: 18),
              label: const Text('Importer un enregistrement'),
            ),
          ],
        ),
        const SizedBox(height: 38),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          decoration: BoxDecoration(
            color: panel,
            border: Border.all(color: line),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              const Icon(Icons.videocam_outlined, size: 19, color: muted),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Enregistrez avec OBS, puis retrouvez le résumé et les moments clés ici.',
                  style: TextStyle(color: muted, fontSize: 12, height: 1.5),
                ),
              ),
              TextButton(
                onPressed: onGuide,
                child: const Text('Guide OBS', style: TextStyle(fontSize: 12)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 36),
        Row(
          children: [
            const Text(
              'Meetings',
              style: TextStyle(fontSize: 16, fontWeight: .w600),
            ),
            const SizedBox(width: 10),
            BadgeLabel('${visible.length}', color: muted),
            const Spacer(),
            const Text(
              "Les plus récents d'abord",
              style: TextStyle(color: muted, fontSize: 11),
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (visible.isEmpty)
          Panel(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 28),
              child: Column(
                children: [
                  const Icon(Icons.article_outlined, color: muted, size: 30),
                  const SizedBox(height: 14),
                  Text(
                    search.isEmpty
                        ? 'Votre prochain meeting commence ici.'
                        : 'Aucun résultat pour cette recherche.',
                    style: const TextStyle(fontWeight: .w500),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Préparez vos notes ou importez un enregistrement.',
                    style: TextStyle(color: muted, fontSize: 12),
                  ),
                ],
              ),
            ),
          ),
        for (final m in visible)
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => onSelect(m),
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 15,
                ),
                decoration: const BoxDecoration(
                  border: Border(bottom: BorderSide(color: line)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: panel,
                        border: Border.all(color: line),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        m.media.isEmpty
                            ? Icons.article_outlined
                            : Icons.play_circle_outline,
                        color: muted,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: .start,
                        children: [
                          Text(
                            m.title,
                            maxLines: 1,
                            overflow: .ellipsis,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: .w600,
                            ),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            '${m.created.day}/${m.created.month}/${m.created.year}  ·  ${m.duration == 0 ? 'Notes préparatoires' : timeLabel(m.duration)}',
                            style: const TextStyle(color: muted, fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                    BadgeLabel(
                      m.status.label,
                      color: m.status == .ready
                          ? const Color(0xff9bc5ac)
                          : muted,
                    ),
                    const SizedBox(width: 16),
                    DeleteMeetingButton(
                      meeting: m,
                      onDelete: busy ? null : () => onDelete(m),
                    ),
                    const SizedBox(width: 8),
                    const Icon(Icons.chevron_right, size: 18, color: muted),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}
