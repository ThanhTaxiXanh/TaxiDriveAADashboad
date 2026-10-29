import 'dart:convert';
import 'dart:io';

import 'package:youtube_explode_dart/youtube_explode_dart.dart';

// Public Blender fixture only. Never print signed URLs or exception messages.
Future<void> main() async {
  final attempts = <Map<String, dynamic>>[];
  for (final option in [
    ('sdkless', YoutubeApiClient.androidSdkless, true),
    ('sdkless_direct', YoutubeApiClient.androidSdkless, false),
    ('androidVr_direct', YoutubeApiClient.androidVr, false),
  ]) {
    final yt = YoutubeExplode();
    final report = <String, dynamic>{
      'client': option.$1,
      'result': 'unverified',
    };
    try {
      final manifest = await yt.videos.streams
          .getManifest(
            'aqz-KE-bpKQ',
            ytClients: [option.$2],
            requireWatchPage: option.$3,
          )
          .timeout(const Duration(seconds: 20));
      report.addAll({
        'audio_streams': manifest.audioOnly.length,
        'video_streams': manifest.videoOnly.length,
      });
      final bytes = await yt.videos.streams
          .get(manifest.audioOnly.first)
          .first
          .timeout(const Duration(seconds: 10));
      report.addAll({
        'result': bytes.isNotEmpty ? 'stream_read' : 'empty',
        'bytes_read': bytes.length,
      });
    } catch (error) {
      final text = error.toString().toLowerCase();
      report['result'] =
          text.contains('403') ||
              text.contains('429') ||
              text.contains('sign in') ||
              text.contains('bot')
          ? 'server_or_client_rejected'
          : text.contains('solver') || text.contains('challenge')
          ? 'challenge_required'
          : 'unverified';
      report['error_type'] = error.runtimeType.toString();
    } finally {
      yt.close();
    }
    attempts.add(report);
  }
  final report = {
    'provider': 'youtube_explode_dart 3.1.0',
    'fixture': 'Big Buck Bunny / Blender Foundation',
    'attempts': attempts,
  };
  final output = File('build/youtube-spike.json');
  await output.parent.create(recursive: true);
  await output.writeAsString(
    const JsonEncoder.withIndent('  ').convert(report),
  );
  stdout.writeln('YOUTUBE_SPIKE ${jsonEncode(report)}');
}
