String _two(int n) => n.toString().padLeft(2, '0');

/// 754000 ms -> "12:34". Over an hour -> "1:02:03".
String formatClock(int ms) {
  final s = ms ~/ 1000;
  final h = s ~/ 3600;
  final m = (s % 3600) ~/ 60;
  final x = s % 60;
  return h > 0 ? '$h:${_two(m)}:${_two(x)}' : '${_two(m)}:${_two(x)}';
}

String formatDateTime(DateTime d) =>
    '${d.day}/${d.month}/${d.year}  ${_two(d.hour)}:${_two(d.minute)}';