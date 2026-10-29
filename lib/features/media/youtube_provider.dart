import 'package:youtube_explode_dart/youtube_explode_dart.dart' as yt;

import 'media_models.dart';

class YoutubeStreams {
  const YoutubeStreams(this.audio, this.video);
  final Uri audio;
  final Uri? video;
}

abstract interface class YoutubeStreamProvider {
  Future<YoutubeStreams> resolve(String id);
  Future<List<MediaEntry>> search(String query);
  Future<MediaCollection> load(String input);
}

// Each operation owns and closes its HTTP client, including timed-out work.
// No signed URL, cookie or browsing history is persisted or logged.
class ExplodeStreamProvider implements YoutubeStreamProvider {
  yt.YoutubeExplode? activeResolver;
  void cancelResolve() { activeResolver?.close(); activeResolver = null; }
  MediaEntry entry(yt.Video v) => MediaEntry(v.id.value, v.title, v.author,
      duration: v.duration?.inMilliseconds ?? 0);
  @override
  Future<YoutubeStreams> resolve(String id) async {
    if (!RegExp(r'^[A-Za-z0-9_-]{11}$').hasMatch(id)) throw const FormatException('ID YouTube không hợp lệ');
    cancelResolve();
    final client = yt.YoutubeExplode();
    activeResolver = client;
    try {
      final manifest = await client.videos.streams.getManifest(id).timeout(const Duration(seconds: 35));
      final audio = manifest.audioOnly.where((s) => s.fragments.isEmpty).toList()
        ..sort((a,b) {
          final container = (a.container == yt.StreamContainer.mp4 ? 0 : 1).compareTo(b.container == yt.StreamContainer.mp4 ? 0 : 1);
          return container != 0 ? container : b.bitrate.bitsPerSecond.compareTo(a.bitrate.bitsPerSecond);
        });
      if (audio.isEmpty) throw const FormatException('Chưa có âm thanh phù hợp');
      final video = manifest.videoOnly.where((s) => s.fragments.isEmpty &&
          s.container == yt.StreamContainer.mp4 && s.videoCodec.startsWith('avc1') && s.videoResolution.height <= 720).toList()
        ..sort((a,b) => b.videoResolution.height.compareTo(a.videoResolution.height));
      return YoutubeStreams(audio.first.url, video.firstOrNull?.url);
    } finally { if (identical(activeResolver, client)) activeResolver = null; client.close(); }
  }
  @override
  Future<List<MediaEntry>> search(String query) async {
    final text = query.trim();
    if (text.isEmpty || text.length > 200) return const [];
    final client = yt.YoutubeExplode();
    try {
      final result = await client.search.search(text).timeout(const Duration(seconds: 20));
      return result.take(15).map(entry).toList();
    } finally { client.close(); }
  }
  @override
  Future<MediaCollection> load(String input) async {
    final value = input.trim();
    final uri = Uri.tryParse(value);
    if (uri != null && uri.hasScheme &&
        (uri.scheme != 'https' || !{'youtube.com','www.youtube.com','m.youtube.com','music.youtube.com','youtu.be','www.youtu.be'}.contains(uri.host)))
      throw const FormatException('Chỉ nhận liên kết YouTube HTTPS');
    final client = yt.YoutubeExplode();
    try {
      final playlist = uri?.queryParameters['list'];
      if (playlist != null && playlist.isNotEmpty) {
        return await (() async {
          final list = await client.playlists.get(playlist);
          final videos = await client.playlists.getVideos(list.id).take(200).map(entry).toList();
          if (videos.isEmpty) throw const FormatException('Danh sách chưa có video công khai');
          return MediaCollection('playlist_${list.id.value}', list.title, videos);
        })().timeout(const Duration(seconds: 30));
      }
      final video = await client.videos.get(value).timeout(const Duration(seconds: 20));
      return MediaCollection('video_${video.id.value}',video.title,[entry(video)]);
    } finally { client.close(); }
  }
}
