import 'package:flutter/material.dart';
import 'car_main.dart';
import 'core/car_bridge.dart';
import 'core/dashboard_theme.dart';
import 'features/calendar/calendar_store.dart';
import 'features/calendar/event_screen.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'core/dashboard_controller.dart';
import 'features/settings/layout_settings.dart';
import 'features/dashboard/spike_screen.dart';
import 'features/dashboard/dashboard_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const DashboardApp());
}

// AOT entrypoint phải nằm trong thư viện main mà Android khởi chạy.
@pragma('vm:entry-point')
void carMain() => startCar();

class DashboardApp extends StatefulWidget {
  const DashboardApp({super.key, this.car = false});
  final bool car;
  @override
  State<DashboardApp> createState() => _DashboardAppState();
}

class _DashboardAppState extends State<DashboardApp> {
  final controller = DashboardController();
  final calendar = CalendarStore();
  @override
  void dispose() {
    controller.dispose();
    calendar.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: controller,
    builder: (context, _) {
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        locale: const Locale('vi', 'VN'),
        supportedLocales: const [Locale('vi', 'VN')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        theme: dashboardTheme(Brightness.light),
        darkTheme: dashboardTheme(Brightness.dark),
        themeMode: switch (controller.config.theme) {
          'light' => ThemeMode.light,
          'dark' => ThemeMode.dark,
          _ =>
            widget.car
                ? (controller.diagnostics['carDark'] == true
                      ? ThemeMode.dark
                      : ThemeMode.light)
                : ThemeMode.system,
        },
        home: widget.car
            ? DashboardScreen(
                controller: controller,
                car: true,
                calendar: calendar,
              )
            : DiagnosticsScreen(controller: controller, calendar: calendar),
      );
    },
  );
}

class DiagnosticsScreen extends StatefulWidget {
  const DiagnosticsScreen({
    super.key,
    required this.controller,
    required this.calendar,
  });
  final DashboardController controller;
  final CalendarStore calendar;
  @override
  State<DiagnosticsScreen> createState() => _DiagnosticsScreenState();
}

class _DiagnosticsScreenState extends State<DiagnosticsScreen> {
  Stream<Map<String, dynamic>> get stream => CarBridge.watch();
  String? error;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Taxi Xanh · Chẩn đoán')),
    body: StreamBuilder<Map<String, dynamic>>(
      stream: stream,
      initialData: widget.controller.diagnostics,
      builder: (context, state) {
        final data = state.data ?? {};
        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const Text(
              'Giai đoạn 2 · Lịch Âm/Dương và sự kiện',
              style: TextStyle(fontSize: 22),
            ),
            const SizedBox(height: 16),
            Text(
              'Surface: ${data['surface'] == true ? "Đã nhận" : "Chưa nhận"}',
            ),
            Text(
              'Kích thước: ${data['width'] ?? 0} × ${data['height'] ?? 0} px',
            ),
            Text('DPI: ${data['dpi'] ?? 0}'),
            Text('Car API: ${data['carApi'] ?? "—"}'),
            Text(
              'Khung đầu: ${data['firstFrame'] == true ? "Đã vẽ" : "Chưa vẽ"}',
            ),
            Text('Chạm từ xe: ${data['touches'] ?? 0}'),
            Text('FPS Flutter (5 giây): ${data['fps'] ?? 0}'),
            const Text(
              'FPS là số khung Flutter hoàn tất, không phải FPS màn hình xe.',
            ),
            Text('Lỗi: ${data['error'] ?? state.error ?? "Không"}'),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: () async {
                try {
                  await CarBridge.share();
                } catch (e) {
                  if (mounted) setState(() => error = 'Không chia sẻ được: $e');
                }
              },
              icon: const Icon(Icons.share),
              label: const Text('Chia sẻ nhật ký'),
            ),
            if (error != null) Text(error!),
            FilledButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => EventScreen(store: widget.calendar),
                ),
              ),
              child: const Text('Lịch và sự kiện'),
            ),
            OutlinedButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => DashboardScreen(
                    controller: widget.controller,
                    calendar: widget.calendar,
                  ),
                ),
              ),
              child: const Text('Xem trước bố cục'),
            ),
            OutlinedButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => Scaffold(
                    appBar: AppBar(title: const Text('Bố cục')),
                    body: ListenableBuilder(
                      listenable: widget.controller,
                      builder: (_, _) =>
                          LayoutSettings(controller: widget.controller),
                    ),
                  ),
                ),
              ),
              child: const Text('Chỉnh bố cục'),
            ),
            OutlinedButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const SpikeScreen(preview: true),
                ),
              ),
              child: const Text('Xem khung thử Giai đoạn 0'),
            ),
            const SizedBox(height: 16),
            const Text(
              'Đã có lịch Âm/Dương và sự kiện. Bản đồ dẫn đường, QR thanh toán và media đang giữ chỗ. '
              'Bố cục Giai đoạn 1 đã được Thanh xác nhận chạy mượt trên VF e34.',
            ),
          ],
        );
      },
    ),
  );
}
