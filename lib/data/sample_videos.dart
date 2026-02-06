import '../models/video_item_data.dart';

List<VideoItemData> buildSampleVideos() {
  const total = 20;
  return List<VideoItemData>.generate(total, (index) {
    final number = (index + 1).toString().padLeft(2, '0');
    return VideoItemData(
      id: 'video_$number',
      title: 'Video $number',
      source: 'assets/videos/video_$number.mp4',
      isAsset: true,
    );
  });
}
