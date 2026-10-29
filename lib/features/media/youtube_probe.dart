import 'dart:async';

import 'package:http/http.dart' as http;

// Streamed response, closed after the first media bytes. Do not buffer an
// entire video if a server ignores Range. The player uses the same User-Agent.
Future<bool> probeYoutubeMedia(Uri uri, {http.Client? client}) async {
  final httpClient = client ?? http.Client();
  try {
    if (uri.scheme != 'https' || !uri.host.endsWith('.googlevideo.com'))
      return false;
    return await (() async {
      final response = await httpClient.send(
        http.Request('GET', uri)
          ..headers.addAll({
            'Range': 'bytes=0-2047',
            'User-Agent': 'Mozilla/5.0',
          }),
      );
      if (response.statusCode != 200 && response.statusCode != 206)
        return false;
      final type = (response.headers['content-type'] ?? '').toLowerCase();
      if (!type.startsWith('audio/') &&
          !type.startsWith('video/') &&
          !type.startsWith('application/octet-stream'))
        return false;
      return (await response.stream.first).isNotEmpty;
    })().timeout(const Duration(seconds: 3));
  } catch (_) {
    return false;
  } finally {
    httpClient.close();
  }
}
