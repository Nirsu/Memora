# Memora

Application Flutter pour Windows : notes de réunion, import d’un enregistrement OBS, transcription et résumé locaux, captures et replay.

**Démarrer :** double-cliquer sur `Lancer Memora.cmd`. Consulter le [guide utilisateur](docs/guide.md) et la [review avec les vérifications](docs/review.md).

## Développement

```powershell
flutter pub get
flutter analyze
flutter test
flutter run -d windows
flutter build windows --release --no-tree-shake-icons
```

Les moteurs s’installent avec `scripts/setup.ps1`. Le test complet `dart run scripts/smoke.dart <video>` utilise une bibliothèque isolée, sans ajouter de meeting à l’app.

## Structure

- `lib/` : interface Flutter, bibliothèque et traitement local.
- `windows/` : intégration et compilation Windows.
- `test/` : tests de stockage et de parcours utilisateur.
- `scripts/` : installation des moteurs et vérification sur une vidéo d’essai.
- `docs/` : guide et état des fonctionnalités.

`.runtime/` contient les moteurs et modèles ; `.local/` contient les réunions et résultats de tests. Ces données sont ignorées par Git. `build/` et `.dart_tool/` sont générés ; le lanceur utilise la version Release dans `build/`.

## Périmètre actuel

OBS enregistre l’appel (MKV ou MP4 hybride). Memora traite ensuite le fichier sur cette machine, avec Whisper et Qwen3 via Ollama. Les noms des intervenants sont attribués manuellement. Les captures sont proposées autour des passages du résumé, sans analyse visuelle. Les notes personnelles sont sauvegardées et exportées ; elles ne sont pas utilisées comme source du résumé IA.
