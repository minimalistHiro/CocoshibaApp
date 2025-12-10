String formatRelativeTime(DateTime? dateTime) {
  if (dateTime == null) {
    return '日時取得中';
  }
  final now = DateTime.now();
  final difference = now.difference(dateTime);
  if (difference.inSeconds < 60 && !difference.isNegative) {
    return 'たった今';
  }
  if (difference.inMinutes < 60 && !difference.isNegative) {
    return '${difference.inMinutes}分前';
  }
  if (difference.inHours < 24 && !difference.isNegative) {
    return '${difference.inHours}時間前';
  }
  if (difference.inDays < 7 && !difference.isNegative) {
    return '${difference.inDays}日前';
  }
  return '${dateTime.year}/${dateTime.month.toString().padLeft(2, '0')}/${dateTime.day.toString().padLeft(2, '0')}';
}
