import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taxi_driver_aa_dashboard/core/layout_config.dart';
import 'package:taxi_driver_aa_dashboard/features/dashboard/dashboard_screen.dart';
import 'package:taxi_driver_aa_dashboard/features/media/media_controller.dart';
import 'package:taxi_driver_aa_dashboard/features/media/media_models.dart';
import 'package:taxi_driver_aa_dashboard/features/media/media_panel.dart';
import 'package:taxi_driver_aa_dashboard/features/media/media_screen.dart';
import 'package:taxi_driver_aa_dashboard/features/media/youtube_provider.dart';

class FakeYoutubeProvider implements YoutubeStreamProvider {
  final pending = <String, Completer<YoutubeStreams>>{};
  int calls = 0;
  @override
  Future<YoutubeStreams> resolve(String id) {
    calls++;
    return (pending[id] ??= Completer<YoutubeStreams>()).future;
  }

  @override
  Future<List<MediaEntry>> search(String query) async => const [];
  @override
  Future<MediaCollection> load(String input) async =>
      const MediaCollection('test', 'Test', []);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const entry = {
    'id': 'aqz-KE-bpKQ',
    'title': 'Video mẫu công khai',
    'author': 'Blender Foundation',
    'duration': 600000,
  };
  test('External controls follow advertised actions and source selection', () {
    final state = MediaSnapshot.fromJson({
      'external': {
        'available': true,
        'actions': 4 + 16 + 256,
        'duration': 60000,
        'position': 12000,
        'playing': false,
      },
    });
    expect(state.canPlay, true);
    expect(state.canPrevious, true);
    expect(state.canNext, false);
    expect(state.canSeek, true);
    expect(state.positionMs, 12000);
    expect(mediaTime(state.positionMs), '0:12');
    final internal = MediaSnapshot.fromJson({
      'source': 'youtube',
      'queueCount': 3,
      'index': 1,
      'duration': 60000,
      'position': 5000,
      'loading': true,
    });
    expect(internal.canNext, true);
    expect(internal.canPrevious, true);
    expect(internal.canSeek, false);
  });
  testWidgets(
    'Only resolver worker extracts once per token; metadata survives partial events',
    (tester) async {
      final calls = <MethodCall>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        MediaController.methods,
        (call) async {
          calls.add(call);
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          MediaController.methods,
          null,
        ),
      );
      final provider = FakeYoutubeProvider();
      final worker = MediaController(
        connected: false,
        worker: true,
        provider: provider,
      );
      final ui = MediaController(connected: false, provider: provider);
      addTearDown(worker.dispose);
      addTearDown(ui.dispose);
      final event = {
        'source': 'youtube',
        'request': {'token': 'one', 'entry': entry},
        'library': [
          {
            'id': 'video_aqz-KE-bpKQ',
            'title': 'Danh sách',
            'entries': [entry],
          },
        ],
      };
      ui.accept(event);
      worker.accept(event);
      worker.accept(event);
      expect(provider.calls, 1);
      worker.accept({'source': 'youtube', 'position': 500});
      expect(worker.library.single.entries.single.id, 'aqz-KE-bpKQ');
      provider.pending['aqz-KE-bpKQ']!.complete(
        YoutubeStreams(Uri.parse('https://test.googlevideo.com/audio'), null),
      );
      await tester.pump();
      expect(calls.where((c) => c.method == 'resolved'), hasLength(1));
      expect((calls.last.arguments as Map)['token'], 'one');
    },
  );
  testWidgets(
    'Older cross-channel snapshot cannot replace a newer track request',
    (tester) async {
      final provider = FakeYoutubeProvider();
      final worker = MediaController(
        connected: false,
        worker: true,
        provider: provider,
      );
      worker.accept({
        'revision': 8,
        'request': {'token': 'current', 'entry': entry},
        'source': 'youtube',
        'title': 'Current',
      });
      worker.accept({
        'revision': 7,
        'request': {'token': 'old', 'entry': entry},
        'source': 'external',
        'title': 'Old',
      });
      expect(provider.calls, 1);
      expect(worker.state.source, 'youtube');
      expect(worker.state.title, 'Current');
      worker.dispose();
      provider.pending['aqz-KE-bpKQ']!.complete(
        YoutubeStreams(Uri.parse('https://test.googlevideo.com/a'), null),
      );
      await tester.pump();
    },
  );
  testWidgets(
    'Extractor error reports no private URL or exception; disposed worker sends nothing',
    (tester) async {
      final calls = <MethodCall>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        MediaController.methods,
        (call) async {
          calls.add(call);
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          MediaController.methods,
          null,
        ),
      );
      final provider = FakeYoutubeProvider();
      final worker = MediaController(
        connected: false,
        worker: true,
        provider: provider,
      );
      worker.accept({
        'request': {'token': 'failed', 'entry': entry},
      });
      provider.pending['aqz-KE-bpKQ']!.completeError(
        StateError('private stream detail'),
      );
      await tester.pump();
      expect(calls.single.arguments, {'token': 'failed', 'failed': true});
      worker.dispose();
      final next = FakeYoutubeProvider();
      final stopped = MediaController(
        connected: false,
        worker: true,
        provider: next,
      );
      stopped.accept({
        'request': {'token': 'closed', 'entry': entry},
      });
      stopped.dispose();
      next.pending['aqz-KE-bpKQ']!.complete(
        YoutubeStreams(Uri.parse('https://test.googlevideo.com/audio'), null),
      );
      await tester.pump();
      expect(calls, hasLength(1));
    },
  );
  for (final height in [50.0, 64.0, 110.0, 180.0, 260.0]) {
    for (final scale in [1.0,1.6]) {
    testWidgets('Media row fits 194 px width and height $height at scale $scale', (
      tester,
    ) async {
      final controller = MediaController(connected: false);
      addTearDown(controller.dispose);
      controller.accept({
        'source': 'external',
        'external': {
          'available': true,
          'actions': 4 + 16 + 32 + 256,
          'title': 'Tên bài hát tiếng Việt khá dài để thử bố cục',
          'artist': 'Nghệ sĩ mẫu',
          'duration': 180000,
          'position': 12000,
        },
      });
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 194,
                height: height,
                child: MediaPanel(controller: controller, fontScale: scale),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(find.byTooltip('Bài trước'), findsOneWidget);
      expect(find.byTooltip('Bài tiếp'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    });
  }
  }
  testWidgets(
    'Moving/stale GPS keeps video texture absent and car has no search field',
    (tester) async {
      final calls = <MethodCall>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        MediaController.methods,
        (call) async {
          calls.add(call);
          return 77;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          MediaController.methods,
          null,
        ),
      );
      final media = MediaController(connected: false);
      addTearDown(media.dispose);
      media.accept({
        'source': 'youtube',
        'hasVideo': true,
        'videoRequested': true,
        'videoSafe': false,
        'queueCount': 1,
      });
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: YoutubePanel(controller: media, car: true)),
        ),
      );
      await tester.pump();
      expect(find.byType(TextField), findsNothing);
      expect(find.byType(NativeMediaVideo), findsNothing);
      expect(calls.where((c) => c.method == 'createTexture'), isEmpty);
      media.accept({
        'source': 'youtube',
        'hasVideo': true,
        'videoRequested': true,
        'videoSafe': true,
        'queueCount': 1,
        'carConnected': true,
      });
      await tester.pump();
      await tester.pump();
      expect(find.byType(NativeMediaVideo), findsOneWidget);
      expect(calls.where((c) => c.method == 'createTexture'), hasLength(1));
      media.accept({
        'source': 'youtube',
        'hasVideo': true,
        'videoRequested': false,
        'videoSafe': false,
        'queueCount': 1,
      });
      await tester.pump();
      await tester.pump();
      expect(find.byType(NativeMediaVideo), findsNothing);
      expect(calls.where((c) => c.method == 'releaseTexture'), hasLength(1));
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'YouTube right panel remains available with all dashboard rows off',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DashboardFrame(
              config: LayoutConfig(rowEnabled: [false, false, false]),
              map: const Text('Bản đồ vẫn hiện'),
              rightPanel: const Text('Danh sách đã lưu'),
            ),
          ),
        ),
      );
      expect(find.text('Bản đồ vẫn hiện'), findsOneWidget);
      expect(find.text('Danh sách đã lưu'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
