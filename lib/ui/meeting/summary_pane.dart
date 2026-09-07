import 'dart:io';

import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:flutter/material.dart';

import '../../models/meeting.dart';
import '../../utils/timestamps.dart';
import '../core/app_theme.dart';

class SummaryPane extends StatefulWidget {
  const SummaryPane({
    super.key,
    required this.meeting,
    required this.folder,
    required this.onChanged,
    required this.onSeek,
    required this.onAdopt,
    required this.onEditCaption,
    required this.onRemoveCapture,
  });
  final Meeting meeting;
  final String folder;
  final ValueChanged<String> onChanged;
  final ValueChanged<int> onSeek;
  final VoidCallback onAdopt;
  final ValueChanged<Capture> onEditCaption;
  final ValueChanged<Capture> onRemoveCapture;
  @override
  State<SummaryPane> createState() => _SummaryPaneState();
}

class _SummaryPaneState extends State<SummaryPane> {
  Meeting get meeting => widget.meeting;

  bool editingSummary = false;
  late final summary = TextEditingController(text: meeting.summary);
  @override
  void didUpdateWidget(covariant SummaryPane oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (summary.text != meeting.summary) summary.text = meeting.summary;
  }

  @override
  void dispose() {
    summary.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (meeting.summary.isEmpty && !editingSummary) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(25),
          child: Column(
            mainAxisSize: .min,
            children: [
              const Icon(Icons.auto_awesome_outlined, size: 40, color: accent),
              const SizedBox(height: 18),
              const Text(
                "L'essentiel, après la conversation.",
                style: TextStyle(fontWeight: .w600, fontSize: 19),
              ),
              const SizedBox(height: 12),
              Text(
                meeting.media.isEmpty
                    ? "Rattachez votre enregistrement, puis lancez l'analyse.\nVos notes sont déjà disponibles dans « Mes notes »."
                    : "Lancez « Transcrire et résumer » pour retrouver\nles sujets, les décisions et les actions.",
                textAlign: .center,
                style: const TextStyle(color: muted, height: 1.7),
              ),
            ],
          ),
        ),
      );
    }
    return Column(
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'Généré localement · à relire',
                style: TextStyle(color: muted, fontSize: 11),
              ),
            ),
            TextButton.icon(
              onPressed: () => setState(() {
                editingSummary = !editingSummary;
                summary.text = meeting.summary;
              }),
              icon: Icon(
                editingSummary
                    ? Icons.visibility_outlined
                    : Icons.edit_outlined,
                size: 16,
              ),
              label: Text(editingSummary ? 'Aperçu' : 'Modifier'),
            ),
            PopupMenuButton<String>(
              tooltip: 'Versions du résumé',
              onSelected: (_) => widget.onAdopt(),
              itemBuilder: (_) => [
                const PopupMenuItem(
                  value: 'latest',
                  child: Text('Utiliser le dernier résumé généré'),
                ),
              ],
            ),
          ],
        ),
        Expanded(
          child: editingSummary
              ? TextField(
                  key: const ValueKey('summary-editor'),
                  controller: summary,
                  expands: true,
                  maxLines: null,
                  minLines: null,
                  textAlignVertical: .top,
                  style: const TextStyle(height: 1.8, fontSize: 14),
                  onChanged: widget.onChanged,
                )
              : SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Column(
                      crossAxisAlignment: .start,
                      children: [
                        MarkdownBody(
                          data: meeting.summary,
                          selectable: true,
                          styleSheet: MarkdownStyleSheet(
                            p: const TextStyle(
                              height: 1.8,
                              color: ink,
                              fontSize: 14,
                            ),
                            h2: const TextStyle(
                              fontSize: 21,
                              fontWeight: .w600,
                              height: 2,
                            ),
                            a: const TextStyle(color: accent),
                          ),
                          imageBuilder: (_, _, _) => const SizedBox.shrink(),
                          onTapLink: (_, href, _) {
                            final ms = replayTimestamp(href);
                            if (ms != null) widget.onSeek(ms);
                          },
                        ),
                        if (meeting.captures.isNotEmpty) ...[
                          const SizedBox(height: 24),
                          const Text(
                            'Repères visuels',
                            style: TextStyle(fontSize: 20, fontWeight: .w600),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Images proposées autour des passages clés. Ajustez-les au besoin.',
                            style: TextStyle(color: muted, fontSize: 12),
                          ),
                          const SizedBox(height: 16),
                        ],
                        for (final c in meeting.captures)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 20),
                            child: Column(
                              crossAxisAlignment: .start,
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: InkWell(
                                    onTap: () => widget.onSeek(c.time),
                                    child: Image.file(
                                      File('${widget.folder}/${c.file}'),
                                      fit: .fitWidth,
                                      errorBuilder: (_, _, _) =>
                                          const Text('Image introuvable'),
                                    ),
                                  ),
                                ),
                                Row(
                                  children: [
                                    TextButton(
                                      onPressed: () => widget.onSeek(c.time),
                                      child: Text(timeLabel(c.time)),
                                    ),
                                    Expanded(
                                      child: Text(
                                        c.caption,
                                        maxLines: 2,
                                        style: const TextStyle(
                                          color: muted,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                    IconButton(
                                      tooltip: 'Modifier la légende',
                                      onPressed: () => widget.onEditCaption(c),
                                      icon: const Icon(
                                        Icons.edit_outlined,
                                        size: 16,
                                      ),
                                    ),
                                    IconButton(
                                      tooltip: 'Retirer du résumé',
                                      onPressed: () =>
                                          widget.onRemoveCapture(c),
                                      icon: const Icon(Icons.close, size: 16),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
        ),
      ],
    );
  }
}
