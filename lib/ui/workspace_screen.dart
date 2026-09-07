import 'dart:async';
import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

import '../data/meeting_repository.dart';
import '../models/meeting.dart';
import '../services/local_engine.dart';
import '../services/local_files.dart';
import 'dialogs/engine_settings_dialog.dart';
import 'dialogs/meeting_dialogs.dart';
import 'dialogs/obs_guide_dialog.dart';
import 'library/library_view.dart';
import 'library/meeting_sidebar.dart';
import 'meeting/meeting_view.dart';
import 'workspace_view_model.dart';

class WorkspaceScreen extends StatefulWidget {
  const WorkspaceScreen({super.key, required this.root});
  final Directory root;

  @override
  State<WorkspaceScreen> createState() => _WorkspaceScreenState();
}

class _WorkspaceScreenState extends State<WorkspaceScreen> {
  late final repository = MeetingRepository(
    Directory('${widget.root.path}/.local/meetings'),
  );
  late final model = WorkspaceViewModel(
    repository: repository,
    engine: LocalEngine(widget.root, repository),
  );
  Player? player;
  VideoController? video;
  StreamSubscription<String>? playerErrors;
  StreamSubscription<Duration>? playerDuration;
  int selectionRevision = 0;

  @override
  void initState() {
    super.initState();
    model.onMessage = message;
    unawaited(model.initialize());
  }

  void message(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(text),
        duration: const Duration(seconds: 6),
        showCloseIcon: true,
      ),
    );
  }

  Future<void> selectMeeting(Meeting? meeting) async {
    final revision = ++selectionRevision;
    await player?.pause();
    if (!mounted || revision != selectionRevision) return;
    model.select(meeting);
    if (meeting == null || meeting.media.isEmpty) return;
    player ??= Player();
    video ??= VideoController(player!);
    playerErrors ??= player!.stream.error.listen(message);
    playerDuration ??= player!.stream.duration.listen((_) {
      if (mounted) setState(() {});
    });
    await player!.open(Media(repository.mediaPath(meeting)), play: false);
    if (!mounted || revision != selectionRevision) return;
    await player!.setAudioTrack(
      AudioTrack('${meeting.audioTrack + 1}', null, null),
    );
    if (mounted) setState(() {});
  }

  Future<void> createMeeting() async =>
      selectMeeting(await model.createMeeting());

  Future<void> seek(int position) async {
    await player?.seek(Duration(milliseconds: position));
    await player?.play();
  }

  Future<void> editText(
    String title,
    String initial,
    Future<void> Function(String) apply, {
    bool multiline = false,
  }) async {
    final value = await showDialog<String>(
      context: context,
      builder: (_) =>
          EditTextDialog(title: title, initial: initial, multiline: multiline),
    );
    if (value != null && mounted) await model.safely(() => apply(value));
  }

  Future<void> deleteMeeting(Meeting meeting) async {
    if (model.busy) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => ConfirmMeetingDialog(
        title: 'Supprimer ce meeting ?',
        acceptLabel: 'Supprimer',
        destructive: true,
        message:
            '« ${meeting.title} » sera retiré de la bibliothèque.\n\n'
            "Une copie reste dans la corbeille locale de Memora. Votre fichier OBS d'origine est conservé.",
      ),
    );
    if (confirmed != true || !mounted || model.busy) return;
    if (model.selected == meeting) {
      await selectMeeting(null);
      await player?.stop();
    }
    await model.remove(meeting);
    if (!mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Meeting supprimé de la bibliothèque.'),
        duration: const Duration(seconds: 10),
        action: SnackBarAction(
          label: 'Annuler',
          onPressed: () => model.safely(() async {
            await model.restore(meeting);
            if (mounted) await selectMeeting(meeting);
          }),
        ),
      ),
    );
  }

  Future<void> importRecording() async {
    if (model.busy) return;
    final target = model.selected;
    await model.runJob(target, "Import de l'enregistrement", () async {
      final file = await openFile(
        acceptedTypeGroups: [
          const XTypeGroup(
            label: 'Enregistrement',
            extensions: [
              'mkv',
              'mp4',
              'webm',
              'mov',
              'avi',
              'mp3',
              'wav',
              'm4a',
              'flac',
              'ogg',
            ],
          ),
        ],
      );
      if (file == null || !mounted) return;
      model.engine.cancelled = false;
      await model.engine.loadConfig();
      if (model.engine.config['ffprobe'] == null) {
        message('Installez les moteurs avec scripts/setup.ps1.');
        return;
      }
      final info = await model.engine.probe(file.path);
      final tracks = (info['streams'] as List)
          .where((s) => (s as Map)['codec_type'] == 'audio')
          .map((s) => Map<String, dynamic>.from(s as Map))
          .toList();
      if (tracks.isEmpty) {
        throw Exception('Cet enregistrement ne contient aucune piste audio.');
      }
      if (!mounted) return;
      final track = tracks.length == 1
          ? 0
          : await showDialog<int>(
              context: context,
              builder: (_) => AudioTrackDialog(tracks: tracks),
            );
      if (track == null || !mounted) return;
      final meeting = await model.importRecording(
        target: target,
        path: file.path,
        fileName: file.name,
        track: track,
        info: info,
      );
      if (!mounted) return;
      await selectMeeting(meeting);
      message('Enregistrement copié dans votre bibliothèque. Prêt à analyser.');
    });
  }

  Future<void> exportMeeting(Meeting meeting) async {
    if (model.busy) return;
    final dir = await getDirectoryPath(confirmButtonText: 'Exporter ici');
    if (dir == null || !mounted || model.busy) return;
    final output = await model.export(meeting, dir);
    message('Export disponible : $output');
    await openFolder(output);
  }

  Future<void> exportAudio(Meeting meeting) async {
    if (model.busy) return;
    final location = await getSaveLocation(
      suggestedName: 'meeting-${meeting.id}.m4a',
      acceptedTypeGroups: [
        const XTypeGroup(label: 'Audio M4A', extensions: ['m4a']),
      ],
    );
    if (location == null || !mounted || model.busy) return;
    await model.exportAudio(meeting, location.path);
    message('Audio exporté.');
  }

  Future<void> adoptSummary(Meeting meeting) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => const ConfirmMeetingDialog(
        title: 'Utiliser le dernier résumé généré ?',
        acceptLabel: 'Utiliser',
        message: 'La version actuellement éditée sera conservée dans summary.previous.md.',
      ),
    );
    if (confirmed == true && mounted) await model.adoptSummary(meeting);
  }

  void guide() => showDialog<void>(
    context: context,
    builder: (_) => const ObsGuideDialog(),
  );
  void settings() => showDialog<void>(
    context: context,
    builder: (_) => EngineSettingsDialog(model: model),
  );

  @override
  void dispose() {
    playerErrors?.cancel();
    playerDuration?.cancel();
    player?.dispose();
    model.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: ListenableBuilder(
      listenable: model,
      builder: (context, _) => LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 1100;
          final selected = model.selected;
          return Row(
            children: [
              MeetingSidebar(
                compact: compact,
                meetings: model.meetings,
                selected: selected,
                onSelect: (meeting) =>
                    model.safely(() => selectMeeting(meeting)),
                onCreate: () => model.safely(createMeeting),
                onSettings: settings,
                onGuide: guide,
              ),
              Expanded(
                child: Padding(
                  padding: EdgeInsets.all(compact ? 18 : 24),
                  child: model.loading
                      ? const Center(child: CircularProgressIndicator())
                      : selected == null
                      ? LibraryView(
                          meetings: model.meetings,
                          search: model.search,
                          onSearch: model.searchMeetings,
                          busy: model.busy,
                          onCreate: () => model.safely(createMeeting),
                          onImport: () => model.safely(importRecording),
                          onGuide: guide,
                          onSelect: (meeting) =>
                              model.safely(() => selectMeeting(meeting)),
                          onDelete: (meeting) =>
                              model.safely(() => deleteMeeting(meeting)),
                        )
                      : MeetingView(
                          key: ValueKey(selected.id),
                          meeting: selected,
                          model: model,
                          wide: constraints.maxWidth >= 1100,
                          player: player,
                          video: video,
                          onBack: () => model.safely(() => selectMeeting(null)),
                          onRename: () => editText(
                            'Nom du meeting',
                            selected.title,
                            (value) => model.rename(selected, value),
                          ),
                          onDelete: () =>
                              model.safely(() => deleteMeeting(selected)),
                          onImport: () => model.safely(importRecording),
                          onExport: () =>
                              model.safely(() => exportMeeting(selected)),
                          onExportAudio: () =>
                              model.safely(() => exportAudio(selected)),
                          onOpenFolder: () => model.safely(
                            () => openFolder(repository.folder(selected)),
                          ),
                          onAdopt: () =>
                              model.safely(() => adoptSummary(selected)),
                          onSeek: (position) =>
                              model.safely(() => seek(position)),
                          onEditSpeaker: (segment) => editText(
                            'Intervenant de ce passage',
                            segment.speaker,
                            (value) =>
                                model.updateSpeaker(selected, segment, value),
                          ),
                          onEditText: (segment) => editText(
                            'Corriger la transcription',
                            segment.text,
                            (value) => model.updateTranscript(
                              selected,
                              segment,
                              value,
                            ),
                            multiline: true,
                          ),
                          onEditCaption: (capture) => editText(
                            'Légende',
                            capture.caption,
                            (value) =>
                                model.updateCaption(selected, capture, value),
                          ),
                        ),
                ),
              ),
            ],
          );
        },
      ),
    ),
  );
}
