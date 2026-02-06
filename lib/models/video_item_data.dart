class VideoItemData {
  const VideoItemData({
    required this.id,
    required this.title,
    required this.source,
    this.isAsset = false,
  });

  final String id;
  final String title;
  final String source;
  final bool isAsset;
}
