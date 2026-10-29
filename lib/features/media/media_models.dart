import 'dart:convert';
import 'dart:typed_data';

class MediaEntry {
  const MediaEntry(this.id, this.title, this.author, {this.duration = 0});
  final String id, title, author;
  final int duration;
  factory MediaEntry.fromJson(Map j) => MediaEntry(j['id'] as String,
      j['title'] as String? ?? 'YouTube', j['author'] as String? ?? '',
      duration: (j['duration'] as num? ?? 0).toInt());
  Map<String, dynamic> toJson() => {'id': id, 'title': title, 'author': author, 'duration': duration};
}

class MediaCollection {
  const MediaCollection(this.id, this.title, this.entries, {this.favorite = true});
  final String id, title;
  final List<MediaEntry> entries;
  final bool favorite;
  factory MediaCollection.fromJson(Map j) => MediaCollection(j['id'] as String,
      j['title'] as String, [for (final e in j['entries'] as List) MediaEntry.fromJson(e as Map)],
      favorite: j['favorite'] != false);
  Map<String, dynamic> toJson() => {'id': id, 'title': title, 'favorite': favorite, 'entries': entries.map((e) => e.toJson()).toList()};
}

class MediaSnapshot {
  const MediaSnapshot({this.source = 'external', this.external = const {},
    this.title = 'Chưa chọn bài', this.artist = '', this.playing = false,
    this.loading = false, this.position = 0, this.duration = 0, this.index = 0,
    this.queueCount = 0, this.videoSafe = false, this.videoRequested = false,
    this.videoVisible = false, this.hasVideo = false, this.carConnected = false,
    this.aspect = 16 / 9, this.message = '', this.playedMs = 0});
  final String source, title, artist, message;
  final Map<String, dynamic> external;
  final bool playing, loading, videoSafe, videoRequested, videoVisible, hasVideo, carConnected;
  final int position, duration, index, queueCount, playedMs;
  final double aspect;
  factory MediaSnapshot.fromJson(Map j) => MediaSnapshot(
    source: j['source'] as String? ?? 'external',
    external: Map<String,dynamic>.from(j['external'] as Map? ?? {}),
    title: j['title'] as String? ?? 'Chưa chọn bài', artist: j['artist'] as String? ?? '',
    message: j['message'] as String? ?? '', playing: j['playing'] == true,
    loading: j['loading'] == true, position: (j['position'] as num? ?? 0).toInt(),
    duration: (j['duration'] as num? ?? 0).toInt(), index: (j['index'] as num? ?? 0).toInt(),
    queueCount: (j['queueCount'] as num? ?? (j['queue'] as List?)?.length ?? 0).toInt(),
    playedMs: (j['playedMs'] as num? ?? 0).toInt(), videoSafe: j['videoSafe'] == true,
    videoRequested: j['videoRequested'] == true, videoVisible: j['videoVisible'] == true,
    hasVideo: j['hasVideo'] == true, carConnected: j['carConnected'] == true,
    aspect: (j['videoAspect'] as num? ?? 16/9).toDouble());
  bool get isExternal => source == 'external';
  bool get isPlaying => isExternal ? external['playing'] == true : playing;
  String get displayTitle => isExternal ? external['title'] as String? ?? 'Chưa có bài đang phát' : title;
  String get displayArtist => isExternal ? external['artist'] as String? ?? '' : artist;
  String get app => isExternal ? external['app'] as String? ?? 'Ứng dụng nhạc' : 'YouTube';
  int get positionMs => isExternal ? (external['position'] as num? ?? 0).toInt() : position;
  int get durationMs => isExternal ? (external['duration'] as num? ?? 0).toInt() : duration;
  bool hasAction(int flag) => ((external['actions'] as num? ?? 0).toInt() & flag) != 0;
  bool get canPlay => isExternal ? external['available'] == true && (hasAction(isPlaying ? 2 : 4) || hasAction(512)) : queueCount > 0;
  bool get canPrevious => isExternal ? hasAction(16) : index > 0 || position > 3000;
  bool get canNext => isExternal ? hasAction(32) : index + 1 < queueCount;
  bool get canSeek => durationMs > 0 && (isExternal ? hasAction(256) : !loading);
  Uint8List? get artwork {
    final raw = external['art'];
    if (raw is! String || raw.length > 150000) return null;
    try { return base64Decode(raw); } catch (_) { return null; }
  }
}

String mediaTime(int milliseconds) {
  final seconds = milliseconds.clamp(0, 864000000) ~/ 1000;
  return '${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2,'0')}';
}
