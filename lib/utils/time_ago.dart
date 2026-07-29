/// Converts a timestamp into a short, human-friendly relative string,
/// used by the Dashboard's Recent Activities feed.
String timeAgo(DateTime time) {
  final diff = DateTime.now().difference(time);
  if (diff.inSeconds < 60) return 'Just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
  if (diff.inHours < 24) return '${diff.inHours} hr ago';
  if (diff.inDays == 1) return 'Yesterday';
  if (diff.inDays < 7) return '${diff.inDays} days ago';
  return '${time.day.toString().padLeft(2, '0')}/${time.month.toString().padLeft(2, '0')}/${time.year}';
}
