import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';
import '../../core/car_bridge.dart';
import 'package:flutter/material.dart';
import '../../core/dashboard_controller.dart';
import '../../core/layout_config.dart';
import '../../modules/dashboard_module.dart';
import '../settings/layout_settings.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key, required this.controller, this.car = false});
  final DashboardController controller;
  final bool car;
  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}
class _DashboardScreenState extends State<DashboardScreen> {
  final modules = DashboardModules();
  Timer? clock;
  Timer? reporting;
  final watch = Stopwatch();
  int frames = 0;
  void timings(List<FrameTiming> batch) => frames += batch.length;
  @override
  void initState() { super.initState();
    if (widget.car) {
      WidgetsBinding.instance.addTimingsCallback(timings);
      watch.start();
      reporting = Timer.periodic(const Duration(seconds: 5), (_) { CarBridge.reportFrames(frames, watch.elapsedMilliseconds); frames = 0; watch.reset(); });
    }
    clock = Timer.periodic(const Duration(minutes: 1), (_) { if (mounted) setState(() {}); }); }
  @override
  void dispose() { clock?.cancel(); reporting?.cancel(); if (widget.car) WidgetsBinding.instance.removeTimingsCallback(timings); super.dispose(); }
  @override
  Widget build(BuildContext context) => ListenableBuilder(listenable: widget.controller, builder: (context, _) => buildBody(context));
  Widget buildBody(BuildContext context) {
    final controller = widget.controller;
    final rect = widget.car ? controller.diagnostics['visible'] as List? : null;
    final ratio = View.of(context).devicePixelRatio;
    final padding = rect == null ? EdgeInsets.zero : EdgeInsets.fromLTRB((rect[0] as num).toDouble() / ratio, (rect[1] as num).toDouble() / ratio, (rect[2] as num).toDouble() / ratio, (rect[3] as num).toDouble() / ratio);
    return Scaffold(
      appBar: widget.car ? null : AppBar(title: const Text('Xem trước bố cục')),
      body: Padding(padding: padding, child: switch (controller.panel) {
        'settings' => LayoutSettings(controller: controller, car: widget.car),
        'youtube' => Center(child: Column(mainAxisSize: MainAxisSize.min, children: [const Icon(Icons.play_circle_outline, size: 56), const Text('YouTube · Giai đoạn 6', style: TextStyle(fontSize: 22)), const Text('Chưa có chức năng phát nhạc hoặc video', style: TextStyle(fontSize: 16)), TextButton(onPressed: () => controller.showPanel('dashboard'), child: const Text('Về bảng điều khiển'))])),
        'modules' => ListView(padding: const EdgeInsets.all(24), children: [const Text('Tính năng mở rộng', style: TextStyle(fontSize: 22)), if (modules.items.isEmpty) const Text('Chưa có module được đăng ký.', style: TextStyle(fontSize: 16)), for (final module in modules.items) ListTile(leading: Icon(module.icon), title: Text(module.title), onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (context) => Scaffold(body: module.buildPanel(context))))), TextButton(onPressed: () => controller.showPanel('dashboard'), child: const Text('Về bảng điều khiển'))]),
        _ => DashboardFrame(config: controller.config),
      }),
      bottomNavigationBar: widget.car ? null : SafeArea(child: Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
        IconButton(tooltip: 'Bảng điều khiển', onPressed: () => controller.showPanel('dashboard'), icon: const Icon(Icons.home)),
        IconButton(tooltip: 'YouTube', onPressed: () => controller.showPanel('youtube'), icon: const Icon(Icons.play_circle)),
        IconButton(tooltip: 'Cài đặt bố cục', onPressed: () => controller.showPanel('settings'), icon: const Icon(Icons.settings)),
        IconButton(tooltip: 'Mở rộng', onPressed: () => controller.showPanel('modules'), icon: const Icon(Icons.add)),
      ])),
    );
  }
}

class DashboardFrame extends StatelessWidget {
  const DashboardFrame({super.key, required this.config});
  final LayoutConfig config;
  @override
  Widget build(BuildContext context) {
    final fractions = config.fractions;
    final enabled = [for (var i = 0; i < 3; i++) if (config.rowEnabled[i]) i];
    final titles = ['Lịch Âm/Dương', 'QR thanh toán', 'Media'];
    final captions = ['Lịch và sự kiện · Giai đoạn 2', 'Chưa có mã thanh toán · Giai đoạn 3', 'Chưa kết nối trình phát · Giai đoạn 6'];
    final icons = [Icons.calendar_month, Icons.qr_code_2, Icons.music_note];
    return Padding(padding: const EdgeInsets.all(8), child: LayoutBuilder(builder: (context, size) {
      final available = math.max(0.0, size.maxWidth - (enabled.isEmpty ? 0 : 8));
      final left = enabled.isEmpty ? available : available * config.leftFraction;
      return Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        SizedBox(width: left, child: Card(key: const ValueKey('map-panel'), margin: EdgeInsets.zero, clipBehavior: Clip.antiAlias, child: Stack(children: [
          const Positioned.fill(child: CustomPaint(painter: _RoadPlaceholder())),
          Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('TAXI XANH', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: math.max(22, 24 * config.fontScale), fontWeight: FontWeight.bold)),
            Text('Khung bố cục · Giai đoạn 1', style: TextStyle(fontSize: math.max(16, 18 * config.fontScale))),
          ])),
          Center(child: Padding(padding: const EdgeInsets.all(12), child: Column(mainAxisSize: MainAxisSize.min, children: [const Icon(Icons.navigation_outlined, size: 56), Text('Ô bản đồ', textAlign: TextAlign.center, style: TextStyle(fontSize: math.max(22, 26 * config.fontScale))), Text('Dẫn đường sẽ có ở Giai đoạn 4', textAlign: TextAlign.center, style: TextStyle(fontSize: math.max(16, 18 * config.fontScale)))]))),
          const Positioned(left: 16, bottom: 16, right: 16, child: Text('Bản đồ giữ chỗ · Không dùng để dẫn đường', style: TextStyle(fontSize: 16))),
        ]))),
        if (enabled.isNotEmpty) ...[const SizedBox(width: 8), Expanded(child: Column(children: [
          for (final i in enabled) Expanded(flex: (fractions[i] * 100000).round(), child: Padding(padding: const EdgeInsets.symmetric(vertical: 4), child: Card(key: ValueKey('row-$i'), margin: EdgeInsets.zero, child: LayoutBuilder(builder: (context, cell) => Padding(padding: const EdgeInsets.all(12), child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
            if (cell.maxHeight > 300) Icon(icons[i], size: 40, color: Theme.of(context).colorScheme.primary),
            Text(titles[i], maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: math.min(math.max(22, 24 * config.fontScale), math.max(22, (cell.maxHeight - 24) / 1.5)), fontWeight: FontWeight.w600)),
            if (cell.maxHeight > 24 + math.max(22, 24 * config.fontScale) * 1.5 + math.max(16, 18 * config.fontScale) * 3) Text(captions[i], maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: math.max(16, 18 * config.fontScale))),
          ]))))))
        ]))],
      ]);
    }));
  }
}
class _RoadPlaceholder extends CustomPainter {
  const _RoadPlaceholder();
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = const Color(0x226c9a96)..strokeWidth = 5..style = PaintingStyle.stroke;
    for (var i = -2; i < 8; i++) {
      final x = i * size.width / 5;
      canvas.drawLine(Offset(x, 0), Offset(x + size.width * .6, size.height), paint);
    }
    for (var i = 1; i < 5; i++) { final y = i * size.height / 5; canvas.drawLine(Offset(0, y), Offset(size.width, y - 60), paint); }
  }
  @override
  bool shouldRepaint(_RoadPlaceholder oldDelegate) => false;
}
