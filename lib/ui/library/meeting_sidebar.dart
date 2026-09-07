import 'package:flutter/material.dart';

import '../../models/meeting.dart';
import '../core/app_theme.dart';
import '../core/navigation_item.dart';

class MeetingSidebar extends StatelessWidget {
  const MeetingSidebar({
    super.key,
    required this.compact,
    required this.meetings,
    required this.selected,
    required this.search,
    required this.onSearch,
    required this.onSelect,
    required this.onCreate,
    required this.onSettings,
    required this.onGuide,
  });
  final bool compact;
  final List<Meeting> meetings;
  final Meeting? selected;
  final String search;
  final ValueChanged<String> onSearch;
  final ValueChanged<Meeting?> onSelect;
  final VoidCallback onCreate;
  final VoidCallback onSettings;
  final VoidCallback onGuide;
  @override
  Widget build(BuildContext context) => Container(
    width: compact ? 76 : 244,
    padding: EdgeInsets.symmetric(horizontal: compact ? 10 : 18, vertical: 20),
    decoration: const BoxDecoration(
      color: Color(0xff101012),
      border: Border(right: BorderSide(color: line)),
    ),
    child: Column(
      crossAxisAlignment: .stretch,
      children: [
        Row(
          mainAxisAlignment: compact ? .center : .start,
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: const Color(0xff27272b),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.graphic_eq_rounded, color: ink),
            ),
            if (!compact) ...[
              const SizedBox(width: 12),
              const Text(
                'memora',
                style: TextStyle(
                  fontSize: 21,
                  fontWeight: .w700,
                  letterSpacing: -1,
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 26),
        NavigationItem(
          icon: Icons.space_dashboard_outlined,
          title: 'Bibliothèque',
          active: selected == null,
          action: () => onSelect(null),
          compact: compact,
        ),
        const SizedBox(height: 12),
        if (!compact)
          TextField(
            key: const ValueKey('meeting-search'),
            onChanged: onSearch,
            decoration: const InputDecoration(
              hintText: 'Rechercher un meeting',
              prefixIcon: Icon(Icons.search, size: 18),
              isDense: true,
            ),
          ),
        const SizedBox(height: 26),
        Row(
          mainAxisAlignment: .spaceBetween,
          children: [
            if (!compact)
              const Text(
                'MEETINGS',
                style: TextStyle(
                  fontSize: 10,
                  letterSpacing: 1.8,
                  color: muted,
                  fontWeight: .w700,
                ),
              ),
            IconButton(
              key: const ValueKey('new-meeting'),
              tooltip: 'Préparer un meeting',
              onPressed: onCreate,
              icon: const Icon(Icons.add, size: 20),
            ),
          ],
        ),
        Expanded(
          child: ListView(
            children: [
              for (final m in meetings.where(
                (m) => m.title.toLowerCase().contains(search.toLowerCase()),
              ))
                Padding(
                  padding: const EdgeInsets.only(bottom: 7),
                  child: NavigationItem(
                    icon: m.media.isEmpty
                        ? Icons.edit_note_rounded
                        : Icons.video_library_outlined,
                    title: m.title,
                    active: m == selected,
                    action: () => onSelect(m),
                    compact: compact,
                    subtitle:
                        '${m.created.day}/${m.created.month} · ${m.status.label}',
                  ),
                ),
            ],
          ),
        ),
        const Divider(),
        NavigationItem(
          icon: Icons.tune_rounded,
          title: 'Moteurs locaux',
          active: false,
          action: onSettings,
          compact: compact,
        ),
        NavigationItem(
          icon: Icons.help_outline_rounded,
          title: 'Guide OBS',
          active: false,
          action: onGuide,
          compact: compact,
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: .center,
          children: [
            const Icon(Icons.lock_outline, color: Color(0xff83c8a7), size: 14),
            if (!compact) ...[
              const SizedBox(width: 8),
              const Flexible(
                child: Text(
                  'Stockage local',
                  overflow: .ellipsis,
                  style: TextStyle(color: muted, fontSize: 11),
                ),
              ),
            ],
          ],
        ),
      ],
    ),
  );
}
