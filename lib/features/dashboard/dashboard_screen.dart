import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';

import '../../core/car_bridge.dart';

import 'package:flutter/material.dart';

import '../../core/dashboard_controller.dart';
import '../../core/layout_config.dart';
import '../../modules/dashboard_module.dart';
import '../settings/layout_settings.dart';
import '../calendar/calendar_panel.dart';
import '../calendar/calendar_store.dart';
import '../calendar/event_item.dart';
import '../payment/payment_store.dart';
import '../payment/payment_config.dart';
import '../payment/payment_panel.dart';
import '../navigation/nav_controller.dart';
import '../navigation/map_panel.dart';
import '../media/media_controller.dart';
import '../media/media_panel.dart';
import '../media/media_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({
    super.key,
    required this.controller,
    this.car = false,
    this.calendar,
    this.payment,
    this.navigation,
    this.media,
  });
  final DashboardController controller;
  final bool car;
  final CalendarStore? calendar;
  final PaymentStore? payment;
  final NavController? navigation;
  final MediaController? media;
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
  void initState() {
    super.initState();
    if (widget.car) {
      WidgetsBinding.instance.addTimingsCallback(timings);
      watch.start();
      reporting = Timer.periodic(const Duration(seconds: 5), (_) {
        CarBridge.reportFrames(frames, watch.elapsedMilliseconds);
        frames = 0;
        watch.reset();
      });
    }
    clock = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    clock?.cancel();
    reporting?.cancel();
    if (widget.car) WidgetsBinding.instance.removeTimingsCallback(timings);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: Listenable.merge([
      widget.controller,
      if (widget.calendar != null) widget.calendar!,
      if (widget.payment != null) widget.payment!,
    ]),
    builder: (context, _) => buildBody(context),
  );
  Widget buildBody(BuildContext context) {
    final controller = widget.controller;
    final rect = widget.car ? controller.diagnostics['visible'] as List? : null;
    final ratio = View.of(context).devicePixelRatio;
    final padding = rect == null
        ? EdgeInsets.zero
        : EdgeInsets.fromLTRB(
            (rect[0] as num).toDouble() / ratio,
            (rect[1] as num).toDouble() / ratio,
            (rect[2] as num).toDouble() / ratio,
            (rect[3] as num).toDouble() / ratio,
          );
    return Scaffold(
      appBar: widget.car ? null : AppBar(title: const Text('Xem trước bố cục')),
      body: Padding(
        padding: padding,
        child: switch (controller.panel) {
          'settings' => LayoutSettings(controller: controller, car: widget.car),
          'modules' => ListView(
            padding: const EdgeInsets.all(24),
            children: [
              const Text('Tính năng mở rộng', style: TextStyle(fontSize: 22)),
              if (modules.items.isEmpty)
                const Text(
                  'Chưa có module được đăng ký.',
                  style: TextStyle(fontSize: 16),
                ),
              for (final module in modules.items)
                ListTile(
                  leading: Icon(module.icon),
                  title: Text(module.title),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (context) =>
                          Scaffold(body: module.buildPanel(context)),
                    ),
                  ),
                ),
              TextButton(
                onPressed: () => controller.showPanel('dashboard'),
                child: const Text('Về bảng điều khiển'),
              ),
            ],
          ),
          _ => DashboardFrame(
            config: controller.config,
            map: widget.navigation == null
                ? null
                : MapPanel(navigation: widget.navigation!, car: widget.car),
            payment: widget.payment?.config ?? const PaymentConfig(),
            events: widget.calendar?.events ?? const [],
            showMonthly: widget.calendar?.showMonthly ?? false,
            media: widget.media,
            rightPanel: controller.panel == 'youtube' && widget.media != null
                ? YoutubePanel(
                    controller: widget.media!,
                    car: widget.car,
                    navigation: widget.navigation,
                    onClose: () => controller.showPanel('dashboard'),
                  )
                : null,
          ),
        },
      ),
      bottomNavigationBar: widget.car
          ? null
          : SafeArea(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  IconButton(
                    tooltip: 'Bảng điều khiển',
                    onPressed: () => controller.showPanel('dashboard'),
                    icon: const Icon(Icons.home),
                  ),
                  IconButton(
                    tooltip: 'YouTube',
                    onPressed: () => controller.showPanel('youtube'),
                    icon: const Icon(Icons.play_circle),
                  ),
                  IconButton(
                    tooltip: 'Cài đặt bố cục',
                    onPressed: () => controller.showPanel('settings'),
                    icon: const Icon(Icons.settings),
                  ),
                  IconButton(
                    tooltip: 'Mở rộng',
                    onPressed: () => controller.showPanel('modules'),
                    icon: const Icon(Icons.add),
                  ),
                ],
              ),
            ),
    );
  }
}

class DashboardFrame extends StatefulWidget {
  const DashboardFrame({
    super.key,
    required this.config,
    this.events = const [],
    this.showMonthly = false,
    this.today,
    this.payment = const PaymentConfig(),
    this.map,
    this.media,
    this.rightPanel,
  });
  final LayoutConfig config;
  final List<EventItem> events;
  final bool showMonthly;
  final DateTime? today;
  final PaymentConfig payment;
  final Widget? map;
  final MediaController? media;
  final Widget? rightPanel;
  @override
  State<DashboardFrame> createState() => _DashboardFrameState();
}

class _DashboardFrameState extends State<DashboardFrame> {
  bool expandedCalendar = false;
  bool expandedPayment = false;
  Timer? paymentTimer;
  void togglePayment() {
    paymentTimer?.cancel();
    setState(() {
      expandedPayment = !expandedPayment;
      expandedCalendar = false;
    });
    if (expandedPayment)
      paymentTimer = Timer(const Duration(seconds: 10), () {
        if (mounted) setState(() => expandedPayment = false);
      });
  }

  @override
  void didUpdateWidget(DashboardFrame oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.config.rowEnabled[1]) {
      paymentTimer?.cancel();
      expandedPayment = false;
    }
    if (!widget.config.rowEnabled[0]) expandedCalendar = false;
  }

  @override
  void dispose() {
    paymentTimer?.cancel();
    super.dispose();
  }

  int calendarPage = 0;
  LayoutConfig get config => widget.config;
  @override
  Widget build(BuildContext context) {
    final fractions = config.fractions;
    final enabled = [
      for (var i = 0; i < 3; i++)
        if (config.rowEnabled[i]) i,
    ];
    return Padding(
      padding: const EdgeInsets.all(8),
      child: LayoutBuilder(
        builder: (context, size) {
          final showRight = enabled.isNotEmpty || widget.rightPanel != null;
          final available = math.max(0.0, size.maxWidth - (showRight ? 8 : 0));
          final left = showRight ? available * config.leftFraction : available;
          return Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                width: left,
                child: Card(
                  key: const ValueKey('map-panel'),
                  margin: EdgeInsets.zero,
                  clipBehavior: Clip.antiAlias,
                  child:
                      widget.map ??
                      Stack(
                        children: [
                          const Positioned.fill(
                            child: CustomPaint(painter: _RoadPlaceholder()),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'TAXI XANH',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: math.max(
                                      22,
                                      24 * config.fontScale,
                                    ),
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  'Bảng điều khiển · Giai đoạn 4',
                                  style: TextStyle(
                                    fontSize: math.max(
                                      16,
                                      18 * config.fontScale,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Center(
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.navigation_outlined,
                                    size: 56,
                                  ),
                                  Text(
                                    'Ô bản đồ',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: math.max(
                                        22,
                                        26 * config.fontScale,
                                      ),
                                    ),
                                  ),
                                  Text(
                                    'Mở Bản đồ và dẫn đường trên điện thoại',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: math.max(
                                        16,
                                        18 * config.fontScale,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const Positioned(
                            left: 16,
                            bottom: 16,
                            right: 16,
                            child: Text(
                              'Bản đồ giữ chỗ · Không dùng để dẫn đường',
                              style: TextStyle(fontSize: 16),
                            ),
                          ),
                        ],
                      ),
                ),
              ),
              if (showRight) ...[
                const SizedBox(width: 8),
                Expanded(
                  child: widget.rightPanel != null
                      ? widget.rightPanel!
                      : expandedPayment && config.rowEnabled[1]
                      ? Card(
                          margin: EdgeInsets.zero,
                          clipBehavior: Clip.antiAlias,
                          child: PaymentPanel(
                            config: widget.payment,
                            expanded: true,
                            fontScale: config.fontScale,
                            onTap: togglePayment,
                          ),
                        )
                      : expandedCalendar && config.rowEnabled[0]
                      ? Card(
                          child: CalendarPanel(
                            events: widget.events,
                            showMonthly: widget.showMonthly,
                            today: widget.today,
                            fontScale: config.fontScale,
                            expanded: true,
                            initialPage: calendarPage,
                            onCollapse: () =>
                                setState(() => expandedCalendar = false),
                          ),
                        )
                      : Column(
                          children: [
                            for (final i in enabled)
                              Expanded(
                                flex: (fractions[i] * 100000).round(),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 4,
                                  ),
                                  child: Card(
                                    key: ValueKey('row-$i'),
                                    margin: EdgeInsets.zero,
                                    child: i == 0
                                        ? CalendarPanel(
                                            events: widget.events,
                                            showMonthly: widget.showMonthly,
                                            today: widget.today,
                                            fontScale: config.fontScale,
                                            onExpand: (page) => setState(() {
                                              paymentTimer?.cancel();
                                              expandedPayment = false;
                                              expandedCalendar = true;
                                              calendarPage = page;
                                            }),
                                          )
                                        : i == 1
                                        ? PaymentPanel(
                                            config: widget.payment,
                                            fontScale: config.fontScale,
                                            onTap: togglePayment,
                                          )
                                        : MediaPanel(
                                            controller: widget.media,
                                            fontScale: config.fontScale,
                                          ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _RoadPlaceholder extends CustomPainter {
  const _RoadPlaceholder();
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0x226c9a96)
      ..strokeWidth = 5
      ..style = PaintingStyle.stroke;
    for (var i = -2; i < 8; i++) {
      final x = i * size.width / 5;
      canvas.drawLine(
        Offset(x, 0),
        Offset(x + size.width * .6, size.height),
        paint,
      );
    }
    for (var i = 1; i < 5; i++) {
      final y = i * size.height / 5;
      canvas.drawLine(Offset(0, y), Offset(size.width, y - 60), paint);
    }
  }

  @override
  bool shouldRepaint(_RoadPlaceholder oldDelegate) => false;
}
