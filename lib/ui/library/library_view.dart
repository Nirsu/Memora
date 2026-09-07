import 'package:flutter/material.dart';

import '../../models/meeting.dart';
import '../../utils/timestamps.dart';
import '../core/app_theme.dart';
import '../core/delete_meeting_button.dart';
import '../core/surfaces.dart';

enum LibraryFilter {
  all('Tous'),
  notes('Notes seules'),
  recordings('Enregistrements'),
  summaries('Avec résumé');

  const LibraryFilter(this.label);
  final String label;
  bool includes(Meeting meeting) => switch (this) {
    .all => true,
    .notes => meeting.media.isEmpty,
    .recordings => meeting.media.isNotEmpty,
    .summaries => meeting.summary.trim().isNotEmpty,
  };
}

class LibraryView extends StatefulWidget {
  const LibraryView({
    super.key,
    required this.meetings,
    required this.search,
    required this.onSearch,
    required this.busy,
    required this.onCreate,
    required this.onImport,
    required this.onGuide,
    required this.onSelect,
    required this.onDelete,
  });
  final List<Meeting> meetings;
  final String search;
  final ValueChanged<String> onSearch;
  final bool busy;
  final VoidCallback onCreate, onImport, onGuide;
  final ValueChanged<Meeting> onSelect, onDelete;
  @override
  State<LibraryView> createState() => _LibraryViewState();
}

class _LibraryViewState extends State<LibraryView> {
  LibraryFilter filter = .all;
  @override
  Widget build(BuildContext context) {
    final visible =
        widget.meetings
            .where(
              (meeting) =>
                  filter.includes(meeting) &&
                  meeting.title.toLowerCase().contains(
                    widget.search.trim().toLowerCase(),
                  ),
            )
            .toList()
          ..sort((a, b) => b.created.compareTo(a.created));
    return ListView(
      children: [
        const Text(
          'ESPACE PERSONNEL',
          style: TextStyle(color: muted, fontSize: 10, letterSpacing: 1.5),
        ),
        const SizedBox(height: 18),
        const Text(
          'Bibliothèque',
          key: ValueKey('library-title'),
          style: TextStyle(fontSize: 30, fontWeight: .w600, letterSpacing: -.8),
        ),
        const SizedBox(height: 8),
        const Text(
          'Vos notes, vos conversations, ce qui compte.',
          style: TextStyle(color: muted, fontSize: 13),
        ),
        const SizedBox(height: 22),
        Wrap(
          spacing: 10,
          runSpacing: 8,
          children: [
            FilledButton.icon(
              key: const ValueKey('prepare-home'),
              onPressed: widget.onCreate,
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Nouveau meeting'),
            ),
            OutlinedButton.icon(
              key: const ValueKey('import-home'),
              onPressed: widget.busy ? null : widget.onImport,
              icon: const Icon(Icons.file_upload_outlined, size: 18),
              label: const Text('Importer un enregistrement'),
            ),
          ],
        ),
        const SizedBox(height: 28),
        TextFormField(
          key: const ValueKey('meeting-search'),
          initialValue: widget.search,
          onChanged: widget.onSearch,
          decoration: const InputDecoration(
            hintText: 'Rechercher par titre…',
            prefixIcon: Icon(Icons.search, size: 18),
            isDense: true,
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final value in LibraryFilter.values)
              ChoiceChip(
                label: Text(value.label, style: const TextStyle(fontSize: 12)),
                selected: filter == value,
                showCheckmark: false,
                selectedColor: selectedSurface,
                onSelected: (_) => setState(() => filter = value),
              ),
          ],
        ),
        const SizedBox(height: 26),
        Text(
          '${visible.length} meeting${visible.length == 1 ? '' : 's'} · Les plus récents d’abord',
          style: const TextStyle(color: muted, fontSize: 11),
        ),
        const SizedBox(height: 12),
        if (visible.isEmpty)
          Panel(
            child: Column(
              children: [
                const Icon(Icons.article_outlined, color: muted, size: 28),
                const SizedBox(height: 14),
                Text(
                  widget.meetings.isEmpty
                      ? 'Votre prochain meeting commence ici.'
                      : 'Aucun meeting ne correspond à ces critères.',
                ),
                const SizedBox(height: 8),
                const Text(
                  'Préparez vos notes ou importez un enregistrement OBS.',
                  textAlign: .center,
                  style: TextStyle(color: muted, fontSize: 12),
                ),
                TextButton(
                  onPressed: widget.onGuide,
                  child: const Text('Comment enregistrer avec OBS'),
                ),
              ],
            ),
          ),
        for (var index = 0; index < visible.length; index++) ...[
          if (index == 0 ||
              DateUtils.dateOnly(visible[index - 1].created) !=
                  DateUtils.dateOnly(visible[index].created))
            Padding(
              padding: const EdgeInsets.only(top: 20, bottom: 8),
              child: Text(
                '${visible[index].created.day}/${visible[index].created.month}/${visible[index].created.year}',
                style: const TextStyle(color: muted, fontSize: 11),
              ),
            ),
          _MeetingRow(
            meeting: visible[index],
            busy: widget.busy,
            onSelect: widget.onSelect,
            onDelete: widget.onDelete,
          ),
        ],
      ],
    );
  }
}

class _MeetingRow extends StatelessWidget {
  const _MeetingRow({
    required this.meeting,
    required this.busy,
    required this.onSelect,
    required this.onDelete,
  });
  final Meeting meeting;
  final bool busy;
  final ValueChanged<Meeting> onSelect, onDelete;
  @override
  Widget build(BuildContext context) => Material(
    color: Colors.transparent,
    child: InkWell(
      onTap: () => onSelect(meeting),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: line)),
        ),
        child: Row(
          children: [
            Icon(
              meeting.media.isEmpty
                  ? Icons.edit_note
                  : Icons.play_circle_outline,
              color: muted,
              size: 22,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: .start,
                children: [
                  Text(
                    meeting.title,
                    maxLines: 1,
                    overflow: .ellipsis,
                    style: const TextStyle(fontSize: 13, fontWeight: .w600),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    meeting.media.isEmpty
                        ? 'Notes personnelles'
                        : '${timeLabel(meeting.duration)} · ${meeting.hasVideo ? 'Vidéo' : 'Audio'}',
                    style: const TextStyle(color: muted, fontSize: 11),
                  ),
                ],
              ),
            ),
            BadgeLabel(
              meeting.status == .ready
                  ? 'Résumé disponible'
                  : meeting.status.label,
              color: muted,
            ),
            const SizedBox(width: 8),
            DeleteMeetingButton(
              meeting: meeting,
              onDelete: busy ? null : () => onDelete(meeting),
            ),
          ],
        ),
      ),
    ),
  );
}
