import 'dart:convert';
import 'dart:io';

import 'package:youtube_explode_dart/youtube_explode_dart.dart';

// Public Blender fixture only. Never print signed stream URLs or exceptions.
Future<void> main() async {
  final yt = YoutubeExplode();
  final report = <String,dynamic>{'provider':'youtube_explode_dart 3.1.0','fixture':'Big Buck Bunny / Blender Foundation','result':'unverified'};
  try {
    final manifest = await yt.videos.streams.getManifest('aqz-KE-bpKQ').timeout(const Duration(seconds:40));
    final audio = manifest.audioOnly.first;
    final bytes = await yt.videos.streams.get(audio).first.timeout(const Duration(seconds:15));
    report.addAll({'result': bytes.isNotEmpty ? 'stream_read' : 'empty','audio_streams':manifest.audioOnly.length,'video_streams':manifest.videoOnly.length,'bytes_read':bytes.length});
  } catch (_) { report['result']='network_or_extractor_unverified'; }
  finally { yt.close(); }
  final output = File('build/youtube-spike.json');
  await output.parent.create(recursive:true);
  await output.writeAsString(const JsonEncoder.withIndent('  ').convert(report));
  stdout.writeln('YOUTUBE_SPIKE ${jsonEncode(report)}');
}
