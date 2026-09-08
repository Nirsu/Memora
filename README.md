# Memora

Application Flutter pour Windows : notes de réunion, import d'un enregistrement OBS, transcription et résumé locaux, captures et replay.

Consulter le [guide utilisateur](docs/guide.md), l'[architecture du code](docs/architecture.md) et le fonctionnement des [intervenants](docs/intervenants.md).

## Installation depuis le dépôt

Prérequis : Windows x64, Flutter avec Dart 3.13.1 ou plus récent, et Visual Studio avec la charge de travail **Développement Desktop en C++**. Vérifier l'environnement avec `flutter doctor -v` ; voir la [configuration Windows de Flutter](https://docs.flutter.dev/platform-integration/windows/setup).

Depuis la racine du dépôt :

```powershell
flutter pub get
powershell -ExecutionPolicy Bypass -File scripts/setup.ps1
flutter build windows --release --no-tree-shake-icons
```

L'installation télécharge les moteurs et les modèles dans `.runtime/` et nécessite plusieurs Go libres. Double-cliquer ensuite sur `Lancer Memora.cmd`. Après une modification du code, reconstruire la version Release pour mettre à jour celle du lanceur.

## Développement

```powershell
flutter pub get
flutter analyze
flutter test
flutter run -d windows
flutter build windows --release --no-tree-shake-icons
```

Le test complet `dart run scripts/smoke.dart <video>` utilise une bibliothèque isolée, sans ajouter de meeting à l'app. Il nécessite les moteurs installés. Les tests `flutter test` utilisent des données temporaires et ne nécessitent pas les modèles.

## Structure

- `lib/main.dart` et `lib/app.dart` : démarrage et configuration de l'application.
- `lib/ui/` : écrans, widgets, dialogues, thème et état de l'espace de travail.
- `lib/models/` : réunions, transcription, résumés et statuts typés.
- `lib/data/` : stockage local, sauvegardes et corbeille.
- `lib/services/` : traitement des médias, client Ollama et intégration fichiers Windows.
- `lib/utils/` : timestamps et comparaison des captures.
- `windows/` : intégration et compilation Windows.
- `test/` : tests de stockage et de parcours utilisateur.
- `scripts/` : installation des moteurs et vérification sur une vidéo d'essai.
- `docs/` : guide et état des fonctionnalités.

`.runtime/` contient les moteurs et modèles ; `.local/` contient les réunions et résultats de tests. Ces données sont ignorées par Git. `build/` et `.dart_tool/` sont générés ; le lanceur utilise la version Release dans `build/`.

## Périmètre actuel

OBS enregistre l'appel (MKV ou MP4 hybride). Memora traite ensuite le fichier sur cette machine, avec Whisper et Qwen3 via Ollama. Une détection expérimentale regroupe les voix localement : l'utilisateur nomme chaque groupe une fois et peut corriger un passage. Le moteur facultatif s'installe avec `scripts/setup-diarization.ps1` ; ses limites sont détaillées dans [Intervenants](docs/intervenants.md). Les captures sont proposées autour des passages du résumé, sans analyse visuelle. Les notes personnelles sont sauvegardées et exportées ; elles ne sont pas utilisées comme source du résumé IA.
