import 'package:flutter/material.dart';
import '../../core/dashboard_controller.dart';
import '../../core/layout_config.dart';

class LayoutSettings extends StatelessWidget {
  const LayoutSettings({super.key, required this.controller, this.car = false});
  final DashboardController controller;
  final bool car;
  static const rows = ['Lịch Âm/Dương', 'QR thanh toán', 'Media'];
  @override
  Widget build(BuildContext context) {
    final config = controller.config;
    Widget control(String title, double value, double min, double max, double step, ValueChanged<double> change) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [Text('$title: ${value.toStringAsFixed(2)}', style: const TextStyle(fontSize: 18)),
        if (car) Row(children: [
          IconButton(tooltip: 'Giảm $title', onPressed: controller.ready ? () => change((value - step).clamp(min, max).toDouble()) : null, icon: const Icon(Icons.remove_circle_outline), iconSize: 32),
          IconButton(tooltip: 'Tăng $title', onPressed: controller.ready ? () => change((value + step).clamp(min, max).toDouble()) : null, icon: const Icon(Icons.add_circle_outline), iconSize: 32),
        ]) else Slider(value: value, min: min, max: max, onChanged: controller.ready ? change : null),
      ],
    );
    return ListView(padding: const EdgeInsets.all(16), children: [
      const Text('Bố cục · Chỉ chỉnh khi đang đỗ', style: TextStyle(fontSize: 22)),
      if (car) TextButton(onPressed: () => controller.showPanel('dashboard'), child: const Text('Về bảng điều khiển')),
      control('Cột bản đồ', config.leftFraction, .4, .75, .05, (v) => controller.update(config.copyWith(leftFraction: v))),
      for (var i = 0; i < 3; i++) ...[
        SwitchListTile(title: Text(rows[i]), value: config.rowEnabled[i], onChanged: controller.ready ? (v) { final rows = [...config.rowEnabled]; rows[i] = v; controller.update(config.copyWith(rowEnabled: rows)); } : null),
        if (config.rowEnabled[i]) control('Trọng số ${rows[i]}', config.rowWeights[i], .1, 10, .1, (v) { final weights = [...config.rowWeights]; weights[i] = v; controller.update(config.copyWith(rowWeights: weights)); }),
      ],
      const Text('Khi tắt một hàng, các hàng còn lại chia đều. Mỗi hàng đang bật chiếm ít nhất 15%.'),
      control('Cỡ chữ', config.fontScale, .8, 1.6, .1, (v) => controller.update(config.copyWith(fontScale: v))),
      Wrap(spacing: 8, children: [for (final pair in [('auto', 'Tự động'), ('light', 'Sáng'), ('dark', 'Tối')]) ChoiceChip(label: Text(pair.$2), selected: config.theme == pair.$1, onSelected: controller.ready ? (_) => controller.update(config.copyWith(theme: pair.$1)) : null)]),
      const SizedBox(height: 16),
      OutlinedButton(onPressed: controller.ready ? () => controller.update(LayoutConfig()) : null, child: const Text('Đặt lại mặc định')),
      if (controller.error != null) Text(controller.error!),
    ]);
  }
}
