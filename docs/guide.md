# Utiliser Memora

Ouvrir **Lancer Memora.cmd** à la racine du projet. La version Windows compilée se trouve dans `build/windows/x64/runner/Release`. Les modèles et moteurs sont installés dans `.runtime`, les meetings dans `.local/meetings`. Garder ces dossiers avec le projet. Aucun compte ni abonnement IA n'est nécessaire.

## Avant le meeting : un essai de 30 secondes

1. Ouvrir OBS, déjà installé sur cet ordinateur.
2. Ajouter une **Capture de fenêtre** pour l'application de meeting, ou une **Capture d'écran**. Vérifier dans l'aperçu que le contenu voulu est visible.
3. Vérifier que **Audio du bureau** (ou une source de capture audio de l'application) ET **Mic/Aux** sont présents. Le vumètre du micro doit réagir à votre voix et celui de l'appel à un son de l'application. Éviter d'enregistrer deux fois la même source. Un casque limite l'écho.
4. Dans Paramètres → Sortie → Enregistrement, choisir **MP4 hybride** ou **MKV**. Si plusieurs pistes sont utilisées, la **piste 1 doit contenir le mix complet** : micro et voix distantes. Les propriétés audio avancées permettent d'affecter chaque source aux pistes.
5. Enregistrer 30 secondes contenant votre voix et le son de l'ordinateur, arrêter OBS, puis réécouter. C'est la vérification la plus importante : Memora ne peut pas récupérer une voix qui n'a pas été enregistrée.
6. Importer cet essai dans Memora et lancer **Transcrire et résumer**. Vérifier une fois la lecture, le texte et le résumé avant le vrai appel.

## Pendant le meeting

- Dans Memora, **Préparer mon meeting**, renommer le titre et ouvrir **Mes notes**.
- Démarrer l'enregistrement dans OBS. Memora n'enregistre pas l'écran ni le son dans cette version.
- Facultatif : démarrer le repère temps Memora au même instant. **Moment important** ajoute un timestamp dans les notes. Ce repère est manuel et approximatif ; il continue pendant la navigation dans Memora, mais repart à zéro si Memora est fermé.
- Écrire les notes normalement : elles sont sauvegardées localement au fil de la saisie. Garder l'indicateur « Enregistré localement » à l'œil.

## Après le meeting

1. Arrêter OBS pour finaliser le fichier MP4 ou MKV.
2. Dans le meeting préparé, cliquer **Rattacher l'enregistrement OBS**. Si plusieurs pistes existent, choisir celle qui contient toutes les voix. Memora copie le fichier ; l'original OBS est conservé.
3. Cliquer **Transcrire et résumer**. L'app extrait l'audio, lance Whisper puis Qwen3 via Ollama, et propose des captures près des sujets importants. Le traitement se fait sur cette machine.
4. Relire le résumé et cliquer sur les timestamps pour vérifier les passages. Les captures sont proposées par proximité temporelle, sans compréhension visuelle ; ajouter une meilleure image depuis le lecteur ou retirer une image inutile.
5. Dans **Transcription**, attribuer manuellement les noms aux passages et corriger le texte si nécessaire. Les voix ne sont pas automatiquement séparées en groupes dans cette version.
6. **Exporter** produit un nouveau dossier à chaque export avec `resume.md`, les images et la transcription en Markdown et JSON. **Exporter l'audio** produit un M4A de la piste choisie. **Audio seul** masque l'image tout en permettant l'écoute.

## Résumés, corrections et erreurs

- Pour retirer un meeting créé par erreur, cliquez sur la corbeille dans la bibliothèque ou à côté du titre du meeting, puis sur **Supprimer**. Le bouton **Annuler** reste disponible pendant 10 secondes. Les fichiers sont déplacés dans `.local/meetings/.trash` : ils restent sur le disque et le fichier OBS d'origine n'est pas touché. La suppression est désactivée pendant un traitement.

- Une régénération écrit `summary.generated.md` et préserve le résumé édité. Le menu du résumé permet d'utiliser la nouvelle version ; la précédente est alors conservée dans `summary.previous.md`.
- Une interruption de traitement conserve l'enregistrement, les notes et les résultats déjà produits. Relancer reprend à partir de la transcription si elle existe.
- Si le résumé échoue, la transcription reste consultable. Vous pouvez exporter son Markdown pour une synthèse manuelle dans un autre outil ; cet envoi éventuel reste à votre initiative.
- Si la capture d'images échoue, le résumé peut déjà être présent et éditable. Les captures peuvent être ajoutées depuis le lecteur.
- Le dossier de chaque meeting contient `processing.log` pour diagnostiquer FFmpeg et Whisper. Les fichiers `meeting.json.bak` conservent la sauvegarde précédente.

## Moteurs locaux

Whisper large-v3-turbo assure la transcription française. Qwen3 8B quantifié assure le résumé. Ils sont utilisés successivement, après l'appel. Le binaire Whisper détecte la RTX 5070 Ti ; en cas d'échec GPU, un essai CPU est prévu. Le mode rapide utilise une recherche de transcription simple (`beam_size=1`).

Ollama est lié uniquement à `127.0.0.1:11435` avec les fonctions cloud désactivées. Le moteur démarre automatiquement au premier résumé ; le panneau **Moteurs locaux** permet également de le démarrer et vérifier. Un téléchargement internet est nécessaire uniquement à l'installation initiale ; aucun téléchargement de modèle n'est lancé implicitement par l'app.

Pour réinstaller sur cette machine, exécuter `scripts/setup.ps1` depuis PowerShell. Le script télécharge FFmpeg (build Windows Gyan), whisper.cpp, Ollama et leurs modèles. Il ne modifie pas les réglages OBS. Les chemins et le modèle de résumé sont dans `.runtime/runtime.json`. Ne changer le modèle qu'après l'avoir téléchargé dans le même stockage Ollama.

## Développement et vérification

```powershell
flutter pub get
flutter analyze
flutter test
flutter run -d windows
flutter build windows --release --no-tree-shake-icons
```

Un essai de traitement entièrement local peut être lancé avec `dart run scripts/smoke.dart <chemin-vers-une-video>`. `scripts/make-test-recording.ps1` crée une réunion fictive pour tester le parcours sans données réelles ; la voix Windows disponible peut avoir un accent anglais et ne constitue pas un benchmark de qualité en français.

Cette livraison est destinée au premier test personnel : pas de capture intégrée, de diarisation automatique, de synchronisation cloud ni d'analyse visuelle exhaustive. L'enregistrement réel du meeting de demain permettra d'évaluer la qualité avec plusieurs voix, les interruptions et les termes spécifiques à votre équipe.
