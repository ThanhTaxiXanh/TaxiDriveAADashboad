import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'media_models.dart';
import 'youtube_provider.dart';

class MediaController extends ChangeNotifier {
  MediaController({
    this.connected = true,
    this.car = false,
    this.worker = false,
    YoutubeStreamProvider? provider,
  }) : provider = provider ?? ExplodeStreamProvider() {
    if (connected) {
      subscription = events.receiveBroadcastStream().listen(
        (value) {
          try {
            accept(jsonDecode(value as String) as Map);
          } catch (_) {
            message = 'Chưa đọc được trạng thái nhạc';
            notify();
          }
        },
        onError: (Object _) {
          message = 'Cầu nối nhạc tạm ngắt';
          notify();
        },
      );
      unawaited(reload());
    }
  }
  static const methods = MethodChannel('taxi/media');
  static const events = EventChannel('taxi/media/events');
  final bool connected, car, worker;
  final YoutubeStreamProvider provider;
  StreamSubscription<dynamic>? subscription;
  MediaSnapshot state = const MediaSnapshot();
  List<MediaCollection> library = const [];
  List<MediaEntry> recent = const [];
  bool closed = false, busy = false;
  String? message, resolving;
  int revision = -1;
  void notify() {
    if (!closed) notifyListeners();
  }

  void accept(Map j) {
    if (closed) return;
    final incoming = (j['revision'] as num?)?.toInt();
    if (incoming != null && incoming < revision) return;
    if (incoming != null) revision = incoming;
    state = MediaSnapshot.fromJson(j);
    if (j['library'] is List)
      library = [
        for (final item in j['library']) MediaCollection.fromJson(item as Map),
      ];
    if (j['recent'] is List)
      recent = [
        for (final item in j['recent']) MediaEntry.fromJson(item as Map),
      ];
    notify();
    final request = j['request'];
    if (worker &&
        j.containsKey('request') &&
        request == null &&
        resolving != null) {
      resolving = null;
      if (provider is ExplodeStreamProvider)
        (provider as ExplodeStreamProvider).cancelResolve();
    }
    if (worker && request is Map && request['token'] != resolving) {
      resolving = request['token'] as String;
      unawaited(
        resolve(resolving!, MediaEntry.fromJson(request['entry'] as Map)),
      );
    }
  }

  Future<void> resolve(String token, MediaEntry entry) async {
    try {
      final streams = await provider.resolve(entry.id);
      if (!closed)
        await methods.invokeMethod('resolved', {
          'token': token,
          'audio': streams.audio.toString(),
          'video': streams.video?.toString(),
        });
    } catch (_) {
      if (!closed)
        await methods
            .invokeMethod('resolved', {'token': token, 'failed': true})
            .catchError((Object _) {});
    }
  }

  Future<void> reload() async {
    try {
      final raw = await methods.invokeMethod<String>('snapshot');
      if (raw != null && !closed) accept(jsonDecode(raw) as Map);
    } catch (_) {
      if (!closed) {
        message = 'Chưa kết nối trình phát';
        notify();
      }
    }
  }

  Future<void> call(String name, [Map<String, dynamic>? args]) async {
    if (closed || !connected) return;
    try {
      await methods.invokeMethod(name, args);
      message = null;
    } on PlatformException catch (error) {
      message = error.code == 'MEDIA_LIMIT'
          ? 'Đã đủ 60 danh sách. Xóa bớt trước khi lưu thêm'
          : 'Chưa thực hiện được. Kiểm tra quyền hoặc thử lại';
    } catch (_) {
      message = 'Chưa thực hiện được. Kiểm tra quyền hoặc thử lại';
    }
    notify();
  }

  Future<void> command(String action, [int position = 0]) =>
      call('command', {'action': action, 'position': position});
  Future<void> chooseSource(String source) =>
      call('chooseSource', {'source': source});
  Future<void> playSaved(String id) => call('playSaved', {'id': id});
  Future<void> playEntries(List<MediaEntry> entries, {int index = 0}) {
    if (car) return Future.value();
    return call('playQueue', {
      'json': jsonEncode(entries.map((e) => e.toJson()).toList()),
      'index': index,
    });
  }

  Future<void> save(MediaCollection collection) => car
      ? Future.value()
      : call('saveCollection', {'json': jsonEncode(collection.toJson())});
  Future<void> remove(String id) =>
      car ? Future.value() : call('deleteCollection', {'id': id});
  Future<void> video(bool value) => call('video', {'enabled': value});
  @override
  void dispose() {
    closed = true;
    subscription?.cancel();
    if (provider is ExplodeStreamProvider)
      (provider as ExplodeStreamProvider).cancelResolve();
    super.dispose();
  }
}

MediaController? _resolver;
void startMediaResolver() {
  _resolver ??= MediaController(worker: true);
}
