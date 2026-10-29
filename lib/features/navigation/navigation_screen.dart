import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'map_panel.dart';
import 'nav_controller.dart';
import 'nav_models.dart';
import '../road_data/road_screen.dart';

class NavigationScreen extends StatefulWidget {
  const NavigationScreen({super.key, required this.navigation});
  final NavController navigation;
  @override
  State<NavigationScreen> createState() => _NavigationScreenState();
}

class _NavigationScreenState extends State<NavigationScreen> {
  final query = TextEditingController();
  List<Place> results = [];
  bool busy = false;
  String? message;
  NavController get nav => widget.navigation;
  @override
  void dispose() {
    query.dispose();
    super.dispose();
  }

  Future<void> action(Future<void> Function() work) async {
    if (busy) return;
    setState(() {
      busy = true;
      message = null;
    });
    try {
      await work();
    } on FormatException catch (e) {
      if (mounted) setState(() => message = e.message);
    } on PlatformException catch (e) {
      if (mounted)
        setState(
          () => message =
              e.message ?? 'Không thực hiện được. Kiểm tra quyền vị trí.',
        );
    } catch (_) {
      if (mounted)
        setState(
          () => message =
              'Chưa lấy được dữ liệu. Kiểm tra mạng/máy chủ rồi thử lại.',
        );
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> select(Place p) => action(() async {
    if (!nav.running) {
      await nav.startLocation();
      if (mounted)
        setState(
          () => message = 'Đang bật GPS. Chờ có vị trí rồi bấm Dẫn đường lại.',
        );
      return;
    }
    await nav.start(p);
    if (mounted) setState(() => message = 'Đã gửi điểm đến lên xe.');
  });
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Bản đồ và dẫn đường')),
    body: ListenableBuilder(
      listenable: nav,
      builder: (_, _) => ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Bật vị trí tại đây trước khi tắt màn hình điện thoại. Chọn Vị trí chính xác để dẫn đường; thông báo có nút Dừng vị trí.',
          ),
          Wrap(
            spacing: 8,
            children: [
              FilledButton.icon(
                onPressed: busy ? null : () => action(nav.startLocation),
                icon: const Icon(Icons.gps_fixed),
                label: const Text('Bật vị trí'),
              ),
              OutlinedButton(
                onPressed: busy ? null : () => action(nav.stopLocation),
                child: const Text('Dừng vị trí'),
              ),
              TextButton(
                onPressed: () => action(
                  () => NavController.location.invokeMethod('settings'),
                ),
                child: const Text('Quyền ứng dụng'),
              ),
            ],
          ),
          Text(
            nav.running
                ? 'Vị trí đang bật · ${nav.precise ? 'GPS chính xác' : 'đang chờ GPS chính xác'}'
                : nav.status,
          ),
          Text(
            nav.carConnected
                ? 'Android Auto đang kết nối'
                : 'Android Auto chưa kết nối',
          ),
          const Text(
            'Vị trí sẽ tự tắt khi Android Auto ngắt kết nối. Luôn luôn giúp tự bật lại GPS khi kết nối xe lúc điện thoại ở nền.',
          ),
          TextButton.icon(
            onPressed: () => showBackgroundPermission(),
            icon: const Icon(Icons.location_on),
            label: Text(
              nav.backgroundLocation
                  ? 'Vị trí nền đã được cho phép'
                  : 'Cho phép vị trí Luôn luôn',
            ),
          ),
          FilledButton.icon(onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => RoadScreen(navigation: nav))), icon: const Icon(Icons.traffic), label: const Text('Tốc độ và biển báo')),
          SwitchListTile(
            title: const Text('Bản đồ 3D · nghiêng 60°'),
            subtitle: const Text('Tắt để dùng bản đồ 2D dự phòng'),
            value: nav.settings['map3d'] != false,
            onChanged: busy
                ? null
                : (v) => action(
                    () => nav.saveSettings({..._settings(nav), 'map3d': v}),
                  ),
          ),
          Text(
            nav.voiceReady
                ? 'Giọng Việt ngoại tuyến sẵn sàng'
                : 'Chưa có giọng Việt ngoại tuyến; vẫn có chỉ dẫn chữ',
          ),
          if (!nav.voiceReady)
            TextButton(
              onPressed: () => action(
                () => NavController.location.invokeMethod('installVoice'),
              ),
              child: const Text('Cài dữ liệu giọng đọc'),
            ),
          SwitchListTile(
            title: const Text('Đọc chỉ đường'),
            value: nav.settings['voice'] != false,
            onChanged: busy
                ? null
                : (v) => action(
                    () => nav.saveSettings({..._settings(nav), 'voice': v}),
                  ),
          ),
          SwitchListTile(
            title: const Text('Xoay bản đồ theo hướng xe'),
            value: nav.settings['headingUp'] != false,
            onChanged: busy
                ? null
                : (v) => action(
                    () => nav.saveSettings({..._settings(nav), 'headingUp': v}),
                  ),
          ),
          TextButton(
            onPressed: () => showLicensePage(
              context: context,
              applicationName: 'Taxi Xanh',
              applicationVersion: '0.5.0',
            ),
            child: const Text('Giấy phép thư viện và bản đồ'),
          ),
          const Divider(),
          TextField(
            controller: query,
            textInputAction: TextInputAction.search,
            decoration: const InputDecoration(
              labelText: 'Địa điểm hoặc vĩ độ,kinh độ',
              helperText:
                  'Ví dụ: 21.281,106.194 · Nhập tọa độ dùng được ngoại tuyến',
            ),
            onSubmitted: (_) => search(),
          ),
          FilledButton.icon(
            onPressed: busy ? null : search,
            icon: const Icon(Icons.search),
            label: const Text('Tìm địa điểm'),
          ),
          const Text(
            'Tìm tên gửi truy vấn tới Photon; tính đường gửi điểm đầu/đích tới Valhalla hoặc OSRM. Tài khoản/QR không được gửi. Tìm kiếm chỉ chạy khi bấm Tìm; tọa độ nhập tay và địa điểm đã lưu dùng được không cần tra cứu mạng.',
          ),
          if (busy) const LinearProgressIndicator(),
          if (message != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(message!),
            ),
          for (final p in results) _place(p),
          const Divider(),
          const Text('Yêu thích và gần đây', style: TextStyle(fontSize: 22)),
          for (final p in [
            ...nav.places.where((p) => p.favorite),
            ...nav.places.where((p) => !p.favorite),
          ])
            _place(p, saved: true),
          OutlinedButton(
            onPressed: busy ? null : () => action(nav.stop),
            child: const Text('Dừng dẫn đường'),
          ),
          SizedBox(
            height: 520,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: MapPanel(navigation: nav),
            ),
          ),
          TextButton(
            onPressed: () =>
                action(() => NavController.location.invokeMethod('source')),
            child: const Text('Nguồn bản đồ và giấy phép OpenStreetMap'),
          ),
          ExpansionTile(
            title: const Text('Máy chủ dịch vụ'),
            subtitle: const Text('Đổi khi máy chủ công cộng không đáp ứng'),
            children: [
              Padding(
                padding: const EdgeInsets.all(12),
                child: _ServerSettings(
                  navigation: nav,
                  onSave: (value) => action(() => nav.saveSettings(value)),
                ),
              ),
            ],
          ),
          const Text(
            'Vùng bản đồ đã xem có bộ nhớ đệm 300 MB; vùng chưa tải và tính tuyến mới cần mạng. ETA là ước tính, chưa có giao thông trực tiếp. Giới hạn tốc độ và biển báo sẽ có ở Giai đoạn 5.',
          ),
        ],
      ),
    ),
  );
  Future<void> showBackgroundPermission() async {
    final open = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Vị trí Luôn luôn'),
        content: const Text(
          'Cho phép tự bật GPS khi kết nối Android Auto mà điện thoại đang ở nền. Khi ngắt Android Auto, ứng dụng dừng GPS. Trên Android 11 trở lên: mở Quyền ứng dụng → Vị trí → Luôn cho phép, đồng thời bật Vị trí chính xác. Bạn vẫn có thể dùng nút Bật vị trí nếu không cấp quyền này.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Để sau'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Mở cài đặt'),
          ),
        ],
      ),
    );
    if (open == true && mounted)
      await action(() => NavController.location.invokeMethod('background'));
  }

  Future<void> search() => action(() async {
    final found = await nav.search(query.text);
    if (mounted)
      setState(() {
        results = found;
        message = found.isEmpty
            ? 'Không tìm thấy. Thử địa chỉ cụ thể hoặc nhập tọa độ.'
            : null;
      });
  });
  Widget _place(Place p, {bool saved = false}) => Card(
    child: Padding(
      padding: const EdgeInsets.all(8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(p.name, style: const TextStyle(fontSize: 18)),
          Wrap(
            spacing: 4,
            children: [
              TextButton.icon(
                onPressed: busy ? null : () => select(p),
                icon: const Icon(Icons.directions_car),
                label: const Text('Dẫn đường'),
              ),
              IconButton(
                tooltip: p.favorite ? 'Bỏ yêu thích' : 'Lưu yêu thích',
                onPressed: busy
                    ? null
                    : () => action(
                        () => nav.savePlace(
                          Place(p.name, p.point, favorite: !p.favorite),
                        ),
                      ),
                icon: Icon(p.favorite ? Icons.star : Icons.star_border),
              ),
              if (saved)
                IconButton(
                  tooltip: 'Xóa địa điểm',
                  onPressed: busy
                      ? null
                      : () => action(() => nav.savePlace(p, remove: true)),
                  icon: const Icon(Icons.delete_outline),
                ),
            ],
          ),
        ],
      ),
    ),
  );
}

Map<String, dynamic> _settings(NavController n) => {
  'valhalla': n.endpoint('valhalla'),
  'osrm': n.endpoint('osrm'),
  'photon': n.endpoint('photon'),
  'voice': n.settings['voice'] != false,
  'headingUp': n.settings['headingUp'] != false,
  'map3d': n.settings['map3d'] != false,
};

class _ServerSettings extends StatefulWidget {
  const _ServerSettings({required this.navigation, required this.onSave});
  final NavController navigation;
  final Future<void> Function(Map<String, dynamic>) onSave;
  @override
  State<_ServerSettings> createState() => _ServerSettingsState();
}

class _ServerSettingsState extends State<_ServerSettings> {
  late final fields = {
    for (final key in ['valhalla', 'osrm', 'photon'])
      key: TextEditingController(text: widget.navigation.endpoint(key)),
  };
  @override
  void dispose() {
    for (final c in fields.values) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Column(
    children: [
      for (final entry in fields.entries)
        TextField(
          controller: entry.value,
          decoration: InputDecoration(labelText: '${entry.key} · HTTPS'),
          keyboardType: TextInputType.url,
        ),
      const Text(
        'Valhalla: URL /route · OSRM: URL kết thúc /route/v1/driving · Photon: URL /api/. Chỉ dùng máy chủ có quyền truy cập miễn phí.',
      ),
      FilledButton(
        onPressed: () => widget.onSave({
          ..._settings(widget.navigation),
          for (final e in fields.entries) e.key: e.value.text.trim(),
        }),
        child: const Text('Lưu máy chủ'),
      ),
    ],
  );
}
