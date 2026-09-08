/// Conservative comparison of equally sized grayscale thumbnails.
bool similarFrames(List<int> a, List<int> b) {
  if (a.isEmpty || a.length != b.length) return false;
  var difference = 0;
  var changed = 0;
  for (var i = 0; i < a.length; i++) {
    final delta = (a[i] - b[i]).abs();
    difference += delta;
    if (delta > 12) changed++;
  }
  // ponytail: thumbnail comparison removes near-static screens, not semantic
  // duplicates. Keep thresholds conservative to preserve small slide changes.
  return difference / a.length < 1.5 && changed / a.length < .005;
}
