import 'package:youtube_explode_dart/youtube_explode_dart.dart' as yt;

import 'media_models.dart';
import 'youtube_clients.dart';
import 'youtube_probe.dart';

class YoutubeStreams {
  const YoutubeStreams(
    this.audio,
    this.video, {
    this.muxed = false,
    this.client = 'unknown',
  });
  final Uri audio;
  final Uri? video;
  final bool muxed;
  final String client;
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
  int generation = 0;
  void cancelResolve() {
    generation++;
    activeResolver?.close();
    activeResolver = null;
  }

  MediaEntry entry(yt.Video v) => MediaEntry(
    v.id.value,
    v.title,
    v.author,
    duration: v.duration?.inMilliseconds ?? 0,
  );
  @override
  Future<YoutubeStreams> resolve(String id) async {
    if (!RegExp(r'^[A-Za-z0-9_-]{11}$').hasMatch(id))
      throw const FormatException('ID YouTube không hợp lệ');
    cancelResolve();
    final task = generation;
    for (final mode in youtubeClients) {
      if (task != generation) throw const FormatException('Đã đổi bài');
      final client = yt.YoutubeExplode();
      activeResolver = client;
      try {
        final manifest = await client.videos.streams
            .getManifest(id, ytClients: [mode.$2], requireWatchPage: false)
            .timeout(const Duration(seconds: 7));
        if (task != generation) throw const FormatException('Đã đổi bài');
        final audio =
            manifest.audioOnly.where((s) => s.fragments.isEmpty).toList()
              ..sort((a, b) {
                final container =
                    (a.container == yt.StreamContainer.mp4 ? 0 : 1).compareTo(
                      b.container == yt.StreamContainer.mp4 ? 0 : 1,
                    );
                return container != 0
                    ? container
                    : b.bitrate.bitsPerSecond.compareTo(
                        a.bitrate.bitsPerSecond,
                      );
              });

        final video =
            manifest.videoOnly
                .where(
                  (s) =>
                      s.fragments.isEmpty &&
                      s.container == yt.StreamContainer.mp4 &&
                      s.videoCodec.startsWith('avc1') &&
                      s.videoResolution.height <= 720 &&
                      s.videoResolution.width <= 1280,
                )
                .toList()
              ..sort(
                (a, b) => b.videoResolution.height.compareTo(
                  a.videoResolution.height,
                ),
              );
        if (audio.isNotEmpty && await probeYoutubeMedia(audio.first.url)) {
          if (task != generation) throw const FormatException('Đã đổi bài');
          final picture =
              mode.$1 == 'vision' &&
                  video.isNotEmpty &&
                  await probeYoutubeMedia(video.first.url)
              ? video.first.url
              : null;
          if (task != generation) throw const FormatException('Đã đổi bài');
          return YoutubeStreams(audio.first.url, picture, client: mode.$1);
        }
        final muxed =
            manifest.muxed
                .where(
                  (s) =>
                      s.fragments.isEmpty &&
                      s.container == yt.StreamContainer.mp4 &&
                      s.videoResolution.height <= 360,
                )
                .toList()
              ..sort(
                (a, b) => b.videoResolution.height.compareTo(
                  a.videoResolution.height,
                ),
              );
        if (muxed.isNotEmpty && await probeYoutubeMedia(muxed.first.url)) {
          if (task != generation) throw const FormatException('Đã đổi bài');
          return YoutubeStreams(
            muxed.first.url,
            null,
            muxed: true,
            client: mode.$1,
          );
        }
      } catch (_) {
        if (task != generation) rethrow;
      } finally {
        if (identical(activeResolver, client)) activeResolver = null;
        client.close();
      }
    }
    throw const FormatException('Chưa lấy được luồng phù hợp');
  }

  @override
  Future<List<MediaEntry>> search(String query) async {
    final text = query.trim();
    if (text.isEmpty || text.length > 200) return const [];
    final client = yt.YoutubeExplode();
    try {
      final result = await client.search
          .searchContent(text, filter: yt.TypeFilters.video)
          .timeout(const Duration(seconds: 20));
      return result.whereType<yt.SearchVideo>().take(15).map((video) => MediaEntry(
        video.id.value, video.title, video.author,
        duration: youtubeDurationMs(video.duration),
      )).toList();
    } finally {
      client.close();
    }
  }

  @override
  Future<MediaCollection> load(String input) async {
    final value = input.trim();
    final uri = Uri.tryParse(value);
    if (uri != null &&
        uri.hasScheme &&
        (uri.scheme != 'https' ||
            !{
              'youtube.com',
              'www.youtube.com',
              'm.youtube.com',
              'music.youtube.com',
              'youtu.be',
              'www.youtu.be',
            }.contains(uri.host)))
      throw const FormatException('Chỉ nhận liên kết YouTube HTTPS');
    final client = yt.YoutubeExplode();
    try {
      final playlist = uri?.queryParameters['list'];
      if (playlist != null && playlist.isNotEmpty) {
        return await (() async {
          final list = await client.playlists.get(playlist);
          final videos = await client.playlists
              .getVideos(list.id)
              .take(200)
              .map(entry)
              .toList();
          if (videos.isEmpty)
            throw const FormatException('Danh sách chưa có video công khai');
          return MediaCollection(
            'playlist_${list.id.value}',
            list.title,
            videos,
          );
        })().timeout(const Duration(seconds: 30));
      }
      final normalized = uri != null && uri.pathSegments.firstOrNull == 'shorts'
          ? Uri(scheme: uri.scheme, host: uri.host, path: uri.path).toString()
          : value;
      final id = yt.VideoId.fromString(normalized).value;
      try {
        final video = await client.videos.get(id).timeout(const Duration(seconds: 12));
        return MediaCollection('video_${video.id.value}', video.title, [entry(video)]);
      } catch (_) {
        // Metadata and playback use different endpoints. A missing watch-page
        // response must not prevent trying a valid public video link.
        return MediaCollection('video_$id', 'YouTube · $id', [MediaEntry(id, 'YouTube · $id', '')]);
      }
    } finally {
      client.close();
    }
  }
}

// Raw search results avoid upstream 3.1.0's relative-upload-date parser (#392).
int youtubeDurationMs(String? text) {
  if (text == null || !RegExp(r'^[0-9]{1,3}(:[0-9]{2}){1,2}$').hasMatch(text)) return 0;
  var total = 0;
  for (final field in text.split(':')) { total = total * 60 + int.parse(field); }
  return total * 1000;
}
