import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:flutter/material.dart';

import '../../models/meeting.dart';
import '../../utils/timestamps.dart';
import '../core/app_theme.dart';
import '../core/surfaces.dart';

class ReplayPane extends StatefulWidget {
  const ReplayPane({
    super.key,
    required this.meeting,
    required this.player,
    required this.video,
    required this.busy,
    required this.onCapture,
    required this.onExportAudio,
    required this.onOpenFolder,
  });
  final Meeting meeting;
  final Player? player;
  final VideoController? video;
  final bool busy;
  final VoidCallback onCapture;
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
  Widget build(BuildContext context) => SingleChildScrollView(
    child: Column(
      crossAxisAlignment: .stretch,
      children: [
        Panel(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: .start,
            children: [
              const Row(
                children: [
                  Icon(Icons.play_circle_outline, color: accent, size: 19),
                  SizedBox(width: 9),
                  Expanded(
                    child: Text(
                      'Le fil de la conversation',
                      style: TextStyle(fontWeight: .w600),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: AspectRatio(
                  aspectRatio: 16 / 10,
                  child: meeting.media.isEmpty || video == null
                      ? Container(
                          color: const Color(0xff12141b),
                          child: const Column(
                            mainAxisAlignment: .center,
                            children: [
                              Icon(
                                Icons.movie_outlined,
                                size: 38,
                                color: muted,
                              ),
                              SizedBox(height: 14),
                              Text(
                                'Votre replay attend ici',
                                style: TextStyle(color: muted, fontSize: 12),
                              ),
                            ],
                          ),
                        )
                      : audioOnly || !meeting.hasVideo
                      ? Container(
                          color: const Color(0xff202023),
                          child: const Center(
                            child: Icon(
                              Icons.graphic_eq_rounded,
                              color: accent,
                              size: 66,
                            ),
                          ),
                        )
                      : Video(controller: video!, controls: null),
                ),
              ),
              if (meeting.media.isNotEmpty && player != null) ...[
                const SizedBox(height: 12),
                StreamBuilder<Duration>(
                  stream: player!.stream.position,
                  initialData: player!.state.position,
                  builder: (_, snap) {
                    final position = snap.data!.inMilliseconds;
                    final duration = player!.state.duration.inMilliseconds;
                    return Column(
                      children: [
                        Slider(
                          value: position
                              .clamp(0, duration > 0 ? duration : 1)
                              .toDouble(),
                          max: (duration > 0 ? duration : 1).toDouble(),
                          onChanged: (v) =>
                              player!.seek(Duration(milliseconds: v.round())),
                        ),
                        Row(
                          children: [
                            Text(
                              timeLabel(position),
                              style: const TextStyle(
                                color: muted,
                                fontSize: 11,
                              ),
                            ),
                            const Spacer(),
                            Text(
                              timeLabel(duration),
                              style: const TextStyle(
                                color: muted,
                                fontSize: 11,
                              ),
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
                              (player!.state.position.inMilliseconds - 10000)
                                  .clamp(0, 1 << 40),
                        ),
                      ),
                      icon: const Icon(Icons.replay_10),
                    ),
                    StreamBuilder<bool>(
                      stream: player!.stream.playing,
                      initialData: false,
                      builder: (_, snap) => IconButton.filled(
                        key: const ValueKey('play-pause'),
                        tooltip: 'Lecture / pause',
                        onPressed: player!.playOrPause,
                        icon: Icon(
                          snap.data!
                              ? Icons.pause_rounded
                              : Icons.play_arrow_rounded,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Avancer de 10 secondes',
                      onPressed: () => player!.seek(
                        player!.state.position + const Duration(seconds: 10),
                      ),
                      icon: const Icon(Icons.forward_10),
                    ),
                  ],
                ),
                Row(
                  children: [
                    const Text(
                      'Audio seul',
                      style: TextStyle(color: muted, fontSize: 12),
                    ),
                    const Spacer(),
                    Switch(
                      value: audioOnly,
                      onChanged: (v) => setState(() => audioOnly = v),
                    ),
                  ],
                ),
                if (meeting.hasVideo)
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: !widget.busy ? widget.onCapture : null,
                      icon: const Icon(
                        Icons.add_photo_alternate_outlined,
                        size: 18,
                      ),
                      label: const Text('Ajouter cette image'),
                    ),
                  ),
                TextButton.icon(
                  onPressed: !widget.busy ? widget.onExportAudio : null,
                  icon: const Icon(Icons.file_download_outlined, size: 16),
                  label: const Text("Exporter l'audio"),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),
        Panel(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: .start,
            children: [
              BadgeLabel('SUR CET ORDINATEUR', color: const Color(0xff8ad3b1)),
              const SizedBox(height: 14),
              const Text(
                'Un espace privé, par défaut.',
                style: TextStyle(fontWeight: .w600),
              ),
              const SizedBox(height: 10),
              const Text(
                "Enregistrement original, notes et résultats sont conservés ensemble. Aucune réunion n'est envoyée à un service cloud.",
                style: TextStyle(color: muted, height: 1.7, fontSize: 12),
              ),
              const SizedBox(height: 8),
              TextButton(
                key: const ValueKey('open-meeting-folder'),
                onPressed: widget.onOpenFolder,
                child: const Text(
                  'Ouvrir le dossier du meeting',
                  style: TextStyle(fontSize: 12),
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}
