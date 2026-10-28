import 'package:flutter/material.dart';
import 'car_main.dart';
import 'core/car_bridge.dart';
import 'features/dashboard/dashboard_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const DashboardApp());
}

// AOT entrypoint phải nằm trong thư viện main mà Android khởi chạy.
@pragma('vm:entry-point')
void carMain() => startCar();

class DashboardApp extends StatelessWidget {
  const DashboardApp({super.key, this.car = false});
  final bool car;

  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: ThemeData.dark(useMaterial3: true).copyWith(
      scaffoldBackgroundColor: const Color(0xff0c1824),
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xff41d7b0),
        brightness: Brightness.dark,
      ),
    ),
    home: car ? const DashboardScreen() : const DiagnosticsScreen(),
  );
}

class DiagnosticsScreen extends StatefulWidget {
  const DiagnosticsScreen({super.key});
  @override
  State<DiagnosticsScreen> createState() => _DiagnosticsScreenState();
}

class _DiagnosticsScreenState extends State<DiagnosticsScreen> {
  late final stream = CarBridge.watch();
  String? error;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Taxi Xanh · Chẩn đoán')),
    body: StreamBuilder<Map<String, dynamic>>(
      stream: stream,
      builder: (context, state) {
        final data = state.data ?? {};
        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const Text('Giai đoạn 0 · Thử trên xe khi đang đỗ',
                style: TextStyle(fontSize: 22)),
            const SizedBox(height: 16),
            Text('Surface: ${data['surface'] == true ? "Đã nhận" : "Chưa nhận"}'),
            Text('Kích thước: ${data['width'] ?? 0} × ${data['height'] ?? 0} px'),
            Text('DPI: ${data['dpi'] ?? 0}'),
            Text('Car API: ${data['carApi'] ?? "—"}'),
            Text('Khung đầu: ${data['firstFrame'] == true ? "Đã vẽ" : "Chưa vẽ"}'),
            Text('Chạm từ xe: ${data['touches'] ?? 0}'),
            Text('FPS Flutter (5 giây): ${data['fps'] ?? 0}'),
            const Text('FPS là số khung Flutter hoàn tất, không phải FPS màn hình xe.'),
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
            OutlinedButton(
              onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(
                builder: (_) => const DashboardScreen(preview: true),
              )),
              child: const Text('Xem trước khung thử'),
            ),
            const SizedBox(height: 16),
            const Text('Chưa có bản đồ, lịch âm, QR thanh toán và media. '
                'Cần xác nhận chữ tiếng Việt, chạm và FPS trên xe trước khi triển khai tiếp.'),
          ],
        );
      },
    ),
  );
}
