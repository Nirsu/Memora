int? replayTimestamp(String? href) {
  final uri = Uri.tryParse(href ?? '');
  if (uri?.scheme != 'memora' ||
      uri?.host != 'seek' ||
      uri!.pathSegments.length != 1) {
    return null;
  }
  final ms = int.tryParse(uri.pathSegments.single);
  return ms != null && ms >= 0 ? ms : null;
}

String timeLabel(int ms) {
  final seconds = ms ~/ 1000;
  return '${(seconds ~/ 3600).toString().padLeft(2, '0')}:'
      '${(seconds ~/ 60 % 60).toString().padLeft(2, '0')}:'
      '${(seconds % 60).toString().padLeft(2, '0')}';
}
