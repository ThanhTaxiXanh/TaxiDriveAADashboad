import 'dart:convert';
import 'dart:math' as math;
import 'package:http/http.dart' as http;
import 'routing_provider.dart';

class MapStyleClient extends http.BaseClient {
  final http.Client inner = http.Client();
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    request.headers['User-Agent'] = navUserAgent;
    final response = await inner
        .send(request)
        .timeout(const Duration(seconds: 15));
    if (!['/styles/liberty', '/styles/dark'].contains(request.url.path) ||
        response.statusCode != 200)
      return response;
    final text = await response.stream.bytesToString().timeout(
      const Duration(seconds: 15),
    );
    final json = jsonDecode(text) as Map;
    for (final layer in json['layers'] as List) {
      if (layer['type'] == 'symbol' &&
          layer['layout'] is Map &&
          layer['layout']['text-field'] != null) {
        final value = layer['layout']['text-size'];
        layer['layout']['text-size'] = value is num ? math.max(16, value) : 18;
      }
    }
    final bytes = utf8.encode(jsonEncode(json));
    return http.StreamedResponse(
      Stream.value(bytes),
      response.statusCode,
      headers: {...response.headers}
        ..remove('content-length')
        ..remove('content-encoding'),
      request: request,
    );
  }

  @override
  void close() {
    inner.close();
    super.close();
  }
}
