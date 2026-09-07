import 'dart:async';
import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

import 'engine.dart';
import 'meeting.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();
  runApp(const MemoraApp());
}

const ink = Color(0xffededee);
const muted = Color(0xff96969f);
const accent = Color(0xffc4b5fd);
const panel = Color(0xff19191c);
const line = Color(0xff2b2b30);

class MemoraApp extends StatelessWidget {
  const MemoraApp({super.key, this.root});
  final Directory? root;
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Memora',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      brightness: Brightness.dark,
      useMaterial3: true,
      fontFamily: 'Segoe UI',
      scaffoldBackgroundColor: const Color(0xff141416),
      splashFactory: NoSplash.splashFactory,
      colorScheme:
          ColorScheme.fromSeed(
            seedColor: accent,
            brightness: Brightness.dark,
          ).copyWith(
            primary: accent,
            onPrimary: const Color(0xff18181b),
            surface: panel,
            onSurface: ink,
            outline: line,
          ),
      dividerColor: line,
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: ink),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(foregroundColor: muted),
      ),
      tabBarTheme: const TabBarThemeData(
        labelColor: ink,
        unselectedLabelColor: muted,
        indicatorColor: ink,
        dividerColor: line,
        labelStyle: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        unselectedLabelStyle: TextStyle(fontSize: 13),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: panel,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: const BorderSide(color: line),
        ),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: panel,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: const BorderSide(color: line),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xff141416),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: line),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: line),
        ),
        hintStyle: const TextStyle(color: muted),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: ink,
          foregroundColor: const Color(0xff18181b),
          textStyle: const TextStyle(
            fontFamily: 'Segoe UI',
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: ink,
          side: const BorderSide(color: line),
          textStyle: const TextStyle(fontFamily: 'Segoe UI', fontSize: 13),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
    ),
    home: Workspace(root: root ?? findProjectRoot()),
  );
}

class Workspace extends StatefulWidget {
  const Workspace({super.key, required this.root});
  final Directory root;
  @override
  State<Workspace> createState() => _WorkspaceState();
}

class _WorkspaceState extends State<Workspace> {
  late final Library library = Library(
    Directory('${widget.root.path}/.local/meetings'),
  );
  late final LocalEngine engine = LocalEngine(widget.root, library);
  List<Meeting> meetings = [];
  Meeting? selected;
  String? busyId;
  String search = '', transcriptSearch = '';
  bool loading = true,
      checking = false,
      editingSummary = false,
      audioOnly = false;
  String saveState = 'Enregistré localement';
  int saveRevision = 0;
  List<String> engineIssues = ['Vérification des moteurs…'];
  final notes = TextEditingController(), summary = TextEditingController();
  Player? player;
  VideoController? video;
  StreamSubscription<String>? playerErrors;
  StreamSubscription<Duration>? playerDuration;
  final markerStarts = <String, DateTime>{};
  DateTime? get markerStart => markerStarts[selected?.id];
  int selectionRevision = 0;
  Timer? clock;

  @override
  void initState() {
    super.initState();
    engine.onUpdate = () {
      if (mounted) {
        setState(() {});
      }
    };
    _load();
    clock = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && markerStart != null) {
        setState(() {});
      }
    });
  }

  Future<void> _load() async {
    try {
      final loaded = await library.load();
      if (mounted) {
        setState(() {
          meetings = loaded;
          loading = false;
        });
      }
      if (library.warnings.isNotEmpty) {
        message(library.warnings.join('\n'));
      }
      if (mounted) {
        await checkEngines();
      }
    } catch (e) {
      message(e.toString());
      if (mounted) {
        setState(() => loading = false);
      }
    }
  }

  void message(String text) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(text),
        duration: const Duration(seconds: 6),
        showCloseIcon: true,
      ),
    );
  }

  Future<void> safely(Future<void> Function() action) async {
    try {
      await action();
    } catch (e) {
      message(e.toString());
    }
  }

  Future<void> save(Meeting m) async {
    final revision = ++saveRevision;
    if (mounted) {
      setState(() => saveState = 'Enregistrement…');
    }
    try {
      await library.save(m);
      if (mounted && revision == saveRevision) {
        setState(() => saveState = 'Enregistré localement');
      }
    } catch (e) {
      if (mounted) {
        setState(() => saveState = 'Échec de sauvegarde');
      }
      message('Sauvegarde impossible : $e');
    }
  }

  Future<void> checkEngines({bool start = false}) async {
    setState(() => checking = true);
    try {
      if (start) {
        await engine.startServer();
      }
      final issues = await engine.check();
      if (mounted) {
        setState(() => engineIssues = issues);
      }
    } catch (e) {
      if (mounted) {
        setState(() => engineIssues = [e.toString()]);
      }
    } finally {
      if (mounted) {
        setState(() => checking = false);
      }
    }
  }

  Future<void> selectMeeting(Meeting? m) async {
    final revision = ++selectionRevision;
    await player?.pause();
    if (!mounted || revision != selectionRevision) {
      return;
    }
    setState(() {
      selected = m;
      notes.text = m?.notes ?? '';
      summary.text = m?.summary ?? '';
      editingSummary = false;
      transcriptSearch = '';
      audioOnly = false;
    });
    if (m != null && m.media.isNotEmpty) {
      player ??= Player();
      video ??= VideoController(player!);
      playerErrors ??= player!.stream.error.listen(message);
      playerDuration ??= player!.stream.duration.listen((_) {
        if (mounted) {
          setState(() {});
        }
      });
      await player!.open(Media(library.mediaPath(m)), play: false);
      if (!mounted || revision != selectionRevision) return;
      await player!.setAudioTrack(
        AudioTrack('${m.audioTrack + 1}', null, null),
      );
      if (mounted) {
        setState(() {});
      }
    }
  }

  Future<void> createMeeting() async {
    final now = DateTime.now();
    final m = Meeting(
      '${now.microsecondsSinceEpoch}',
      'Réunion du ${now.day}/${now.month}',
      now,
    );
    await library.save(m);
    setState(() => meetings.insert(0, m));
    await selectMeeting(m);
  }

  Future<void> deleteMeeting(Meeting m) async {
    if (busyId != null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Supprimer ce meeting ?'),
        content: SizedBox(
          width: 420,
          child: Text(
            '« ${m.title} » sera retiré de la bibliothèque.\n\n'
            'Une copie reste dans la corbeille locale de Memora. '
            'Votre fichier OBS d’origine est conservé.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            key: const ValueKey('confirm-delete'),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xffb83b46),
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted || busyId != null) return;
    if (selected == m) {
      await selectMeeting(null);
      await player?.stop();
    }
    await library.remove(m);
    if (!mounted) return;
    setState(() => meetings.remove(m));
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Meeting supprimé de la bibliothèque.'),
        duration: const Duration(seconds: 10),
        action: SnackBarAction(
          label: 'Annuler',
          onPressed: () => safely(() async {
            await library.restore(m);
            if (!mounted) return;
            setState(() {
              meetings.add(m);
              meetings.sort((a, b) => b.created.compareTo(a.created));
            });
            await selectMeeting(m);
          }),
        ),
      ),
    );
  }

  Widget deleteButton(Meeting m) => IconButton(
    key: ValueKey('delete-${m.id}'),
    tooltip: busyId == null ? 'Supprimer le meeting' : 'Traitement en cours',
    onPressed: busyId == null ? () => safely(() => deleteMeeting(m)) : null,
    icon: const Icon(Icons.delete_outline_rounded, size: 18),
  );

  Future<void> importRecording() async {
    if (busyId != null) {
      return;
    }
    final intendedMeeting = selected;
    setState(() => busyId = intendedMeeting?.id ?? 'import');
    try {
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
      if (file == null || !mounted) {
        return;
      }
      engine.cancelled = false;
      await engine.loadConfig();
      if (engine.config['ffprobe'] == null) {
        message('Installez les moteurs avec scripts/setup.ps1.');
        return;
      }
      final info = await engine.probe(file.path);
      final tracks = (info['streams'] as List)
          .where((s) => (s as Map)['codec_type'] == 'audio')
          .toList();
      if (tracks.isEmpty) {
        throw Exception('Cet enregistrement ne contient aucune piste audio.');
      }
      var track = 0;
      if (tracks.length > 1 && mounted) {
        final choice = await showDialog<int>(
          context: context,
          builder: (ctx) => SimpleDialog(
            title: const Text('Quelle piste contient tout l’appel ?'),
            children: [
              const Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Choisissez le mix complet (micro + participants), généralement la piste 1 dans OBS. Une seule piste sera transcrite pour éviter les doublons.',
                ),
              ),
              for (var i = 0; i < tracks.length; i++)
                SimpleDialogOption(
                  onPressed: () => Navigator.pop(ctx, i),
                  child: Padding(
                    padding: const EdgeInsets.all(10),
                    child: Text(
                      'Piste ${i + 1} · ${(tracks[i] as Map)['codec_name']} · ${(tracks[i] as Map)['channels']} canaux',
                    ),
                  ),
                ),
            ],
          ),
        );
        if (choice == null) {
          return;
        }
        track = choice;
      }
      var m = intendedMeeting;
      if (m == null || m.media.isNotEmpty) {
        final now = DateTime.now();
        m = Meeting(
          '${now.microsecondsSinceEpoch}',
          file.name.replaceFirst(RegExp(r'\.[^.]+$'), ''),
          now,
        );
        meetings.insert(0, m);
      }
      final target = m;
      setState(() => busyId = target.id);
      try {
        await engine.importMedia(target, file.path, track, info);
        await selectMeeting(target);
        message(
          'Enregistrement copié dans votre bibliothèque. Prêt à analyser.',
        );
      } catch (e) {
        target.status = 'Erreur';
        target.error = e.toString();
        await library.save(target);
        rethrow;
      } finally {
        if (mounted) {
          setState(() => busyId = null);
        }
      }
    } finally {
      if (mounted) setState(() => busyId = null);
    }
  }

  Future<void> analyze(Meeting m) async {
    if (busyId != null) {
      return;
    }
    if (m.summary.isNotEmpty) {
      message(
        'Le nouveau résumé sera enregistré séparément. Votre version modifiée reste intacte.',
      );
    }
    setState(() {
      busyId = m.id;
      engine.detail = 'Préparation du résumé';
    });
    try {
      await engine.process(m, summaryOnly: m.segments.isNotEmpty);
      if (mounted && selected == m) {
        summary.text = m.summary;
      }
    } finally {
      if (mounted) {
        setState(() => busyId = null);
      }
    }
  }

  Future<void> editText(
    String title,
    String initial,
    Future<void> Function(String) apply, {
    bool multiline = false,
  }) async {
    final controller = TextEditingController(text: initial);
    final value = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: SizedBox(
          width: 500,
          child: TextField(
            autofocus: true,
            controller: controller,
            minLines: multiline ? 3 : 1,
            maxLines: multiline ? 8 : 1,
            onSubmitted: multiline ? null : (s) => Navigator.pop(ctx, s),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text),
            child: const Text('Enregistrer'),
          ),
        ],
      ),
    );
    // The dialog's exit animation still uses its controller for one frame.
    await Future<void>.delayed(const Duration(milliseconds: 250));
    controller.dispose();
    if (value != null) {
      await safely(() => apply(value));
    }
  }

  Future<void> seek(int ms) async {
    if (player == null) {
      return;
    }
    await player!.seek(Duration(milliseconds: ms));
    await player!.play();
  }

  void mark(Meeting m) {
    final ms = m.media.isNotEmpty
        ? player?.state.position.inMilliseconds ?? 0
        : markerStart == null
        ? 0
        : DateTime.now().difference(markerStart!).inMilliseconds;
    final text =
        '${notes.text}${notes.text.endsWith('\n') || notes.text.isEmpty ? '' : '\n'}[${timeLabel(ms)}] Moment important : ';
    notes.text = text;
    notes.selection = TextSelection.collapsed(offset: text.length);
    m.notes = text;
    save(m);
  }

  Future<void> exportMeeting(Meeting m) async {
    if (busyId != null) return;
    final dir = await getDirectoryPath(confirmButtonText: 'Exporter ici');
    if (dir == null || !mounted || busyId != null) {
      return;
    }
    setState(() => busyId = m.id);
    try {
      final output = await engine.export(m, dir);
      message('Export disponible : $output');
      await openFolder(output);
    } finally {
      if (mounted) setState(() => busyId = null);
    }
  }

  Future<void> exportAudio(Meeting m) async {
    if (busyId != null) return;
    final location = await getSaveLocation(
      suggestedName: 'meeting-${m.id}.m4a',
      acceptedTypeGroups: [
        const XTypeGroup(label: 'Audio M4A', extensions: ['m4a']),
      ],
    );
    if (location == null || !mounted || busyId != null) {
      return;
    }
    setState(() => busyId = m.id);
    try {
      await engine.exportAudio(m, location.path);
      message('Audio exporté.');
    } finally {
      if (mounted) {
        setState(() => busyId = null);
      }
    }
  }

  Future<void> addCapture(Meeting m) async {
    if (busyId != null || player == null) return;
    final time = player!.state.position.inMilliseconds;
    setState(() => busyId = m.id);
    try {
      engine.cancelled = false;
      await engine.loadConfig();
      await engine.capture(m, time, 'Capture ajoutée manuellement');
    } finally {
      if (mounted) setState(() => busyId = null);
    }
  }

  @override
  void dispose() {
    clock?.cancel();
    playerErrors?.cancel();
    playerDuration?.cancel();
    engine.dispose();
    player?.dispose();
    notes.dispose();
    summary.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: LayoutBuilder(
      builder: (context, box) {
        final compact = box.maxWidth < 900;
        return Row(
          children: [
            sidebar(compact),
            Expanded(
              child: Padding(
                padding: EdgeInsets.all(compact ? 18 : 32),
                child: loading
                    ? const Center(child: CircularProgressIndicator())
                    : selected == null
                    ? home()
                    : meetingView(selected!, box.maxWidth > 1250),
              ),
            ),
          ],
        );
      },
    ),
  );

  Widget sidebar(bool compact) => Container(
    width: compact ? 76 : 244,
    padding: EdgeInsets.symmetric(horizontal: compact ? 10 : 18, vertical: 20),
    decoration: const BoxDecoration(
      color: Color(0xff101012),
      border: Border(right: BorderSide(color: line)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: compact
              ? MainAxisAlignment.center
              : MainAxisAlignment.start,
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
                  fontWeight: FontWeight.w700,
                  letterSpacing: -1,
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 26),
        nav(
          Icons.space_dashboard_outlined,
          'Bibliothèque',
          selected == null,
          () => safely(() => selectMeeting(null)),
          compact,
        ),
        const SizedBox(height: 12),
        if (!compact)
          TextField(
            key: const ValueKey('meeting-search'),
            onChanged: (s) => setState(() => search = s),
            decoration: const InputDecoration(
              hintText: 'Rechercher un meeting',
              prefixIcon: Icon(Icons.search, size: 18),
              isDense: true,
            ),
          ),
        const SizedBox(height: 26),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            if (!compact)
              const Text(
                'MEETINGS',
                style: TextStyle(
                  fontSize: 10,
                  letterSpacing: 1.8,
                  color: muted,
                  fontWeight: FontWeight.w700,
                ),
              ),
            IconButton(
              key: const ValueKey('new-meeting'),
              tooltip: 'Préparer un meeting',
              onPressed: () => safely(createMeeting),
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
                  child: nav(
                    m.media.isEmpty
                        ? Icons.edit_note_rounded
                        : Icons.video_library_outlined,
                    m.title,
                    m == selected,
                    () => safely(() => selectMeeting(m)),
                    compact,
                    subtitle:
                        '${m.created.day}/${m.created.month} · ${m.status}',
                  ),
                ),
            ],
          ),
        ),
        const Divider(),
        nav(
          Icons.tune_rounded,
          'Moteurs locaux',
          false,
          () => settings(),
          compact,
        ),
        nav(
          Icons.help_outline_rounded,
          'Guide OBS',
          false,
          () => guide(),
          compact,
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.lock_outline, color: Color(0xff83c8a7), size: 14),
            if (!compact) ...[
              const SizedBox(width: 8),
              const Flexible(
                child: Text(
                  'Stockage local',
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: muted, fontSize: 11),
                ),
              ),
            ],
          ],
        ),
      ],
    ),
  );

  Widget nav(
    IconData icon,
    String title,
    bool active,
    VoidCallback action,
    bool compact, {
    String? subtitle,
  }) => Material(
    color: active ? const Color(0xff26262b) : Colors.transparent,
    borderRadius: BorderRadius.circular(8),
    child: InkWell(
      onTap: action,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 13),
        child: Row(
          children: [
            Tooltip(
              message: title,
              child: Icon(icon, size: 20, color: active ? accent : muted),
            ),
            if (!compact) ...[
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        color: active ? ink : muted,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (subtitle != null)
                      Text(
                        subtitle,
                        style: const TextStyle(color: muted, fontSize: 10),
                      ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    ),
  );

  Widget box(Widget child, {EdgeInsets padding = const EdgeInsets.all(24)}) =>
      Container(
        padding: padding,
        decoration: BoxDecoration(
          color: panel,
          border: Border.all(color: line),
          borderRadius: BorderRadius.circular(12),
        ),
        child: child,
      );
  Widget tag(String text, {Color color = accent}) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(
      color: color.withValues(alpha: .1),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Text(
      text,
      style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600),
    ),
  );

  Widget home() {
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
          'Vos conversations,\nl’esprit libre.',
          style: TextStyle(
            fontSize: 38,
            height: 1.15,
            fontWeight: FontWeight.w600,
            letterSpacing: -1.4,
          ),
        ),
        const SizedBox(height: 14),
        const Text(
          'Un endroit pour vos notes, vos enregistrements et ce qu’il faut retenir.',
          style: TextStyle(color: muted, fontSize: 14, height: 1.6),
        ),
        const SizedBox(height: 26),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            FilledButton.icon(
              key: const ValueKey('prepare-home'),
              onPressed: () => safely(createMeeting),
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text('Préparer mon meeting'),
            ),
            OutlinedButton.icon(
              key: const ValueKey('import-home'),
              onPressed: busyId == null ? () => safely(importRecording) : null,
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
                onPressed: guide,
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
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(width: 10),
            tag('${visible.length}', color: muted),
            const Spacer(),
            const Text(
              'Les plus récents d’abord',
              style: TextStyle(color: muted, fontSize: 11),
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (visible.isEmpty)
          box(
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 28),
              child: Column(
                children: [
                  const Icon(Icons.article_outlined, color: muted, size: 30),
                  const SizedBox(height: 14),
                  Text(
                    search.isEmpty
                        ? 'Votre prochain meeting commence ici.'
                        : 'Aucun résultat pour cette recherche.',
                    style: const TextStyle(fontWeight: FontWeight.w500),
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
              onTap: () => safely(() => selectMeeting(m)),
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
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            m.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
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
                    tag(
                      m.status,
                      color: m.status == 'Prêt'
                          ? const Color(0xff9bc5ac)
                          : muted,
                    ),
                    const SizedBox(width: 16),
                    deleteButton(m),
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

  Widget meetingView(Meeting m, bool wide) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: [
          TextButton.icon(
            onPressed: () => safely(() => selectMeeting(null)),
            icon: const Icon(Icons.arrow_back, size: 16),
            label: const Text('Bibliothèque'),
          ),
          const Spacer(),
          tag(m.status),
          const SizedBox(width: 10),
          const Icon(Icons.lock_outline, color: muted, size: 14),
        ],
      ),
      const SizedBox(height: 18),
      Row(
        children: [
          Expanded(
            child: Text(
              m.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 25,
                fontWeight: FontWeight.w600,
                letterSpacing: -.7,
              ),
            ),
          ),
          IconButton(
            tooltip: 'Renommer le meeting',
            onPressed: () => editText('Nom du meeting', m.title, (s) async {
              if (s.trim().isNotEmpty) {
                m.title = s.trim();
                await save(m);
              }
            }),
            icon: const Icon(Icons.edit_outlined, size: 18),
          ),
          deleteButton(m),
        ],
      ),
      const SizedBox(height: 8),
      Text(
        '${m.created.day}/${m.created.month}/${m.created.year}  ·  ${m.duration == 0 ? 'Prêt à prendre des notes' : timeLabel(m.duration)}  ·  $saveState',
        style: const TextStyle(color: muted, fontSize: 12),
      ),
      const SizedBox(height: 20),
      Wrap(
        spacing: 10,
        runSpacing: 8,
        children: [
          if (m.media.isEmpty)
            FilledButton.icon(
              onPressed: busyId == null ? () => safely(importRecording) : null,
              icon: const Icon(Icons.attach_file, size: 18),
              label: const Text('Rattacher l’enregistrement OBS'),
            ),
          if (m.media.isNotEmpty)
            FilledButton.icon(
              key: const ValueKey('analyze'),
              onPressed: busyId == null ? () => safely(() => analyze(m)) : null,
              icon: const Icon(Icons.auto_awesome, size: 18),
              label: Text(
                m.segments.isEmpty
                    ? 'Transcrire et résumer'
                    : 'Générer un nouveau résumé',
              ),
            ),
          OutlinedButton.icon(
            onPressed: busyId == null
                ? () => safely(() => exportMeeting(m))
                : null,
            icon: const Icon(Icons.ios_share, size: 17),
            label: const Text('Exporter'),
          ),
          if (busyId == m.id)
            TextButton.icon(
              onPressed: engine.cancel,
              icon: const Icon(Icons.stop_circle_outlined, size: 18),
              label: const Text('Arrêter le traitement'),
            ),
        ],
      ),
      if (busyId == m.id)
        Padding(
          padding: const EdgeInsets.only(top: 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const LinearProgressIndicator(minHeight: 3),
              const SizedBox(height: 10),
              Text(
                '${m.status} · ${engine.detail}',
                style: const TextStyle(color: accent, fontSize: 12),
              ),
            ],
          ),
        ),
      if (m.error.isNotEmpty)
        Padding(
          padding: const EdgeInsets.only(top: 12),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xff38282b),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.info_outline,
                  color: Color(0xffffb4ab),
                  size: 18,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: SelectableText(
                    m.error,
                    maxLines: 3,
                    style: const TextStyle(
                      color: Color(0xffffb4ab),
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      const SizedBox(height: 22),
      Expanded(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: DefaultTabController(
                key: ValueKey('${m.id}-$wide'),
                length: wide ? 3 : 4,
                initialIndex: m.media.isEmpty ? 2 : 0,
                child: box(
                  Column(
                    children: [
                      TabBar(
                        isScrollable: true,
                        tabAlignment: TabAlignment.start,
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
                            summaryView(m),
                            transcriptView(m),
                            notesView(m),
                            if (!wide) replay(m),
                          ],
                        ),
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.all(16),
                ),
              ),
            ),
            if (wide) ...[
              const SizedBox(width: 20),
              SizedBox(width: 360, child: replay(m)),
            ],
          ],
        ),
      ),
    ],
  );

  Widget summaryView(Meeting m) {
    if (m.summary.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(25),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.auto_awesome_outlined, size: 40, color: accent),
              const SizedBox(height: 18),
              const Text(
                'L’essentiel, après la conversation.',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 19),
              ),
              const SizedBox(height: 12),
              Text(
                m.media.isEmpty
                    ? 'Rattachez votre enregistrement, puis lancez l’analyse.\nVos notes sont déjà disponibles dans « Mes notes ».'
                    : 'Lancez « Transcrire et résumer » pour retrouver\nles sujets, les décisions et les actions.',
                textAlign: TextAlign.center,
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
                summary.text = m.summary;
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
              onSelected: (_) => safely(() async {
                final file = File('${library.folder(m)}/summary.generated.md');
                if (!await file.exists()) {
                  return;
                }
                final fresh = await file.readAsString();
                if (!mounted) {
                  return;
                }
                final accept = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Utiliser le dernier résumé généré ?'),
                    content: const Text(
                      'La version actuellement éditée sera conservée dans summary.previous.md.',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: const Text('Annuler'),
                      ),
                      FilledButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        child: const Text('Utiliser'),
                      ),
                    ],
                  ),
                );
                if (accept == true) {
                  await File('${library.folder(m)}/summary.previous.md')
                      .writeAsString(m.summary, flush: true);
                  m.summary = fresh;
                  summary.text = fresh;
                  await save(m);
                }
              }),
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
                  textAlignVertical: TextAlignVertical.top,
                  style: const TextStyle(height: 1.8, fontSize: 14),
                  onChanged: (s) {
                    m.summary = s;
                    save(m);
                  },
                )
              : SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        MarkdownBody(
                          data: m.summary,
                          selectable: true,
                          styleSheet: MarkdownStyleSheet(
                            p: const TextStyle(
                              height: 1.8,
                              color: ink,
                              fontSize: 14,
                            ),
                            h2: const TextStyle(
                              fontSize: 21,
                              fontWeight: FontWeight.w600,
                              height: 2,
                            ),
                            a: const TextStyle(color: accent),
                          ),
                          imageBuilder: (_, _, _) => const SizedBox.shrink(),
                          onTapLink: (_, href, _) {
                            final ms = replayTimestamp(href);
                            if (ms != null) safely(() => seek(ms));
                          },
                        ),
                        if (m.captures.isNotEmpty) ...[
                          const SizedBox(height: 24),
                          const Text(
                            'Repères visuels',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Images proposées autour des passages clés. Ajustez-les au besoin.',
                            style: TextStyle(color: muted, fontSize: 12),
                          ),
                          const SizedBox(height: 16),
                        ],
                        for (final c in m.captures)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 20),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: InkWell(
                                    onTap: () => safely(() => seek(c.time)),
                                    child: Image.file(
                                      File('${library.folder(m)}/${c.file}'),
                                      fit: BoxFit.fitWidth,
                                      errorBuilder: (_, _, _) =>
                                          const Text('Image introuvable'),
                                    ),
                                  ),
                                ),
                                Row(
                                  children: [
                                    TextButton(
                                      onPressed: () =>
                                          safely(() => seek(c.time)),
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
                                      onPressed: () => editText(
                                        'Légende',
                                        c.caption,
                                        (s) async {
                                          c.caption = s;
                                          await save(m);
                                        },
                                      ),
                                      icon: const Icon(
                                        Icons.edit_outlined,
                                        size: 16,
                                      ),
                                    ),
                                    IconButton(
                                      tooltip: 'Retirer du résumé',
                                      onPressed: () {
                                        m.captures.remove(c);
                                        save(m);
                                      },
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

  Widget transcriptView(Meeting m) {
    final visible = m.segments
        .where(
          (s) => '${s.speaker} ${s.text}'.toLowerCase().contains(
            transcriptSearch.toLowerCase(),
          ),
        )
        .toList();
    return Column(
      children: [
        const SizedBox(height: 14),
        TextField(
          key: const ValueKey('transcript-search'),
          onChanged: (s) => setState(() => transcriptSearch = s),
          decoration: const InputDecoration(
            prefixIcon: Icon(Icons.search, size: 18),
            hintText: 'Rechercher dans la conversation',
            isDense: true,
          ),
        ),
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 12),
          child: Text(
            'Les noms sont attribués manuellement dans cette version. Cliquez sur une étiquette pour identifier la voix.',
            style: TextStyle(color: muted, fontSize: 11, height: 1.5),
          ),
        ),
        Expanded(
          child: m.segments.isEmpty
              ? const Center(
                  child: Text(
                    'La transcription apparaîtra après l’analyse.',
                    style: TextStyle(color: muted),
                  ),
                )
              : ListView.builder(
                  itemCount: visible.length,
                  itemBuilder: (_, i) {
                    final s = visible[i];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              TextButton(
                                onPressed: () => safely(() => seek(s.start)),
                                child: Text(
                                  timeLabel(s.start),
                                  style: const TextStyle(fontSize: 12),
                                ),
                              ),
                              TextButton.icon(
                                onPressed: () => editText(
                                  'Intervenant de ce passage',
                                  s.speaker,
                                  (value) async {
                                    s.speaker = value.trim();
                                    await save(m);
                                  },
                                ),
                                icon: const Icon(
                                  Icons.person_outline,
                                  size: 15,
                                ),
                                label: Text(
                                  s.speaker.isEmpty
                                      ? 'Attribuer un nom'
                                      : s.speaker,
                                  style: const TextStyle(
                                    color: muted,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                              const Spacer(),
                              IconButton(
                                tooltip: 'Corriger ce passage',
                                onPressed: () => editText(
                                  'Corriger la transcription',
                                  s.text,
                                  (value) async {
                                    s.text = value;
                                    await save(m);
                                  },
                                  multiline: true,
                                ),
                                icon: const Icon(Icons.edit_outlined, size: 15),
                              ),
                            ],
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            child: SelectableText(
                              s.text,
                              style: const TextStyle(height: 1.8, fontSize: 14),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget notesView(Meeting m) => Padding(
    padding: const EdgeInsets.only(top: 14),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            if (m.media.isEmpty)
              TextButton.icon(
                onPressed: () => setState(() {
                  if (markerStarts.containsKey(m.id)) {
                    markerStarts.remove(m.id);
                  } else {
                    markerStarts[m.id] = DateTime.now();
                  }
                }),
                icon: Icon(
                  markerStart == null
                      ? Icons.timer_outlined
                      : Icons.stop_circle_outlined,
                  size: 18,
                ),
                label: Text(
                  markerStart == null
                      ? 'Démarrer le repère temps'
                      : timeLabel(
                          DateTime.now()
                              .difference(markerStart!)
                              .inMilliseconds,
                        ),
                ),
              ),
            TextButton.icon(
              key: const ValueKey('mark-moment'),
              onPressed: () => mark(m),
              icon: const Icon(Icons.bookmark_add_outlined, size: 18),
              label: const Text('Moment important'),
            ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Text(
            m.media.isEmpty
                ? 'OBS enregistre séparément. Démarrez le repère temps au même instant qu’OBS pour annoter vos notes.'
                : 'Vos notes personnelles restent intactes quand vous régénérez un résumé.',
            style: const TextStyle(color: muted, fontSize: 11, height: 1.5),
          ),
        ),
        Expanded(
          child: TextField(
            key: const ValueKey('notes-editor'),
            controller: notes,
            expands: true,
            maxLines: null,
            minLines: null,
            textAlignVertical: TextAlignVertical.top,
            style: const TextStyle(height: 1.9, fontSize: 15),
            decoration: const InputDecoration(
              hintText: 'Un ordre du jour, une idée, une question…\n\nCet espace est à vous.',
            ),
            onChanged: (s) {
              m.notes = s;
              save(m);
            },
          ),
        ),
      ],
    ),
  );

  Widget replay(Meeting m) => SingleChildScrollView(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        box(
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.play_circle_outline, color: accent, size: 19),
                  SizedBox(width: 9),
                  Expanded(
                    child: Text(
                      'Le fil de la conversation',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: AspectRatio(
                  aspectRatio: 16 / 10,
                  child: m.media.isEmpty || video == null
                      ? Container(
                          color: const Color(0xff12141b),
                          child: const Column(
                            mainAxisAlignment: MainAxisAlignment.center,
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
                      : audioOnly || !m.hasVideo
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
                      : Video(controller: video!, controls: NoVideoControls),
                ),
              ),
              if (m.media.isNotEmpty && player != null) ...[
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
                  mainAxisAlignment: MainAxisAlignment.center,
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
                if (m.hasVideo)
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: busyId == null
                          ? () => safely(() => addCapture(m))
                          : null,
                      icon: const Icon(
                        Icons.add_photo_alternate_outlined,
                        size: 18,
                      ),
                      label: const Text('Ajouter cette image'),
                    ),
                  ),
                TextButton.icon(
                  onPressed: busyId == null
                      ? () => safely(() => exportAudio(m))
                      : null,
                  icon: const Icon(Icons.file_download_outlined, size: 16),
                  label: const Text('Exporter l’audio'),
                ),
              ],
            ],
          ),
          padding: const EdgeInsets.all(20),
        ),
        const SizedBox(height: 16),
        box(
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              tag('SUR CET ORDINATEUR', color: const Color(0xff8ad3b1)),
              const SizedBox(height: 14),
              const Text(
                'Un espace privé, par défaut.',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 10),
              const Text(
                'Enregistrement original, notes et résultats sont conservés ensemble. Aucune réunion n’est envoyée à un service cloud.',
                style: TextStyle(color: muted, height: 1.7, fontSize: 12),
              ),
              const SizedBox(height: 8),
              TextButton(
                key: const ValueKey('open-meeting-folder'),
                onPressed: () => safely(() => openFolder(library.folder(m))),
                child: const Text(
                  'Ouvrir le dossier du meeting',
                  style: TextStyle(fontSize: 12),
                ),
              ),
            ],
          ),
          padding: const EdgeInsets.all(20),
        ),
      ],
    ),
  );

  void settings() => showDialog<void>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, refresh) => AlertDialog(
        title: const Text('Votre IA, sur votre ordinateur'),
        content: SizedBox(
          width: 560,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                engineIssues.isEmpty
                    ? 'Tous les moteurs sont prêts.'
                    : engineIssues.join('\n'),
                style: TextStyle(
                  color: engineIssues.isEmpty
                      ? const Color(0xff8ad3b1)
                      : accent,
                  height: 1.8,
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Transcription : Whisper large-v3-turbo\nRésumé : Qwen3 8B · Ollama local\nCalcul après l’appel · aucun compte requis',
                style: TextStyle(color: muted, height: 1.8),
              ),
              const SizedBox(height: 16),
              SelectableText(
                'Bibliothèque : ${library.root.path}\n\nInstallation initiale : scripts/setup.ps1',
                style: const TextStyle(color: muted, fontSize: 12),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: checking || busyId != null
                ? null
                : () async {
                    await checkEngines(start: true);
                    if (ctx.mounted) {
                      refresh(() {});
                    }
                  },
            child: const Text('Démarrer et vérifier'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Fermer'),
          ),
        ],
      ),
    ),
  );

  void guide() => showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Prêt pour votre prochain meeting'),
      content: const SizedBox(
        width: 600,
        child: SingleChildScrollView(
          child: Text(
            '1. Dans OBS, ajoutez une capture de fenêtre ou d’écran. Vérifiez que votre micro ET le son de l’appel font bouger les vumètres. Utilisez un casque.\n\n'
            '2. Enregistrez en MP4 hybride ou MKV avec une piste 1 contenant le mix complet. Faites un test de 30 secondes et réécoutez votre voix ainsi que le son de l’ordinateur.\n\n'
            '3. Préparez un meeting dans Memora et prenez vos notes. Le repère temps est manuel : lancez-le en même temps que l’enregistrement OBS.\n\n'
            '4. Après le meeting, arrêtez OBS, rattachez le fichier MP4 ou MKV dans Memora puis cliquez sur « Transcrire et résumer ».\n\n'
            '5. Relisez le résumé, corrigez les noms des passages et ajustez les captures. Cliquez sur un timestamp pour revoir la source.\n\n'
            'Cette version transcrit plusieurs voix, mais n’identifie pas automatiquement les intervenants. Les noms sont attribués manuellement. Les images sont proposées près des sujets importants, puis ajustables.',
            style: TextStyle(height: 1.7),
          ),
        ),
      ),
      actions: [
        FilledButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('C’est compris'),
        ),
      ],
    ),
  );
}
