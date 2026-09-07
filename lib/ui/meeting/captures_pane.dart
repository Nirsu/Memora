import 'dart:io';

import 'package:flutter/material.dart';

import '../../models/meeting.dart';
import '../../utils/timestamps.dart';
import '../core/app_theme.dart';

class CapturesPane extends StatelessWidget {
  const CapturesPane({
    super.key,
    required this.meeting,
    required this.folder,
    required this.onSeek,
    required this.onEditCaption,
    required this.onRemove,
  });
  final Meeting meeting;
  final String folder;
  final ValueChanged<int> onSeek;
  final ValueChanged<Capture> onEditCaption, onRemove;

  @override
  Widget build(BuildContext context) {
    if (meeting.captures.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Aucune capture pour le moment.\nDepuis le lecteur vidéo, ajoutez une image au passage qui compte.',
            textAlign: .center,
            style: TextStyle(color: muted, height: 1.8),
          ),
        ),
      );
    }
    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 20),
      children: [
        const Text(
          'REPÈRES VISUELS',
          style: TextStyle(color: muted, fontSize: 10, letterSpacing: 1.5),
        ),
        const SizedBox(height: 8),
        const Text(
          'Agrandissez une image ou retrouvez son passage dans le replay.',
          style: TextStyle(color: muted, fontSize: 12),
        ),
        const SizedBox(height: 20),
        for (final capture in meeting.captures)
          CaptureCard(
            capture: capture,
            folder: folder,
            onSeek: onSeek,
            onEditCaption: onEditCaption,
            onRemove: onRemove,
          ),
      ],
    );
  }
}

class CaptureCard extends StatelessWidget {
  const CaptureCard({
    super.key,
    required this.capture,
    required this.folder,
    required this.onSeek,
    required this.onEditCaption,
    required this.onRemove,
  });
  final Capture capture;
  final String folder;
  final ValueChanged<int> onSeek;
  final ValueChanged<Capture> onEditCaption, onRemove;

  Widget picture() => Image.file(
    File('$folder/${capture.file}'),
    fit: .contain,
    errorBuilder: (_, _, _) => const Padding(
      padding: EdgeInsets.all(32),
      child: Text('Image introuvable', style: TextStyle(color: muted)),
    ),
  );

  void enlarge(BuildContext context) => showDialog<void>(
    context: context,
    builder: (context) => Dialog(
      insetPadding: const EdgeInsets.all(32),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 20, right: 8, top: 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    capture.caption.isEmpty
                        ? 'Capture · ${timeLabel(capture.time)}'
                        : capture.caption,
                    maxLines: 2,
                    overflow: .ellipsis,
                  ),
                ),
                IconButton(
                  tooltip: 'Fermer l’image',
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
          ),
          Expanded(
            child: InteractiveViewer(
              minScale: .5,
              maxScale: 5,
              child: Center(child: picture()),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextButton.icon(
              onPressed: () {
                Navigator.pop(context);
                onSeek(capture.time);
              },
              icon: const Icon(Icons.play_arrow, size: 18),
              label: Text('Revoir à ${timeLabel(capture.time)}'),
            ),
          ),
        ],
      ),
    ),
  );

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 24),
    child: Column(
      crossAxisAlignment: .stretch,
      children: [
        Tooltip(
          message: 'Agrandir l’image',
          child: InkWell(
            onTap: () => enlarge(context),
            borderRadius: BorderRadius.circular(8),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: picture(),
            ),
          ),
        ),
        Row(
          children: [
            TextButton(
              onPressed: () => onSeek(capture.time),
              child: Text(
                timeLabel(capture.time),
                style: const TextStyle(fontSize: 11),
              ),
            ),
            Expanded(
              child: Text(
                capture.caption,
                maxLines: 2,
                overflow: .ellipsis,
                style: const TextStyle(color: muted, fontSize: 12),
              ),
            ),
            IconButton(
              tooltip: 'Modifier la légende',
              onPressed: () => onEditCaption(capture),
              icon: const Icon(Icons.edit_outlined, size: 16),
            ),
            IconButton(
              tooltip: 'Retirer du résumé',
              onPressed: () => onRemove(capture),
              icon: const Icon(Icons.close, size: 16),
            ),
          ],
        ),
      ],
    ),
  );
}
