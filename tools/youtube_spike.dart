import 'dart:convert';
import 'dart:io';

import '../lib/features/media/youtube_provider.dart';

// Only public Blender fixtures. Never print signed URLs or exception messages.
Future<void> main() async {
  final attempts = <Map<String, dynamic>>[];
  for (final fixture in ['aqz-KE-bpKQ', 'YE7VzlLtp-4']) {
    final provider = ExplodeStreamProvider();
    final report = <String, dynamic>{
      'fixture': fixture,
      'result': 'unverified',
    };
    try {
      final streams = await provider
          .resolve(fixture)
          .timeout(const Duration(seconds: 43));
      report.addAll({
        'result': 'selected_media_bytes_read',
        'client': streams.client,
        'muxed': streams.muxed,
        'has_video': streams.video != null || streams.muxed,
      });
    } catch (_) {
      report['result'] = 'no_reachable_selected_stream';
    } finally {
      provider.cancelResolve();
    }
    attempts.add(report);
    if (report['result'] == 'selected_media_bytes_read') break;
  }
  final report = {
    'provider': 'youtube_explode_dart 3.1.0 + compatibility clients',
    'attempts': attempts,
  };
  final output = File('build/youtube-spike.json');
  await output.parent.create(recursive: true);
  await output.writeAsString(
    const JsonEncoder.withIndent('  ').convert(report),
  );
  stdout.writeln('YOUTUBE_SPIKE ${jsonEncode(report)}');
}
