import 'package:flutter_test/flutter_test.dart';
import 'package:memora/models/meeting.dart';
import 'package:memora/models/replay_moment.dart';

void main() {
  test(
    'Replay moments use real links, deduplicate and reject invalid times',
    () {
      final meeting = Meeting('test', 'Test', DateTime(2026))
        ..duration = 60000
        ..summary = '''## Décisions
- **Livraison** — Vendredi. [00:00:20](memora://seek/20000)
- Même passage [00:00:20](memora://seek/20000)
- Sans source
- Lien externe [source](https://example.com/3000)
- Invalide [source](memora://seek/-1)
- Invalide [source](memora://seek/nope)
- Hors vidéo [source](memora://seek/70000)
'''
        ..captures = [
          Capture('a.png', 1000, 'Écran partagé'),
          Capture('b.png', 20000, 'Doublon'),
          Capture('c.png', -1, 'Invalide'),
        ];
      final moments = replayMoments(meeting);
      expect(moments.map((moment) => moment.time), [1000, 20000]);
      expect(moments.last.title, 'Livraison — Vendredi.');
      expect(moments.last.section, 'Décisions');
      expect(moments.first.section, 'Capture');
    },
  );
}
