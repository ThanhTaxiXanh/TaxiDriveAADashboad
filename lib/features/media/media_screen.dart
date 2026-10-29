import 'dart:async';

import 'package:flutter/material.dart';

import '../navigation/nav_controller.dart';
import 'media_controller.dart';
import 'media_models.dart';
import 'media_panel.dart';

class MediaScreen extends StatelessWidget {
  const MediaScreen({
    super.key,
    required this.controller,
    required this.navigation,
  });
  final MediaController controller;
  final NavController navigation;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Nhạc và YouTube')),
    body: ListenableBuilder(
      listenable: controller,
      builder: (context, _) => ListView(
        padding: const EdgeInsets.all(16),
        children: [
          DropdownButtonFormField<String>(
            key: ValueKey(controller.state.source),
            initialValue: controller.state.source,
            decoration: const InputDecoration(
              labelText: 'Nguồn điều khiển hàng Media',
            ),
            items: const [
              DropdownMenuItem(
                value: 'external',
                child: Text('Ứng dụng nhạc đang chạy'),
              ),
              DropdownMenuItem(
                value: 'youtube',
                child: Text('YouTube trong Taxi Xanh'),
              ),
            ],
            onChanged: (v) => unawaited(controller.chooseSource(v!)),
          ),
          if (controller.state.isExternal) ...[
            if (controller.state.external['permission'] != true) ...[
              const Text(
                'Để xem bài và điều khiển app nhạc khác, bật Truy cập thông báo cho Taxi Xanh. Ứng dụng chỉ dùng quyền này để lấy MediaSession; không đọc nội dung thông báo.',
              ),
              FilledButton(
                onPressed: () =>
                    unawaited(controller.call('notificationSettings')),
                child: const Text('Mở Truy cập thông báo'),
              ),
              const Text(
                'Nếu Android 13 trên Xiaomi chặn quyền cho APK cài ngoài: mở Thông tin ứng dụng → menu ⋮ → Cho phép cài đặt bị hạn chế, rồi bật lại Truy cập thông báo.',
              ),
            ],
            OutlinedButton(
              onPressed: () => unawaited(controller.call('refresh')),
              child: const Text('Làm mới ứng dụng nhạc'),
            ),
            if ((controller.state.external['sessions'] as List? ?? [])
                .isNotEmpty)
              DropdownButtonFormField<String>(
                key: ValueKey(controller.state.external['selected']),
                initialValue: controller.state.external['selected'] as String,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Ứng dụng đang điều khiển',
                ),
                items: [
                  for (final session in controller.state.external['sessions'])
                    DropdownMenuItem<String>(
                      value: session['id'] as String,
                      child: Text(
                        session['name'] as String,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
                onChanged: (v) =>
                    unawaited(controller.call('chooseSession', {'id': v})),
              ),
            SizedBox(height: 240, child: MediaPanel(controller: controller)),
            const Text(
              'Mở app nhạc và phát một bài trước. Nút chỉ sáng khi app đó công bố hỗ trợ lệnh tương ứng.',
            ),
          ],
          if (controller.message != null) Text(controller.message!),
          const Divider(),
          SizedBox(
            height: 780,
            child: YoutubePanel(
              controller: controller,
              car: false,
              navigation: navigation,
            ),
          ),
        ],
      ),
    ),
  );
}

class YoutubePanel extends StatefulWidget {
  const YoutubePanel({
    super.key,
    required this.controller,
    required this.car,
    this.navigation,
    this.onClose,
  });
  final MediaController controller;
  final NavController? navigation;
  final bool car;
  final VoidCallback? onClose;
  @override
  State<YoutubePanel> createState() => _YoutubePanelState();
}

class _YoutubePanelState extends State<YoutubePanel> {
  final query = TextEditingController();
  List<MediaEntry> results = const [];
  int tab = 0, generation = 0;
  bool busy = false;
  String? error;
  MediaController get media => widget.controller;
  Future<void> search({bool link = false}) async {
    if (widget.car || busy) return;
    final token = ++generation;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      if (link) {
        final collection = await media.provider.load(query.text);
        if (!mounted || token != generation) return;
        await media.save(collection);
        if (mounted) setState(() => tab = 1);
      } else {
        final found = await media.provider.search(query.text);
        if (mounted && token == generation) setState(() => results = found);
      }
    } catch (_) {
      if (mounted && token == generation)
        setState(
          () => error = 'Chưa lấy được nội dung YouTube. Kiểm tra liên kết, mạng hoặc thử lại',
        );
    } finally {
      if (mounted && token == generation) setState(() => busy = false);
    }
  }

  Future<void> saveEntry(MediaEntry entry) =>
      media.save(MediaCollection('video_${entry.id}', entry.title, [entry]));
  @override
  void dispose() {
    generation++;
    query.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: media,
    builder: (context, _) {
      final s = media.state;
      final showVideo =
          s.videoRequested &&
          s.videoSafe &&
          s.hasVideo &&
          (!s.carConnected || widget.car);
      return Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'YouTube',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                ),
                if (widget.onClose != null)
                  IconButton(
                    tooltip: 'Về bảng điều khiển',
                    onPressed: widget.onClose,
                    icon: const Icon(Icons.close),
                  ),
              ],
            ),
            Expanded(
              child: ListView(
                children: [
                  if (showVideo)
                    AspectRatio(
                      aspectRatio: s.aspect.isFinite && s.aspect > 0
                          ? s.aspect
                          : 16 / 9,
                      child: NativeMediaVideo(controller: media),
                    ),
                  if (!s.isExternal) ...[
                    Text(
                      s.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    MediaControls(controller: media, state: s),
                    MediaProgress(controller: media, state: s),
                    Text(s.message, style: const TextStyle(fontSize: 16)),
                  Text('Thời gian phát thực: ${mediaTime(s.playedMs)}', style: const TextStyle(fontSize: 16)),
                    if (s.loading) const LinearProgressIndicator(),
                    Wrap(
                      spacing: 4,
                      children: [
                        OutlinedButton.icon(
                          onPressed: s.hasVideo && s.videoSafe
                              ? () => unawaited(media.video(!s.videoRequested))
                              : null,
                          icon: Icon(
                            s.videoRequested
                                ? Icons.videocam_off
                                : Icons.videocam,
                          ),
                          label: Text(
                            s.videoRequested ? 'Ẩn video' : 'Xem video khi đỗ',
                          ),
                        ),
                        TextButton(
                          onPressed: () => unawaited(media.command('stop')),
                          child: const Text('Dừng'),
                        ),
                      ],
                    ),
                    if (!s.videoSafe)
                      const Text(
                        'Chỉ phát âm thanh. Video cần GPS mới, chính xác và tốc độ dưới 5 km/h.',
                        style: TextStyle(fontSize: 16),
                      ),
                  ],
                  if (!widget.car) ...[
                    OutlinedButton(
                      onPressed: () => unawaited(
                        widget.navigation?.locate().catchError((Object _) {}),
                      ),
                      child: const Text('Bật vị trí để xác nhận xe đang đỗ'),
                    ),
                    TextField(
                      controller: query,
                      maxLength: 200,
                      decoration: const InputDecoration(
                        labelText:
                            'Tìm video hoặc dán liên kết YouTube / playlist',
                      ),
                      onSubmitted: (_) => unawaited(search()),
                    ),
                    Wrap(
                      spacing: 8,
                      children: [
                        FilledButton(
                          onPressed: busy ? null : () => unawaited(search()),
                          child: const Text('Tìm video'),
                        ),
                        OutlinedButton(
                          onPressed: busy
                              ? null
                              : () => unawaited(search(link: true)),
                          child: const Text('Lưu liên kết / playlist'),
                        ),
                      ],
                    ),
                    if (busy) const LinearProgressIndicator(),
                    if (error != null) Text(error!),
                    for (final entry in results)
                      Card(
                        child: Column(
                          children: [
                            ListTile(
                              title: Text(
                                entry.title,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              subtitle: Text(
                                entry.author,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Wrap(
                              children: [
                                TextButton(
                                  onPressed: () => unawaited(
                                    media.playEntries(
                                      results,
                                      index: results.indexOf(entry),
                                    ),
                                  ),
                                  child: const Text('Phát từ đây'),
                                ),
                                TextButton(
                                  onPressed: () => unawaited(saveEntry(entry)),
                                  child: const Text('Lưu yêu thích'),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                  ],
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        for (final item in [
                          (0, 'Yêu thích'),
                          (1, 'Danh sách'),
                          (2, 'Gần đây'),
                        ])
                          Padding(
                            padding: const EdgeInsets.only(right: 4),
                            child: ChoiceChip(
                              label: Text(item.$2),
                              selected: tab == item.$1,
                              onSelected: (_) => setState(() => tab = item.$1),
                            ),
                          ),
                      ],
                    ),
                  ),
                  if (tab < 2) ...[
                    for (final collection in media.library.where(
                      (c) => tab == 1 || c.favorite,
                    ))
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(8),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(
                                collection.title,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Text(
                                '${collection.entries.length} bài · ${mediaTime(collection.entries.fold<int>(0, (total, e) => total + e.duration))}',
                                style: const TextStyle(fontSize: 16),
                              ),
                              Wrap(
                                children: [
                                  FilledButton(
                                    onPressed: () => unawaited(
                                      media.playSaved(collection.id),
                                    ),
                                    child: const Text('Phát'),
                                  ),
                                  if (!widget.car) ...[
                                    IconButton(
                                      tooltip: collection.favorite
                                          ? 'Bỏ yêu thích'
                                          : 'Yêu thích',
                                      onPressed: () => unawaited(
                                        media.save(
                                          MediaCollection(
                                            collection.id,
                                            collection.title,
                                            collection.entries,
                                            favorite: !collection.favorite,
                                          ),
                                        ),
                                      ),
                                      icon: Icon(
                                        collection.favorite
                                            ? Icons.star
                                            : Icons.star_border,
                                      ),
                                    ),
                                    IconButton(
                                      tooltip: 'Xóa danh sách',
                                      onPressed: () => unawaited(
                                        media.remove(collection.id),
                                      ),
                                      icon: const Icon(Icons.delete_outline),
                                    ),
                                  ],
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    if (media.library.isEmpty)
                      const Padding(
                        padding: EdgeInsets.all(8),
                        child: Text(
                          'Tìm và lưu bài hoặc playlist trên điện thoại. Danh sách sẽ hiện ở đây.',
                          style: TextStyle(fontSize: 16),
                        ),
                      ),
                  ] else ...[
                    for (final entry in media.recent)
                      Card(
                        child: TextButton(
                          onPressed: () => unawaited(media.playSaved(entry.id)),
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              entry.title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 18),
                            ),
                          ),
                        ),
                      ),
                  ],
                  if (!widget.car)
                    const Padding(
                      padding: EdgeInsets.only(top: 12),
                      child: Text(
                        'Nội dung công khai, không đăng nhập tài khoản. Luồng YouTube có thể bị chặn hoặc thay đổi. Danh sách lưu riêng trong máy; phát cần mạng.',
                        style: TextStyle(fontSize: 16),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      );
    },
  );
}

class NativeMediaVideo extends StatefulWidget {
  const NativeMediaVideo({super.key, required this.controller});
  final MediaController controller;
  @override
  State<NativeMediaVideo> createState() => _NativeMediaVideoState();
}

class _NativeMediaVideoState extends State<NativeMediaVideo> {
  final lease = DateTime.now().microsecondsSinceEpoch.toString();
  int? texture;
  @override
  void initState() {
    super.initState();
    unawaited(create());
  }

  Future<void> create() async {
    try {
      final id = await MediaController.methods.invokeMethod<int>(
        'createTexture',
        {'lease': lease},
      );
      if (mounted)
        setState(() => texture = id);
      else
        await MediaController.methods.invokeMethod('releaseTexture', {
          'lease': lease,
        });
    } catch (_) {}
  }

  @override
  void dispose() {
    unawaited(
      MediaController.methods
          .invokeMethod('releaseTexture', {'lease': lease})
          .catchError((Object _) {}),
    );
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: Colors.black,
    child: texture == null
        ? const Center(
            child: Text(
              'Đang mở video',
              style: TextStyle(color: Colors.white, fontSize: 16),
            ),
          )
        : Texture(textureId: texture!),
  );
}
