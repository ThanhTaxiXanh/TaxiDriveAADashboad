import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

import '../navigation/nav_controller.dart';
import '../navigation/nav_models.dart';
import 'road_controller.dart';
import 'road_models.dart';
import 'sign_painter.dart';

class RoadScreen extends StatefulWidget {
  const RoadScreen({super.key, required this.navigation});
  final NavController navigation;
  @override
  State<RoadScreen> createState() => _RoadScreenState();
}

class _RoadScreenState extends State<RoadScreen> {
  RoadController get road => widget.navigation.road;
  bool busy = false;
  String? message;
  Future<void> action(Future<void> Function() task) async {
    if (busy) return;
    setState(() {
      busy = true;
      message = null;
    });
    try {
      await task();
    } catch (_) {
      if (mounted)
        setState(
          () =>
              message = 'Chưa thực hiện được. Kiểm tra tệp/quyền hoặc thử lại.',
        );
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Tốc độ và biển báo')),
    body: ListenableBuilder(
      listenable: road,
      builder: (context, _) => ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Dữ liệu có thể thiếu hoặc sai. Luôn tuân theo biển báo thực tế. Số có nét đứt là ước tính, không phải giới hạn đã xác nhận.',
          ),
          SwitchListTile(
            title: const Text('Hiện tốc độ giới hạn và biển phía trước'),
            value: road.enabled,
            onChanged: busy
                ? null
                : (v) => action(
                    () => road.saveSettings({...road.settings, 'enabled': v}),
                  ),
          ),
          DropdownButtonFormField<String>(
            initialValue: road.settings['vehicle'] as String? ?? 'car',
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'Loại xe để tính mức ước tính',
            ),
            items: [
              for (final v in vehicleNames.entries)
                DropdownMenuItem(
                  value: v.key,
                  child: Text(
                    v.value,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 16),
                  ),
                ),
            ],
            onChanged: busy
                ? null
                : (v) => action(
                    () => road.saveSettings({...road.settings, 'vehicle': v}),
                  ),
          ),
          SwitchListTile(
            title: const Text('Hiện mức ước tính khi thiếu hạn tốc'),
            subtitle: const Text(
              'Vùng dân cư và loại đường có thể được suy đoán từ OSM',
            ),
            value: road.settings['estimates'] != false,
            onChanged: busy
                ? null
                : (v) => action(
                    () => road.saveSettings({...road.settings, 'estimates': v}),
                  ),
          ),
          DropdownButtonFormField<int>(
            initialValue: (road.settings['tolerance'] as num? ?? 5).toInt(),
            decoration: const InputDecoration(
              labelText: 'Dung sai cảnh báo vượt tốc độ (km/h)',
            ),
            items: [
              for (var i = 0; i <= 20; i++)
                DropdownMenuItem(value: i, child: Text('$i km/h')),
            ],
            onChanged: busy
                ? null
                : (v) => action(
                    () => road.saveSettings({...road.settings, 'tolerance': v}),
                  ),
          ),
          SwitchListTile(
            title: const Text('Bíp khi vượt mức OSM/ghim'),
            subtitle: const Text(
              'Mặc định tắt; không bíp cho mức ước tính; cách nhau ít nhất 30 giây',
            ),
            value: road.settings['beep'] == true,
            onChanged: busy
                ? null
                : (v) => action(
                    () => road.saveSettings({...road.settings, 'beep': v}),
                  ),
          ),
          const Divider(),
          const Text(
            'Gói dữ liệu đường Việt Nam',
            style: TextStyle(fontSize: 22),
          ),
          Text(road.message),
          if (road.pack['built'] != null)
            Text(
              'Bản dựng: ${road.pack['built'].toString().split('T').first} · ${road.pack['counts']?['roads'] ?? '—'} đoạn đường',
            ),
          if (road.downloading)
            LinearProgressIndicator(value: road.progress / 100),
          FilledButton.icon(
            onPressed: busy || road.downloading
                ? null
                : () => action(road.download),
            icon: const Icon(Icons.download),
            label: const Text('Tải / cập nhật dữ liệu Việt Nam'),
          ),
          const Text(
            'Gói toàn quốc có thể vài trăm MB, cần đủ chỗ trống. Tải qua Wi-Fi trước chuyến đi. Gói riêng dùng cho tốc độ/biển báo, hoạt động ngoại tuyến; không phải gói nền bản đồ hoặc tìm đường offline. Dữ liệu dựng hằng tháng từ Geofabrik/OSM, giấy phép ODbL. © OpenStreetMap contributors.',
          ),
          const Divider(),
          const Text('Ghim của anh', style: TextStyle(fontSize: 22)),
          const Text(
            'Tải gói dữ liệu trước để ghim khớp đoạn đường. Nhấn giữ bản đồ trên điện thoại để ghim tại điểm đó. Chọn hướng xe đi; ghim hạn tốc có phạm vi hiệu lực, mặc định 300 m. Ghim được ưu tiên hơn OSM trong phạm vi đã chọn.',
          ),
          OutlinedButton.icon(
            onPressed: busy || widget.navigation.fix == null
                ? null
                : () => showPinEditor(
                    context,
                    road,
                    widget.navigation.fix!.point,
                    heading: widget.navigation.bearing,
                  ),
            icon: const Icon(Icons.add_location_alt),
            label: const Text('Ghim tại vị trí hiện tại'),
          ),
          Wrap(
            spacing: 8,
            children: [
              OutlinedButton(
                onPressed: busy ? null : () => action(road.exportPins),
                child: const Text('Xuất ghim JSON'),
              ),
              OutlinedButton(
                onPressed: busy
                    ? null
                    : () => action(() async {
                        final replace = await showDialog<bool>(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: const Text('Nhập ghim từ JSON'),
                            content: const Text(
                              'Danh sách trong tệp sẽ thay thế ghim hiện tại. Có thể xuất bản sao trước khi nhập.',
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context, false),
                                child: const Text('Để sau'),
                              ),
                              FilledButton(
                                onPressed: () => Navigator.pop(context, true),
                                child: const Text('Chọn tệp'),
                              ),
                            ],
                          ),
                        );
                        if (replace == true) await road.importPins();
                      }),
                child: const Text('Nhập ghim JSON'),
              ),
            ],
          ),
          if (busy) const LinearProgressIndicator(),
          if (message != null) Text(message!),
          for (final pin in road.pins)
            ListTile(
              leading: SignIcon(kind: pin.kind, value: pin.value, size: 44),
              title: Text(pin.title),
              subtitle: Text(
                '${pin.bearing == null ? 'Hai chiều' : 'Hướng xe ${pin.bearing!.round()}°'} · ${pin.note}\n${pin.point.latitude.toStringAsFixed(6)}, ${pin.point.longitude.toStringAsFixed(6)}',
              ),
              isThreeLine: true,
              onTap: () => showPinEditor(
                context,
                road,
                pin.point,
                heading: pin.bearing ?? 0,
                existing: pin,
              ),
            ),
        ],
      ),
    ),
  );
}

Future<void> editPinAt(
  BuildContext context,
  NavController nav,
  LatLng point, {
  bool existingOnly = false,
}) async {
  if (nav.car) return;
  final pin = nav.road.pins
      .where((p) => meters(p.point, point) < 20)
      .firstOrNull;
  if (existingOnly && pin == null) return;
  await showPinEditor(
    context,
    nav.road,
    pin?.point ?? point,
    heading: nav.bearing,
    existing: pin,
  );
}

Future<void> showPinEditor(
  BuildContext context,
  RoadController road,
  LatLng point, {
  double heading = 0,
  RoadSign? existing,
}) async {
  if (road.car) return;
  await showDialog<void>(
    context: context,
    builder: (_) => _PinEditor(
      road: road,
      point: point,
      heading: heading,
      existing: existing,
    ),
  );
}

class _PinEditor extends StatefulWidget {
  const _PinEditor({
    required this.road,
    required this.point,
    required this.heading,
    this.existing,
  });
  final RoadController road;
  final LatLng point;
  final double heading;
  final RoadSign? existing;
  @override
  State<_PinEditor> createState() => _PinEditorState();
}

class _PinEditorState extends State<_PinEditor> {
  final form = GlobalKey<FormState>();
  late final lat = TextEditingController(
    text: widget.point.latitude.toStringAsFixed(6),
  );
  late final lon = TextEditingController(
    text: widget.point.longitude.toStringAsFixed(6),
  );
  late final speed = TextEditingController(
    text: '${widget.existing?.value ?? 50}',
  );
  late final heading = TextEditingController(
    text: '${(widget.existing?.bearing ?? widget.heading).round() % 360}',
  );
  late final scope = TextEditingController(
    text: '${widget.existing?.scope.round() ?? 300}',
  );
  late final note = TextEditingController(text: widget.existing?.note ?? '');
  late String kind = widget.existing?.kind ?? 'speed';
  late bool both = widget.existing != null && widget.existing!.bearing == null;
  bool busy = false;
  String? error;
  @override
  void dispose() {
    for (final c in [lat, lon, speed, heading, scope, note]) {
      c.dispose();
    }
    super.dispose();
  }

  String? numeric(String? value, double min, double max) {
    final n = double.tryParse(value ?? '');
    return n == null || !n.isFinite || n < min || n > max
        ? 'Nhập từ $min đến $max'
        : null;
  }

  Future<void> save() async {
    if (!form.currentState!.validate()) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final p = coordinate(double.parse(lat.text), double.parse(lon.text));
      final old = widget.existing;
      final same = old != null && meters(old.point, p) < 1;
      final id =
          old?.id ??
          'user_${DateTime.now().microsecondsSinceEpoch}_${math.Random.secure().nextInt(1 << 30)}';
      await widget.road.savePin(
        RoadSign(
          id: id,
          point: p,
          kind: kind,
          value: kind == 'speed' ? int.parse(speed.text) : null,
          bearing: both ? null : double.parse(heading.text),
          way: same ? old.way : null,
          along: same ? old.along : null,
          scope: double.parse(scope.text),
          note: note.text.trim(),
        ),
      );
      if (mounted) Navigator.pop(context);
    } catch (_) {
      if (mounted)
        setState(() {
          busy = false;
          error = 'Chưa lưu được ghim. Kiểm tra dữ liệu và thử lại.';
        });
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.existing == null ? 'Ghim biển báo' : 'Sửa ghim'),
    content: SizedBox(
      width: 420,
      child: SingleChildScrollView(
        child: Form(
          key: form,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                initialValue: kind,
                isExpanded: true,
                items: [
                  for (final item in roadKinds.entries)
                    DropdownMenuItem(value: item.key, child: Text(item.value)),
                ],
                onChanged: busy ? null : (v) => setState(() => kind = v!),
              ),
              if (kind == 'speed')
                TextFormField(
                  controller: speed,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Tốc độ tối đa (km/h)',
                  ),
                  validator: (s) => int.tryParse(s ?? '') == null
                      ? 'Nhập số nguyên'
                      : numeric(s, 1, 150),
                ),
              TextFormField(
                controller: lat,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                  signed: true,
                ),
                decoration: const InputDecoration(labelText: 'Vĩ độ'),
                validator: (s) => numeric(s, -90, 90),
              ),
              TextFormField(
                controller: lon,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                  signed: true,
                ),
                decoration: const InputDecoration(labelText: 'Kinh độ'),
                validator: (s) => numeric(s, -180, 180),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Áp dụng hai chiều'),
                value: both,
                onChanged: busy ? null : (v) => setState(() => both = v),
              ),
              if (!both)
                TextFormField(
                  controller: heading,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Hướng xe đi · 0° Bắc, 90° Đông',
                  ),
                  validator: (s) => numeric(s, 0, 359.999),
                ),
              if (kind == 'speed')
                TextFormField(
                  controller: scope,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Phạm vi sau ghim (m)',
                  ),
                  validator: (s) => numeric(s, 50, 2000),
                ),
              TextFormField(
                controller: note,
                maxLength: 200,
                decoration: const InputDecoration(labelText: 'Ghi chú'),
              ),
              if (busy) const LinearProgressIndicator(),
              if (error != null) Text(error!),
            ],
          ),
        ),
      ),
    ),
    actions: [
      if (widget.existing != null)
        TextButton(
          onPressed: busy
              ? null
              : () async {
                  try {
                    await widget.road.deletePin(widget.existing!.id);
                    if (context.mounted) Navigator.pop(context);
                  } catch (_) {
                    if (mounted) setState(() => error = 'Chưa xóa được ghim');
                  }
                },
          child: const Text('Xóa ghim'),
        ),
      TextButton(
        onPressed: busy ? null : () => Navigator.pop(context),
        child: const Text('Hủy'),
      ),
      FilledButton(
        onPressed: busy ? null : save,
        child: const Text('Lưu ghim'),
      ),
    ],
  );
}
