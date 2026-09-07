import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

import '../../models/meeting.dart';
import '../core/surfaces.dart';
import '../workspace_view_model.dart';
import 'meeting_header.dart';
import 'notes_pane.dart';
import 'replay_pane.dart';
import 'summary_pane.dart';
import 'transcript_pane.dart';

/// Composes the meeting panes. Leaf widgets only receive their own data and
/// callbacks; mutations always go through the view model.
class MeetingView extends StatelessWidget {
  const MeetingView({
    super.key,
    required this.meeting,
    required this.model,
    required this.wide,
    required this.player,
    required this.video,
    required this.onBack,
    required this.onRename,
    required this.onDelete,
    required this.onImport,
    required this.onExport,
    required this.onExportAudio,
    required this.onOpenFolder,
    required this.onAdopt,
    required this.onSeek,
    required this.onEditSpeaker,
    required this.onEditText,
    required this.onEditCaption,
  });

  final Meeting meeting;
  final WorkspaceViewModel model;
  final bool wide;
  final Player? player;
  final VideoController? video;
  final VoidCallback onBack,
      onRename,
      onDelete,
      onImport,
      onExport,
      onExportAudio,
      onOpenFolder,
      onAdopt;
  final ValueChanged<int> onSeek;
  final ValueChanged<Segment> onEditSpeaker, onEditText;
  final ValueChanged<Capture> onEditCaption;

  @override
  Widget build(BuildContext context) {
    final replay = ReplayPane(
      key: ValueKey('replay-${meeting.id}'),
      meeting: meeting,
      player: player,
      video: video,
      busy: model.busy,
      onCapture: () => model.safely(
        () => model.addCapture(
          meeting,
          player?.state.position.inMilliseconds ?? 0,
        ),
      ),
      onExportAudio: onExportAudio,
      onOpenFolder: onOpenFolder,
    );
    return Column(
      crossAxisAlignment: .start,
      children: [
        MeetingHeader(
          meeting: meeting,
          busy: model.busy,
          processing: model.busyId == meeting.id,
          detail: model.engine.detail,
          saveState: model.saveState.label,
          onBack: onBack,
          onRename: onRename,
          onDelete: onDelete,
          onImport: onImport,
          onAnalyze: () => model.safely(() => model.analyze(meeting)),
          onExport: onExport,
          onCancel: model.cancel,
        ),
        const SizedBox(height: 22),
        Expanded(
          child: Row(
            crossAxisAlignment: .stretch,
            children: [
              Expanded(
                child: DefaultTabController(
                  key: ValueKey('${meeting.id}-$wide'),
                  length: wide ? 3 : 4,
                  initialIndex: meeting.media.isEmpty ? 2 : 0,
                  child: Panel(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        TabBar(
                          isScrollable: true,
                          tabAlignment: .start,
                          tabs: [
                            const Tab(text: 'Résumé'),
                            const Tab(text: 'Transcription'),
                            const Tab(text: 'Mes notes'),
                            if (!wide) const Tab(text: 'Replay'),
                          ],
                        ),
                        Expanded(
                          child: TabBarView(
                            children: [
                              SummaryPane(
                                meeting: meeting,
                                folder: model.repository.folder(meeting),
                                onChanged: (value) => model.safely(
                                  () => model.updateSummary(meeting, value),
                                ),
                                onSeek: onSeek,
                                onAdopt: onAdopt,
                                onEditCaption: onEditCaption,
                                onRemoveCapture: (capture) => model.safely(
                                  () => model.removeCapture(meeting, capture),
                                ),
                              ),
                              TranscriptPane(
                                meeting: meeting,
                                onSeek: onSeek,
                                onEditSpeaker: onEditSpeaker,
                                onEditText: onEditText,
                              ),
                              NotesPane(
                                meeting: meeting,
                                markerStart: model.markerStart(meeting),
                                onToggleMarker: () =>
                                    model.toggleMarker(meeting),
                                onChanged: (value) => model.safely(
                                  () => model.updateNotes(meeting, value),
                                ),
                                position: () =>
                                    player?.state.position.inMilliseconds ?? 0,
                              ),
                              if (!wide) replay,
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              if (wide) ...[
                const SizedBox(width: 20),
                SizedBox(width: 360, child: replay),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
