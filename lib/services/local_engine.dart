import 'dart:convert';
import 'dart:io';
import 'dart:math';

import '../data/meeting_repository.dart';
import '../models/meeting.dart';
import '../models/meeting_status.dart';
import '../models/transcript.dart';
import '../models/summary.dart';
import '../models/speaker_turn.dart';
import '../utils/timestamps.dart';
import '../utils/frame_similarity.dart';
import 'ollama_client.dart';
import 'summary_checkpoint.dart';

class LocalEngine {
  LocalEngine(this.root, this.library);
  final Directory root;
  final MeetingRepository library;
  Map<String, dynamic> config = {};
  Process? _process;
  late final _ollama = OllamaClient(root, () => config);
  bool cancelled = false;
  String detail = '';
  void Function()? onUpdate;
  bool get hasDiarization => [
    'diarization',
    'speakerSegmentation',
    'speakerEmbedding',
  ].every((key) => File(config[key] as String? ?? '').existsSync());

  Future<void> loadConfig() async {
    final file = File('${root.path}/.runtime/runtime.json');
    if (await file.exists()) {
      config = jsonDecode(
        (await file.readAsString()).replaceFirst('\ufeff', ''),
      ) as Map<String, dynamic>;
    }
  }

  Future<List<String>> check() async {
    await loadConfig();
    final issues = <String>[];
    for (final key in ['ffmpeg', 'ffprobe', 'whisper', 'whisperModel']) {
      if (!File(config[key] as String? ?? '').existsSync()) {
        issues.add('$key manquant');
      }
    }
    if (issues.isNotEmpty) {
      return issues;
    }
    try {
      final tags = await _ollama.request(
        '/api/tags',
        timeout: const Duration(seconds: 4),
      );
      final names = (tags['models'] as List? ?? []).map(
        (v) => (v as Map)['name'],
      );
      if (!names.contains(config['summaryModel'])) {
        issues.add('Modèle de résumé à télécharger');
      }
    } catch (_) {
      issues.add('Moteur de résumé arrêté');
    }
    return issues;
  }

  Future<void> startServer() async {
    await loadConfig();
    guard();
    await _ollama.startServer();
  }

  void cancel() {
    cancelled = true;
    _process?.kill();
    _ollama.cancel();
  }

  void guard() {
    if (cancelled) {
      throw Exception('Traitement interrompu.');
    }
  }

  void dispose() {
    cancel();
    _ollama.dispose();
  }

  Future<String> run(
    String executable,
    List<String> args, {
    String? logPath,
  }) async {
    guard();
    final process = await Process.start(executable, args);
    _process = process;
    final stdoutFuture = process.stdout.transform(utf8.decoder).join();
    final stderrFuture = process.stderr
        .transform(const Utf8Decoder(allowMalformed: true))
        .join();
    try {
      final code = await process.exitCode;
      final out = await stdoutFuture;
      final err = await stderrFuture;
      if (logPath != null) {
        await File(logPath).writeAsString('$out\n$err', mode: FileMode.append);
      }
      guard();
      if (code != 0) {
        throw Exception(
          '${File(executable).uri.pathSegments.last} a échoué ($code). ${err.substring(max(0, err.length - 900))}',
        );
      }
      return out;
    } finally {
      if (identical(_process, process)) {
        _process = null;
      }
    }
  }

  Future<Map<String, dynamic>> probe(String path) async {
    await loadConfig();
    return jsonDecode(
      await run(config['ffprobe'] as String, [
        '-v',
        'error',
        '-show_streams',
        '-show_format',
        '-of',
        'json',
        path,
      ]),
    ) as Map<String, dynamic>;
  }

  Future<void> importMedia(
    Meeting m,
    String path,
    int track,
    Map<String, dynamic> info,
  ) async {
    cancelled = false;
    await library.save(m);
    m.status = .importing;
    onUpdate?.call();
    final extension = path.split('.').last.toLowerCase();
    if (!RegExp(r'^[a-z0-9]{1,8}$').hasMatch(extension)) {
      throw const FormatException('Extension non reconnue.');
    }
    final name = 'recording.$extension';
    final tmp = File('${library.folder(m)}/$name.partial');
    try {
      await File(path)
          .openRead()
          .map((chunk) {
            guard();
            return chunk;
          })
          .pipe(tmp.openWrite());
      guard();
      await tmp.rename('${library.folder(m)}/$name');
    } catch (_) {
      if (await tmp.exists()) {
        await tmp.delete();
      }
      rethrow;
    }
    m.media = name;
    m.audioTrack = track;
    m.hasVideo = (info['streams'] as List).any(
      (s) =>
          (s as Map)['codec_type'] == 'video' &&
          (s['disposition'] as Map?)?['attached_pic'] != 1,
    );
    m.duration =
        ((double.tryParse('${(info['format'] as Map)['duration']}') ?? 0) *
                1000)
            .round();
    m.status = .imported;
    m.error = '';
    await library.save(m);
  }

  Future<void> stage(Meeting m, MeetingStatus status, String message) async {
    guard();
    m.status = status;
    detail = message;
    onUpdate?.call();
    await library.save(m);
  }

  Future<void> prepareAudio(Meeting m) async {
    final dir = library.folder(m);
    if (m.audioExtracted && await File('$dir/audio.wav').exists()) return;
    await stage(m, .extracting, 'Préparation de la piste ${m.audioTrack + 1}');
    await run(config['ffmpeg'] as String, [
      '-y',
      '-v',
      'error',
      '-i',
      library.mediaPath(m),
      '-map',
      '0:a:${m.audioTrack}',
      '-vn',
      '-ar',
      '16000',
      '-ac',
      '1',
      '-c:a',
      'pcm_s16le',
      '-f',
      'wav',
      '$dir/audio.partial.wav',
    ], logPath: '$dir/processing.log');
    guard();
    await File('$dir/audio.partial.wav').rename('$dir/audio.wav');
    m.audioExtracted = true;
    await library.save(m);
  }

  Future<void> _identifySpeakers(Meeting m, int count) async {
    if (!hasDiarization) {
      throw StateError(
        'Installez les intervenants avec scripts/setup-diarization.ps1.',
      );
    }
    if (count < 0 || count > 20) {
      throw const FormatException('Nombre de voix invalide.');
    }
    await prepareAudio(m);
    await stage(
      m,
      .diarizing,
      'Séparation des voix sur cet ordinateur${count == 0 ? '' : ' · $count intervenants'}',
    );
    final dir = library.folder(m);
    final output = await run(config['diarization'] as String, [
      '--segmentation.pyannote-model=${config['speakerSegmentation']}',
      '--embedding.model=${config['speakerEmbedding']}',
      '--segmentation.num-threads=4',
      '--embedding.num-threads=4',
      if (count > 0)
        '--clustering.num-clusters=$count'
      else
        '--clustering.cluster-threshold=0.5',
      '$dir/audio.wav',
    ], logPath: '$dir/diarization.log');
    final turns = parseSpeakerTurns(output);
    guard();
    if (m.speakersDetected) {
      await File('$dir/speakers.previous.json').writeAsString(
        jsonEncode({
          'speakerNames': m.speakerNames,
          'segments': m.segments.map((s) => s.toJson()).toList(),
        }),
        flush: true,
      );
    }
    await File('$dir/diarization.txt.tmp').writeAsString(output, flush: true);
    await File('$dir/diarization.txt.tmp').rename('$dir/diarization.txt');
    guard();
    assignSpeakerTurns(m, turns);
    m.expectedSpeakers = count;
    m.speakerError = count > 0 && m.speakerNames.length != count
        ? '${m.speakerNames.length} groupes obtenus pour $count intervenants attendus. Vérifiez les voix : le modèle peut avoir fusionné des personnes.'
        : '';
    await library.save(m);
    onUpdate?.call();
  }

  Future<void> detectSpeakers(Meeting m, {int count = 0}) async {
    cancelled = false;
    final previousStatus = m.status;
    try {
      await loadConfig();
      if (m.segments.isEmpty) {
        throw StateError(
          'Transcrivez le meeting avant de détecter les intervenants.',
        );
      }
      await _identifySpeakers(m, count);
      await stage(m, previousStatus, '${m.speakerNames.length} voix détectées');
    } catch (e) {
      m.speakerError = cancelled
          ? 'Détection interrompue. Les attributions précédentes sont conservées.'
          : e.toString();
      m.status = previousStatus;
      await library.save(m);
      rethrow;
    } finally {
      onUpdate?.call();
    }
  }

  Future<void> process(
    Meeting m, {
    bool summaryOnly = false,
    bool regenerate = false,
  }) async {
    cancelled = false;
    m.error = '';
    final dir = library.folder(m);
    try {
      await loadConfig();
      if (!summaryOnly && m.segments.isEmpty) {
        await prepareAudio(m);
        await stage(
          m,
          .transcribing,
          'Whisper travaille sur cet ordinateur. Cela peut prendre quelques minutes.',
        );
        final args = [
          '-m',
          config['whisperModel'] as String,
          '-l',
          'fr',
          '-oj',
          '-of',
          '$dir/whisper',
          '-t',
          '12',
          '-bs',
          '1',
          '-bo',
          '1',
          '-f',
          '$dir/audio.wav',
        ];
        final vad = config['vadModel'] as String?;
        if (vad != null && File(vad).existsSync()) {
          args.addAll(['--vad', '-vm', vad]);
        }
        if (config['useGpu'] == false) {
          args.add('-ng');
        }
        try {
          await run(
            config['whisper'] as String,
            args,
            logPath: '$dir/processing.log',
          );
        } catch (_) {
          guard();
          if (args.contains('-ng')) {
            rethrow;
          }
          await stage(
            m,
            .transcribing,
            'Repli sur le processeur : accélération GPU indisponible.',
          );
          await run(config['whisper'] as String, [
            ...args,
            '-ng',
          ], logPath: '$dir/processing.log');
        }
        m.segments = parseWhisper(
          jsonDecode(await File('$dir/whisper.json').readAsString())
              as Map<String, dynamic>,
        );
        if (m.segments.isEmpty) {
          throw Exception(
            'Aucune parole détectée. Vérifiez la piste audio dans le lecteur.',
          );
        }
        await stage(
          m,
          .transcribed,
          '${m.segments.length} passages sauvegardés',
        );
      }
      if (m.segments.isEmpty) {
        throw Exception('Une transcription est nécessaire.');
      }
      if (hasDiarization && !m.speakersDetected) {
        try {
          await _identifySpeakers(m, m.expectedSpeakers);
        } catch (e) {
          guard();
          // Voice detection is optional: a model error must not lose the summary.
          m.speakerError = e.toString();
          await library.save(m);
        }
      }
      // ponytail: character budget keeps ordinary French within the 16k context;
      // token-aware splitting can follow if unusually dense sources exceed it.
      final chunks = transcriptChunks(m.segments, maxChars: 18000);
      final checkpoint = SummaryCheckpoint(
        File('$dir/summary.checkpoint.json'),
        jsonEncode({
          'version': 6,
          'model': config['summaryModel'],
          'speakerNames': m.speakerNames,
          'chunks': chunks
              .map((c) => c.map((s) => s.toJson()).toList())
              .toList(),
        }),
      );
      if (!regenerate) {
        await checkpoint.load(m.segments.map((s) => s.id).toSet());
      }
      // Persist a fresh generation before running inference, invalidating old work.
      await checkpoint.save();
      if (checkpoint.parts.length < chunks.length) {
        await stage(
          m,
          .summarizing,
          'Démarrage de l’IA locale · ${checkpoint.parts.length}/${chunks.length} parties sauvegardées',
        );
        await startServer();
        guard();
      }
      for (var i = checkpoint.parts.length; i < chunks.length; i++) {
        await stage(
          m,
          .summarizing,
          'Rédaction depuis la transcription · partie ${i + 1}/${chunks.length}',
        );
        final text = chunks[i]
            .map(
              (s) =>
                  '[${s.id}] ${m.speakerLabel(s).isEmpty ? '' : '${m.speakerLabel(s)}: '}${s.text}',
            )
            .join('\n');
        checkpoint.parts.add(
          await summarize(text, chunks[i].map((s) => s.id).toSet()),
        );
        await checkpoint.save();
      }
      // Every fact comes directly from source text; never summarize summaries.
      final seen = <String>{};
      final items = checkpoint.parts
          .expand((part) => part)
          .where(
            (item) => seen.add(
              '${item.kind.code}:${item.text.toLowerCase().replaceAll(RegExp(r'\s+'), ' ').trim()}',
            ),
          )
          .toList();
      final generated = renderSummary(items, m.segments);
      await File('$dir/summary.generated.md.tmp')
          .writeAsString(generated, flush: true);
      await File('$dir/summary.generated.md.tmp')
          .rename('$dir/summary.generated.md');
      // Keep the editable version: regeneration never erases user corrections.
      if (m.summary.isEmpty) {
        m.summary = generated;
      }
      await library.save(m);
      if (m.hasVideo) {
        final byId = {for (final s in m.segments) s.id: s};
        for (var i = checkpoint.nextCapture; i < items.length; i++) {
          guard();
          if (m.captures.length >= 8) {
            break;
          }
          final item = items[i];
          final s = byId[item.segmentIds.first]!;
          if (m.captures.any((c) => (c.time - s.start).abs() < 15000)) {
            checkpoint.nextCapture = i + 1;
            await checkpoint.save();
            continue;
          }
          await stage(
            m,
            .capturing,
            'Illustration ${m.captures.length + 1} · ${timeLabel(s.start)}',
          );
          await capture(m, s.start, item.title, skipIdentical: true);
          checkpoint.nextCapture = i + 1;
          await checkpoint.save();
        }
      }
      await stage(m, .ready, 'Compte rendu disponible');
    } catch (e) {
      m.status = cancelled ? .interrupted : .error;
      m.error = cancelled
          ? 'Traitement arrêté. Les résultats déjà produits sont conservés.'
          : e.toString();
      await library.save(m);
      rethrow;
    } finally {
      onUpdate?.call();
    }
  }

  Future<List<SummaryItem>> summarize(String text, Set<int> allowed) async {
    guard();
    final items = await _ollama.summarize(text, allowed);
    guard();
    return items;
  }

  Future<Capture?> capture(
    Meeting m,
    int time,
    String caption, {
    bool skipIdentical = false,
  }) async {
    guard();
    final safeTime = max(
      0,
      m.duration > 0 ? min(time, m.duration - 100) : time,
    );
    final name = 'captures/${DateTime.now().microsecondsSinceEpoch}.jpg';
    await Directory('${library.folder(m)}/captures').create(recursive: true);
    await run(config['ffmpeg'] as String, [
      '-y',
      '-v',
      'error',
      '-ss',
      (safeTime / 1000).toStringAsFixed(3),
      '-i',
      library.mediaPath(m),
      '-frames:v',
      '1',
      '-q:v',
      '3',
      '${library.folder(m)}/$name',
    ]);
    if (!File('${library.folder(m)}/$name').existsSync()) {
      throw Exception("Pas d'image à cet instant.");
    }
    if (skipIdentical) {
      final candidate = File('${library.folder(m)}/$name');
      final signature = await frameSignature(candidate.path);
      for (final previous in m.captures) {
        final file = File('${library.folder(m)}/${previous.file}');
        if (await file.exists() &&
            similarFrames(await frameSignature(file.path), signature)) {
          await candidate.delete();
          return null;
        }
      }
    }
    final shot = Capture(
      name,
      safeTime,
      caption.isEmpty ? 'Passage à revoir' : caption,
    );
    m.captures.add(shot);
    await library.save(m);
    onUpdate?.call();
    return shot;
  }

  Future<List<int>> frameSignature(String path) async {
    final thumbnail = File('$path.gray');
    try {
      await run(config['ffmpeg'] as String, [
        '-y',
        '-v',
        'error',
        '-i',
        path,
        '-vf',
        'scale=64:36:flags=area,format=gray',
        '-frames:v',
        '1',
        '-f',
        'rawvideo',
        thumbnail.path,
      ]);
      return await thumbnail.readAsBytes();
    } finally {
      if (await thumbnail.exists()) await thumbnail.delete();
    }
  }

  Future<String> export(Meeting m, String destination) async {
    var dir = Directory('$destination/Memora-${m.id}');
    for (var version = 2; await dir.exists(); version++) {
      dir = Directory('$destination/Memora-${m.id}-$version');
    }
    await dir.create(recursive: true);
    final out = StringBuffer('# ${m.title}\n\n${m.summary}\n\n');
    if (m.captures.isNotEmpty) {
      out.writeln('## Captures\n');
      await Directory('${dir.path}/captures').create();
      for (final shot in m.captures) {
        await File('${library.folder(m)}/${shot.file}')
            .copy('${dir.path}/${shot.file}');
        out.writeln(
          '${shot.caption} — ${timeLabel(shot.time)}\n\n![](${shot.file})\n',
        );
      }
    }
    if (m.notes.isNotEmpty) {
      out.writeln('## Notes personnelles\n\n${m.notes}');
    }
    // App-specific seek links become readable timestamps in a portable export.
    final portable = out.toString().replaceAllMapped(
      RegExp(r'\[([^\]]+)\]\(memora://seek/\d+\)'),
      (m) => m[1]!,
    );
    await File('${dir.path}/resume.md').writeAsString(portable, flush: true);
    await File('${dir.path}/transcription.md').writeAsString(
      m.segments
          .map(
            (s) =>
                '[${timeLabel(s.start)}] ${m.speakerLabel(s).isEmpty ? '' : '${m.speakerLabel(s)} : '}${s.text}',
          )
          .join('\n\n'),
      flush: true,
    );
    await File('${dir.path}/transcription.json').writeAsString(
      jsonEncode(
        m.segments
            .map((s) => {...s.toJson(), 'speaker': m.speakerLabel(s)})
            .toList(),
      ),
      flush: true,
    );
    return dir.path;
  }

  Future<void> exportAudio(Meeting m, String destination) async {
    cancelled = false;
    await loadConfig();
    await run(config['ffmpeg'] as String, [
      '-y',
      '-v',
      'error',
      '-i',
      library.mediaPath(m),
      '-map',
      '0:a:${m.audioTrack}',
      '-vn',
      '-c:a',
      'aac',
      '-b:a',
      '128k',
      destination,
    ]);
  }
}
