import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:taxi_driver_aa_dashboard/features/media/youtube_probe.dart';

void main() {
  final uri = Uri.parse('https://sample.googlevideo.com/videoplayback');
  test(
    'Selected media probe requires real media bytes and uses bounded range',
    () async {
      var calls = 0;
      final client = MockClient((request) async {
        calls++;
        expect(request.headers['Range'], 'bytes=0-2047');
        expect(request.headers['User-Agent'], 'Mozilla/5.0');
        return http.Response.bytes(
          [0, 0, 0, 24],
          206,
          headers: {'content-type': 'audio/mp4'},
        );
      });
      expect(await probeYoutubeMedia(uri, client: client), true);
      expect(calls, 1);
    },
  );
  test(
    '403, HTML challenges and empty media do not become playable sources',
    () async {
      for (final response in [
        http.Response('Forbidden', 403),
        http.Response('Sign in', 200, headers: {'content-type': 'text/html'}),
        http.Response('', 206, headers: {'content-type': 'audio/mp4'}),
      ]) {
        expect(
          await probeYoutubeMedia(
            uri,
            client: MockClient((_) async => response),
          ),
          false,
        );
      }
      var reached = false;
      expect(
        await probeYoutubeMedia(
          Uri.parse('https://example.com/a'),
          client: MockClient((_) async {
            reached = true;
            return http.Response('a', 200);
          }),
        ),
        false,
      );
      expect(reached, false);
    },
  );
}
