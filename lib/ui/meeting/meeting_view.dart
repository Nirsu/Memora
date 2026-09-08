import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

import '../../models/meeting.dart';
import '../core/app_theme.dart';
import '../dialogs/meeting_dialogs.dart';
import 'captures_pane.dart';
import '../workspace_view_model.dart';
import 'meeting_header.dart';
import 'notes_pane.dart';
import 'replay_pane.dart';
import 'summary_pane.dart';
import 'transcript_pane.dart';

/// Composes the meeting panes. Leaf widgets only receive their own data and
/// callbacks; mutations always go through the view model.
class MeetingView extends StatefulWidget {
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
    this.onRenameSpeaker,
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
  final ValueChanged<String>? onRenameSpeaker;

  @override
  State<MeetingView> createState() => _MeetingViewState();
}

enum MeetingTab {
  summary('Résumé'),
  transcript('Transcription'),
  notes('Mes notes'),
  captures('Captures');

  const MeetingTab(this.label);
  final String label;
}

class _MeetingViewState extends State<MeetingView> {
  late MeetingTab tab = widget.meeting.media.isEmpty ? .notes : .summary;
  late bool readerVisible = widget.wide;
  double readerFraction = .43;
  final documentKey = GlobalKey();
  final readerKey = GlobalKey();
  Meeting get meeting => widget.meeting;
  WorkspaceViewModel get model => widget.model;

  void seek(int time) {
    setState(() => readerVisible = true);
    widget.onSeek(time);
  }

  Future<void> detectSpeakers(int count) async {
    if (model.busy) return;
    if (meeting.speakersDetected) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (_) => const ConfirmMeetingDialog(
          title: 'Recalculer les voix ?',
          message: 'Les groupes seront recalculés et devront être nommés à nouveau. Les corrections individuelles sont conservées et les anciennes attributions sont sauvegardées dans le dossier du meeting.',
          acceptLabel: 'Recalculer',
        ),
      );
      if (confirmed != true || !mounted || model.busy) return;
    }
    await model.detectSpeakers(meeting, count);
  }

  @override
  Widget build(BuildContext context) {
    final hasMedia = meeting.media.isNotEmpty;
    final showReader = hasMedia && readerVisible;
    final document = Column(
      key: documentKey,
      crossAxisAlignment: .stretch,
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (final value in MeetingTab.values)
                TextButton(
                  key: ValueKey('tab-${value.name}'),
                  onPressed: () => setState(() => tab = value),
                  style: TextButton.styleFrom(
                    foregroundColor: tab == value ? ink : muted,
                    backgroundColor: tab == value
                        ? selectedSurface
                        : Colors.transparent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                  child: Text(
                    value == .captures
                        ? '${value.label} (${meeting.captures.length})'
                        : value.label,
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        const Divider(height: 1),
        Expanded(
          child: IndexedStack(
            index: tab.index,
            children: [
              SummaryPane(
                meeting: meeting,
                folder: model.repository.folder(meeting),
                onChanged: (value) =>
                    model.safely(() => model.updateSummary(meeting, value)),
                onSeek: seek,
                onAdopt: widget.onAdopt,
                onEditCaption: widget.onEditCaption,
                onRemoveCapture: (capture) =>
                    model.safely(() => model.removeCapture(meeting, capture)),
              ),
              TranscriptPane(
                meeting: meeting,
                onSeek: seek,
                onEditSpeaker: widget.onEditSpeaker,
                onEditText: widget.onEditText,
                busy: model.busy,
                onDetectSpeakers: (count) =>
                    model.safely(() => detectSpeakers(count)),
                onRenameSpeaker: widget.onRenameSpeaker,
              ),
              NotesPane(
                meeting: meeting,
                markerStart: model.markerStart(meeting),
                onToggleMarker: () => model.toggleMarker(meeting),
                onChanged: (value) =>
                    model.safely(() => model.updateNotes(meeting, value)),
                position: () =>
                    widget.player?.state.position.inMilliseconds ?? 0,
              ),
              CapturesPane(
                meeting: meeting,
                folder: model.repository.folder(meeting),
                onSeek: seek,
                onEditCaption: widget.onEditCaption,
                onRemove: (capture) =>
                    model.safely(() => model.removeCapture(meeting, capture)),
              ),
            ],
          ),
        ),
      ],
    );
    final replay = ReplayPane(
      key: readerKey,
      meeting: meeting,
      player: widget.player,
      video: widget.video,
      busy: model.busy,
      onSeek: seek,
      onCapture: () => model.safely(
        () => model.addCapture(
          meeting,
          widget.player?.state.position.inMilliseconds ?? 0,
        ),
      ),
      onExportAudio: widget.onExportAudio,
      onOpenFolder: widget.onOpenFolder,
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
          onBack: widget.onBack,
          onRename: widget.onRename,
          onDelete: widget.onDelete,
          onImport: widget.onImport,
          onAnalyze: () => model.safely(() => model.analyze(meeting)),
          onExport: widget.onExport,
          onCancel: model.cancel,
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            const Expanded(
              child: Text(
                'VOTRE ESPACE DE TRAVAIL',
                style: TextStyle(
                  color: muted,
                  fontSize: 10,
                  letterSpacing: 1.2,
                ),
              ),
            ),
            if (hasMedia)
              TextButton.icon(
                key: const ValueKey('toggle-reader'),
                onPressed: () => setState(() => readerVisible = !readerVisible),
                icon: Icon(
                  showReader
                      ? Icons.chrome_reader_mode_outlined
                      : Icons.play_circle_outline,
                  size: 16,
                ),
                label: Text(
                  showReader
                      ? (widget.wide
                            ? 'Masquer le lecteur'
                            : 'Revenir au document')
                      : 'Ouvrir le lecteur',
                  style: const TextStyle(fontSize: 12),
                ),
              )
            else
              TextButton.icon(
                key: const ValueKey('open-meeting-folder'),
                onPressed: widget.onOpenFolder,
                icon: const Icon(Icons.folder_open, size: 16),
                label: const Text(
                  'Dossier local',
                  style: TextStyle(fontSize: 12),
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              if (!widget.wide || !hasMedia) {
                return IndexedStack(
                  index: showReader ? 1 : 0,
                  children: [document, replay],
                );
              }
              final readerWidth = (constraints.maxWidth * readerFraction).clamp(
                300.0,
                constraints.maxWidth - 330,
              );
              return Row(
                crossAxisAlignment: .stretch,
                children: [
                  Expanded(child: document),
                  if (showReader)
                    Semantics(
                      label: 'Largeur du lecteur',
                      child: MouseRegion(
                        cursor: SystemMouseCursors.resizeColumn,
                        child: GestureDetector(
                          key: const ValueKey('reader-divider'),
                          behavior: HitTestBehavior.opaque,
                          onHorizontalDragUpdate: (event) => setState(
                            () => readerFraction =
                                ((readerWidth - event.delta.dx) /
                                        constraints.maxWidth)
                                    .clamp(.25, .65),
                          ),
                          child: const SizedBox(
                            width: 24,
                            child: Center(
                              child: SizedBox(
                                width: 1,
                                child: ColoredBox(
                                  color: line,
                                  child: SizedBox.expand(),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  // Keep the reader mounted when hidden so audio mode and playback survive.
                  Offstage(
                    offstage: !showReader,
                    child: SizedBox(width: readerWidth, child: replay),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}
