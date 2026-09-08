import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:flutter/material.dart';

import '../../models/meeting.dart';
import '../../utils/timestamps.dart';
import '../core/app_theme.dart';
import '../../models/replay_moment.dart';

class ReplayPane extends StatefulWidget {
  const ReplayPane({
    super.key,
    required this.meeting,
    required this.player,
    required this.video,
    required this.busy,
    required this.onCapture,
    required this.onSeek,
    required this.onExportAudio,
    required this.onOpenFolder,
  });
  final Meeting meeting;
  final Player? player;
  final VideoController? video;
  final bool busy;
  final VoidCallback onCapture;
  final ValueChanged<int> onSeek;
  final VoidCallback onExportAudio;
  final VoidCallback onOpenFolder;
  @override
  State<ReplayPane> createState() => _ReplayPaneState();
}

class _ReplayPaneState extends State<ReplayPane> {
  Meeting get meeting => widget.meeting;
  bool audioOnly = false;
  Player? get player => widget.player;
  VideoController? get video => widget.video;
  @override
  Widget build(BuildContext context) {
    final moments = replayMoments(meeting);
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: .stretch,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'RELECTURE',
                  style: TextStyle(
                    color: muted,
                    fontSize: 10,
                    letterSpacing: 1.5,
                  ),
                ),
              ),
              if (meeting.hasVideo)
                TextButton.icon(
                  onPressed: () => setState(() => audioOnly = !audioOnly),
                  icon: Icon(
                    audioOnly
                        ? Icons.videocam_outlined
                        : Icons.headphones_outlined,
                    size: 16,
                  ),
                  label: Text(
                    audioOnly ? 'Vidéo' : 'Audio seul',
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          if (meeting.hasVideo && !audioOnly)
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: video == null
                    ? const ColoredBox(
                        color: panel,
                        child: Center(
                          child: Text(
                            'Chargement de la vidéo…',
                            style: TextStyle(color: muted),
                          ),
                        ),
                      )
                    : Video(controller: video!, controls: null),
              ),
            )
          else
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Row(
                mainAxisAlignment: .center,
                children: [
                  Icon(Icons.headphones_outlined, color: muted, size: 22),
                  SizedBox(width: 10),
                  Text('Écoute audio', style: TextStyle(color: muted)),
                ],
              ),
            ),
          if (meeting.media.isNotEmpty && player != null) ...[
            StreamBuilder<Duration>(
              stream: player!.stream.position,
              initialData: player!.state.position,
              builder: (context, snapshot) {
                final position = snapshot.data!.inMilliseconds;
                final duration = player!.state.duration.inMilliseconds;
                return Column(
                  children: [
                    Slider(
                      value: position
                          .clamp(0, duration > 0 ? duration : 1)
                          .toDouble(),
                      max: (duration > 0 ? duration : 1).toDouble(),
                      onChanged: duration > 0
                          ? (value) => player!.seek(
                              Duration(milliseconds: value.round()),
                            )
                          : null,
                    ),
                    Row(
                      mainAxisAlignment: .spaceBetween,
                      children: [
                        Text(
                          timeLabel(position),
                          style: const TextStyle(fontSize: 11, color: muted),
                        ),
                        Text(
                          timeLabel(duration),
                          style: const TextStyle(fontSize: 11, color: muted),
                        ),
                      ],
                    ),
                  ],
                );
              },
            ),
            Row(
              mainAxisAlignment: .center,
              children: [
                IconButton(
                  tooltip: 'Reculer de 10 secondes',
                  onPressed: () => player!.seek(
                    Duration(
                      milliseconds:
                          (player!.state.position.inMilliseconds - 10000).clamp(
                            0,
                            1 << 40,
                          ),
                    ),
                  ),
                  icon: const Icon(Icons.replay_10),
                ),
                StreamBuilder<bool>(
                  stream: player!.stream.playing,
                  initialData: player!.state.playing,
                  builder: (context, snapshot) => IconButton.filled(
                    key: const ValueKey('play-pause'),
                    tooltip: 'Lecture / pause',
                    onPressed: player!.playOrPause,
                    icon: Icon(
                      snapshot.data!
                          ? Icons.pause_rounded
                          : Icons.play_arrow_rounded,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Avancer de 10 secondes',
                  onPressed: () => player!.seek(
                    Duration(
                      milliseconds:
                          (player!.state.position.inMilliseconds + 10000).clamp(
                            0,
                            player!.state.duration.inMilliseconds,
                          ),
                    ),
                  ),
                  icon: const Icon(Icons.forward_10),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: [
                if (meeting.hasVideo)
                  OutlinedButton.icon(
                    onPressed: widget.busy ? null : widget.onCapture,
                    icon: const Icon(
                      Icons.add_photo_alternate_outlined,
                      size: 16,
                    ),
                    label: const Text('Capturer l’image'),
                  ),
                TextButton.icon(
                  onPressed: widget.busy ? null : widget.onExportAudio,
                  icon: const Icon(Icons.file_download_outlined, size: 16),
                  label: const Text('Exporter l’audio'),
                ),
              ],
            ),
            const SizedBox(height: 20),
            StreamBuilder<Duration>(
              stream: player!.stream.position,
              initialData: player!.state.position,
              builder: (context, snapshot) {
                final position = snapshot.data!.inMilliseconds;
                final source = meeting.segments
                    .where(
                      (segment) =>
                          segment.start <= position && position < segment.end,
                    )
                    .firstOrNull;
                return Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: panel,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: .start,
                    children: [
                      Text(
                        source == null || meeting.speakerLabel(source).isEmpty
                            ? 'PASSAGE EN COURS'
                            : meeting.speakerLabel(source),
                        style: const TextStyle(
                          fontSize: 10,
                          color: muted,
                          letterSpacing: 1,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        source?.text ??
                            (meeting.segments.isEmpty
                                ? 'La transcription apparaîtra après l’analyse.'
                                : 'Aucun passage transcrit à cet instant.'),
                        maxLines: 6,
                        overflow: .ellipsis,
                        style: const TextStyle(fontSize: 12, height: 1.7),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
          const SizedBox(height: 24),
          const Text(
            'PASSAGES À REVOIR',
            style: TextStyle(color: muted, fontSize: 10, letterSpacing: 1.5),
          ),
          const SizedBox(height: 8),
          if (moments.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Text(
                'Les passages cités dans le résumé et vos captures apparaîtront ici.',
                style: TextStyle(color: muted, fontSize: 12, height: 1.7),
              ),
            ),
          for (final moment in moments)
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => widget.onSeek(moment.time),
                borderRadius: BorderRadius.circular(6),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: 12,
                    horizontal: 8,
                  ),
                  child: Row(
                    crossAxisAlignment: .start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: selectedSurface,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          timeLabel(moment.time),
                          style: const TextStyle(fontSize: 10),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: .start,
                          children: [
                            Text(
                              moment.section,
                              style: const TextStyle(
                                color: muted,
                                fontSize: 10,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              moment.title,
                              maxLines: 3,
                              overflow: .ellipsis,
                              style: const TextStyle(fontSize: 12, height: 1.5),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          const SizedBox(height: 16),
          const Divider(),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              key: const ValueKey('open-meeting-folder'),
              onPressed: widget.onOpenFolder,
              icon: const Icon(Icons.folder_open_outlined, size: 16),
              label: const Text(
                'Dossier local du meeting',
                style: TextStyle(color: muted, fontSize: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
