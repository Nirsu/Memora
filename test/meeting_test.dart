import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:memora/meeting.dart';
import 'package:memora/engine.dart';

void main() {
  test('Cancelling an import leaves the original intact and removes its partial copy', () async {
    final dir = await Directory.systemTemp.createTemp('memora-import-test-');
    try {
      final source = await File('${dir.path}/source.mp4')
          .writeAsBytes([1, 2, 3]);
      final store = Library(Directory('${dir.path}/meetings'));
      final m = Meeting('cancel-test', 'Import', DateTime(2026));
      final engine = LocalEngine(dir, store);
      engine.onUpdate = engine.cancel;
      await expectLater(
        engine.importMedia(m, source.path, 0, {}),
        throwsException,
      );
      expect(await source.readAsBytes(), [1, 2, 3]);
      expect(
        await File('${store.folder(m)}/recording.mp4.partial').exists(),
        isFalse,
      );
      expect(m.media, isEmpty);
    } finally {
      await dir.delete(recursive: true);
    }
  });
  test(
    'Explorer receives an existing native path, including spaces and accents',
    () async {
      final dir = await Directory.systemTemp.createTemp('memora explorer é ');
      try {
        final nested = await Directory('${dir.path}/un meeting').create();
        final path = await explorerFolderPath(
          nested.path.replaceAll(r'\', '/'),
        );
        expect(path, isNot(contains('/')));
        expect(await Directory(path).exists(), isTrue);
        await expectLater(
          explorerFolderPath('${dir.path}/missing'),
          throwsA(isA<FileSystemException>()),
        );
      } finally {
        await dir.delete(recursive: true);
      }
    },
  );
  test('Removal preserves media, drains saves and can be undone without resurrection', () async {
    final dir = await Directory.systemTemp.createTemp('memora-remove-test-');
    try {
      final store = Library(dir);
      final m = Meeting('remove-test', 'Brouillon', DateTime(2026));
      final other = Meeting('keep-test', 'À conserver', DateTime(2026));
      await store.save(m);
      await store.save(other);
      await File('${store.folder(m)}/original.mkv').writeAsBytes([1, 2, 3]);
      m.notes = 'Dernière note';
      final pending = store.save(m);
      final removal = store.remove(m);
      final lateSave = store.save(m);
      await Future.wait([pending, removal, lateSave]);
      expect((await Library(dir).load()).map((m) => m.id), ['keep-test']);
      expect(await Directory(store.folder(m)).exists(), isFalse);
      expect(
        await File('${dir.path}/.trash/${m.id}/original.mkv').readAsBytes(),
        [1, 2, 3],
      );
      await store.restore(m);
      expect(
        (await store.load()).firstWhere((x) => x.id == m.id).notes,
        'Dernière note',
      );
      expect(await File('${store.folder(m)}/original.mkv').readAsBytes(), [
        1,
        2,
        3,
      ]);
      await expectLater(
        store.remove(Meeting('../escape', 'Invalide', DateTime(2026))),
        throwsFormatException,
      );
    } finally {
      await dir.delete(recursive: true);
    }
  });
  test(
    'Whisper offsets remain in milliseconds and empty segments are skipped',
    () {
      final segments = parseWhisper({
        'transcription': [
          {
            'offsets': {'from': 12500, 'to': 15800},
            'text': ' Une décision, avec "guillemets". ',
          },
          {
            'offsets': {'from': 15800, 'to': 16000},
            'text': ' ',
          },
        ],
      });
      expect(segments.length, 1);
      expect(segments.single.start, 12500);
      expect(segments.single.end, 15800);
      expect(segments.single.text, 'Une décision, avec "guillemets".');
      expect(timeLabel(3661000), '01:01:01');
    },
  );

  test('Chunking preserves every source ID for a long meeting', () {
    final segments = List.generate(
      200,
      (i) => Segment(i, i * 1000, i * 1000 + 900, 'texte ' * 30),
    );
    final chunks = transcriptChunks(segments, maxChars: 1000);
    expect(chunks.length, greaterThan(1));
    expect(
      chunks.expand((c) => c).map((s) => s.id),
      orderedEquals(segments.map((s) => s.id)),
    );
  });

  test('Hallucinated source IDs cannot create invented replay links', () {
    final items = validatedItems(
      {
        'items': [
          {
            'kind': 'action',
            'title': 'Tester',
            'text': 'Faire le test.',
            'segment_ids': [999, 2],
          },
          {
            'kind': 'sujet',
            'text': 'Sans source.',
            'segment_ids': [999],
          },
        ],
      },
      {2},
    );
    expect(items.length, 1);
    final markdown = renderSummary(items, [
      Segment(2, 12300, 14500, 'Faire le test.'),
    ]);
    expect(markdown, contains('memora://seek/12300'));
    expect(markdown, isNot(contains('999')));
    expect(() => validatedItems({'items': []}, {2}), throwsFormatException);
    expect(replayTimestamp('memora://seek/12300'), 12300);
    for (final href in [
      null,
      'memora://seek',
      'memora://seek/-1',
      'memora://seek/abc',
      'https://example.com',
      'memora://seek/1/2',
    ]) {
      expect(replayTimestamp(href), isNull);
    }
  });

  test(
    'Notes and speaker edits survive queued saves and corrupted latest file',
    () async {
      final dir = await Directory.systemTemp.createTemp('memora-test-');
      try {
        final store = Library(dir);
        final m = Meeting('test', 'Réunion', DateTime(2026, 9, 8));
        m.notes = 'Première note';
        final first = store.save(m);
        m.notes = 'Note corrigée';
        m.segments = [Segment(0, 0, 500, 'Bonjour', 'Alexandre')];
        final second = store.save(m);
        await Future.wait([first, second]);
        final loaded = (await store.load()).single;
        expect(loaded.notes, 'Note corrigée');
        expect(loaded.segments.single.speaker, 'Alexandre');
        await File('${store.folder(m)}/meeting.json').writeAsString('{broken');
        expect((await store.load()).single.notes, 'Première note');
        expect(store.warnings, isNotEmpty);
      } finally {
        await dir.delete(recursive: true);
      }
    },
  );

  test(
    'Export is portable and preserves transcript speaker and screenshots',
    () async {
      final dir = await Directory.systemTemp.createTemp('memora-export-test-');
      try {
        final store = Library(Directory('${dir.path}/meetings'));
        final m = Meeting('test', 'Réunion', DateTime(2026));
        m.summary = 'Décision [00:00:02](memora://seek/2000)';
        m.segments = [Segment(0, 2000, 3000, 'On valide.', 'Alexandre')];
        m.captures = [Capture('captures/frame.jpg', 2000, 'Décision')];
        await store.save(m);
        await Directory('${store.folder(m)}/captures').create();
        await File('${store.folder(m)}/captures/frame.jpg')
            .writeAsBytes([1, 2, 3]);
        final engine = LocalEngine(dir, store);
        final output = await engine.export(m, '${dir.path}/export');
        expect(
          await File('$output/resume.md').readAsString(),
          isNot(contains('memora://')),
        );
        expect(
          await File('$output/transcription.md').readAsString(),
          contains('Alexandre'),
        );
        expect(
          jsonDecode(await File('$output/transcription.json').readAsString()),
          hasLength(1),
        );
        expect(await File('$output/captures/frame.jpg').readAsBytes(), [
          1,
          2,
          3,
        ]);
        await File('$output/resume.md')
            .writeAsString('Correction hors de Memora');
        final fresh = await engine.export(m, '${dir.path}/export');
        expect(fresh, isNot(output));
        expect(
          await File('$output/resume.md').readAsString(),
          'Correction hors de Memora',
        );
        engine.config = {'ollamaUrl': 'https://example.com'};
        expect(() => engine.endpoint('/api/chat'), throwsFormatException);
      } finally {
        await dir.delete(recursive: true);
      }
    },
  );
}
