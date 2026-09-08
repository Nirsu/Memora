# Intervenants locaux

La détection expérimentale regroupe les prises de parole par voix. Dans le panneau **Intervenants**, nommer chaque groupe une fois applique ce nom à ses passages. Une correction individuelle reste prioritaire lors d'un nouveau calcul. Le moteur ne connaît pas automatiquement l'identité des personnes.

## Moteur installé

La version Windows utilise **sherpa-onnx 1.13.7**, la segmentation **pyannote 3.0 convertie en ONNX** et les empreintes vocales **NVIDIA NeMo TitaNet Large**. Ce n'est pas le pipeline pyannote Community-1. Whisper large-v3-turbo reste chargé de la transcription française ; le moteur de voix travaille séparément sur l'audio.

Après `scripts/setup.ps1`, exécuter `powershell -ExecutionPolicy Bypass -File scripts/setup-diarization.ps1` depuis la racine du dépôt. Les fichiers et DLL restent dans `.runtime/diarization`, ignoré par Git. Aucun Python, compte ou service distant n'est nécessaire à l'exécution. L'installation télécharge les poids ; les enregistrements restent locaux. Le calcul actuel utilise quatre threads CPU, sans installation CUDA supplémentaire.

Quand ce moteur est installé, le traitement d'un meeting tente aussi de détecter les voix. Il est possible de relancer uniquement cette détection depuis le panneau Intervenants, en indiquant le nombre de personnes si on le connaît. Une erreur du moteur de voix n'empêche pas la génération du résumé. Relancer les voix conserve l'état d'un traitement principal encore incomplet.

## Sources et attributions

- [sherpa-onnx, documentation diarisation](https://k2-fsa.github.io/sherpa/onnx/speaker-diarization/index.html), [binaire Windows 1.13.7](https://github.com/k2-fsa/sherpa-onnx/releases/tag/v1.13.7) : projet k2-fsa, licence Apache-2.0.
- [Segmentation pyannote convertie par sherpa-onnx](https://k2-fsa.github.io/sherpa/onnx/speaker-diarization/models.html) : copyright CNRS 2022, licence MIT incluse dans l'archive du modèle. Memora ne modifie pas les poids.
- [NVIDIA TitaNet Large](https://huggingface.co/nvidia/speakerverification_en_titanet_large) : NVIDIA, licence [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/). Conversion ONNX distribuée par [sherpa-onnx](https://github.com/k2-fsa/sherpa-onnx/releases/tag/speaker-recongition-models), fichier `nemo_en_titanet_large.onnx`, utilisé sans modification supplémentaire.

La fiche NVIDIA documente un entraînement sur de la parole anglaise. Ses résultats publiés ne sont pas un benchmark de cette combinaison sherpa-onnx sur des conversations françaises.

## Vérification et limites constatées

Le moteur peut estimer le nombre de personnes (seuil natif 0,5), ou recevoir le nombre connu via `--clustering.num-clusters=3`. Ce second réglage guide le regroupement, sans garantir sa justesse. L'app signale un nombre obtenu différent du nombre attendu.

Un passage Whisper peut couvrir plusieurs prises de parole ou du silence. Memora laisse les cas ambigus sans nom et ne fabrique pas de frontières entre mots. Le regroupement peut encore fusionner deux voix ou dédoubler une même personne, particulièrement sur des interventions brèves et les chevauchements.

Les essais sur des conversations françaises ont permis de vérifier l'exécution, mais ont montré des fusions de voix et des groupes manquants. Cette combinaison n'est pas validée comme une diarisation fiable en français. Les passages attribués automatiquement peuvent également nécessiter une correction.

## Reproduire un essai

`dart run scripts/diarization_smoke.dart <dossier-du-meeting> 3` lance seulement les voix, sauvegarde puis recharge la réunion, et contrôle que le texte, ses horodatages et le résumé restent identiques. Ce script modifie les attributions du meeting indiqué ; utiliser `.local/smoke/meetings` pour les essais techniques. Les tours bruts sont dans `diarization.txt`, la sortie du moteur dans `diarization.log`. Un recalcul conserve les attributions précédentes dans `speakers.previous.json`.

Les tests Flutter couvrent la correspondance temporelle, les chevauchements, le renommage global, les corrections individuelles, les exports, le redémarrage, le filtre, l'annulation et la poursuite du résumé quand le moteur de voix échoue. Ils ne remplacent pas une référence audio annotée pour mesurer l'exactitude en français.
