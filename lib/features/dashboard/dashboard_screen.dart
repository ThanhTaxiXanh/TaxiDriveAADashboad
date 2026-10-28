import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import '../../core/car_bridge.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key, this.preview = false});
  final bool preview;
  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  StreamSubscription<Map<String, dynamic>>? subscription;
  Timer? animation;
  Timer? reporting;
  final watch = Stopwatch();
  int frames = 0;
  int tick = 0;
  int taps = 0;
  EdgeInsets padding = EdgeInsets.zero;

  void timings(List<FrameTiming> values) => frames += values.length;

  @override
  void initState() {
    super.initState();
    if (widget.preview) return;
    subscription = CarBridge.watch().listen((data) {
      final rect = data['visible'] as List?;
      if (rect != null && mounted) {
        final ratio = View.of(context).devicePixelRatio;
        setState(() => padding = EdgeInsets.fromLTRB(
          (rect[0] as num).toDouble() / ratio,
          (rect[1] as num).toDouble() / ratio,
          (rect[2] as num).toDouble() / ratio,
          (rect[3] as num).toDouble() / ratio,
        ));
      }
    });
    WidgetsBinding.instance.addTimingsCallback(timings);
    watch.start();
    // Animation volontaire à ~30 Hz pour mesurer un rendu actif.
    animation = Timer.periodic(const Duration(milliseconds: 33), (_) {
      if (mounted) setState(() => tick++);
    });
    reporting = Timer.periodic(const Duration(seconds: 5), (_) async {
      final count = frames;
      final elapsed = watch.elapsedMilliseconds;
      frames = 0;
      watch.reset();
      await CarBridge.reportFrames(count, elapsed);
    });
  }

  @override
  void dispose() {
    subscription?.cancel();
    animation?.cancel();
    reporting?.cancel();
    WidgetsBinding.instance.removeTimingsCallback(timings);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Padding(
      padding: padding + const EdgeInsets.all(16),
      child: LayoutBuilder(builder: (context, size) {
        return SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: size.maxHeight),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.local_taxi, size: 48, color: Color(0xff41d7b0)),
                const Text('Thanh Taxi Xanh', style: TextStyle(fontSize: 28)),
                const Text('Thử nghiệm Android Auto · Giai đoạn 0',
                    textAlign: TextAlign.center, style: TextStyle(fontSize: 18)),
                const Text('Tiếng Việt: Âm lịch · Đường phố · Nguyễn',
                    textAlign: TextAlign.center, style: TextStyle(fontSize: 18)),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () => setState(() => taps++),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Text('Chạm thử: $taps', style: const TextStyle(fontSize: 24)),
                  ),
                ),
                const SizedBox(height: 16),
                LinearProgressIndicator(value: (tick % 90) / 90),
                const SizedBox(height: 8),
                Text(widget.preview ? 'Xem trước trên điện thoại' : 'Nhịp vẽ: $tick',
                    style: const TextStyle(fontSize: 16)),
              ],
            ),
          ),
        );
      }),
    ),
  );
}
