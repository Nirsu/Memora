/// Stable storage codes are separate from the French labels shown in the UI.
enum MeetingStatus {
  notes('Notes'),
  importing('Copie de la vidéo', isProcessing: true),
  imported('Importé'),
  extracting('Extraction audio', isProcessing: true),
  transcribing('Transcription', isProcessing: true),
  transcribed('Transcrit'),
  summarizing('Résumé', isProcessing: true),
  capturing('Captures', isProcessing: true),
  ready('Prêt'),
  error('Erreur'),
  interrupted('Interrompu');

  const MeetingStatus(this.label, {this.isProcessing = false});
  final String label;
  final bool isProcessing;

  static MeetingStatus fromJson(Object? value) {
    if (value == null) return .notes;
    for (final status in values) {
      // Read both current codes and the labels written by the original MVP.
      if (value == status.name || value == status.label) return status;
    }
    return .interrupted;
  }
}
