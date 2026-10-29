import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'nav_controller.dart';
import '../road_data/road_widgets.dart';

String distanceText(double meters) => meters < 1000
    ? '${meters.round()} m'
    : '${(meters / 1000).toStringAsFixed(1)} km';

class NavSummary extends StatelessWidget {
  const NavSummary({super.key, required this.navigation});
  final NavController navigation;
  @override
  Widget build(BuildContext context) {
    final n = navigation;
    return SizedBox(
      height: 180,
      child: ColoredBox(
        color: Theme.of(context).colorScheme.surface,
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  n.instruction,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                Wrap(
                  spacing: 12,
                  children: [
                    Text(
                      n.precise && n.fix!.speed >= 0
                          ? '${(n.fix!.speed * 3.6).round()} km/h'
                          : 'GPS: —',
                      style: const TextStyle(fontSize: 22),
                    ),
                    if (n.road.enabled) SpeedBadge(status: n.road.status),
                    if (n.active && n.precise && n.route != null && !n.offRoute)
                      Text(
                        '${distanceText(n.turnDistance)} tới thao tác',
                        style: const TextStyle(fontSize: 16),
                      ),
                  ],
                ),
                if (n.remaining != null)
                  Text(
                    'Còn ${distanceText(n.remaining!)} · ~${math.max(1, (n.route!.seconds * n.remaining! / math.max(1, n.route!.length) / 60).round())} phút',
                    style: const TextStyle(fontSize: 16),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

Future<void> showPlaces(
  BuildContext context,
  NavController nav,
) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  builder: (context) => SafeArea(
    child: SizedBox(
      height: MediaQuery.sizeOf(context).height * .7,
      child: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          const Text('Yêu thích và gần đây', style: TextStyle(fontSize: 22)),
          if (!nav.running)
            const Text(
              'Mở điện thoại để bật vị trí trước khi dẫn đường',
              style: TextStyle(fontSize: 16),
            ),
          if (nav.places.isEmpty)
            const Text(
              'Tìm và lưu địa điểm trên điện thoại',
              style: TextStyle(fontSize: 16),
            ),
          for (final p in [
            ...nav.places.where((p) => p.favorite),
            ...nav.places.where((p) => !p.favorite),
          ])
            ListTile(
              leading: Icon(p.favorite ? Icons.star : Icons.history),
              title: Text(p.name, style: const TextStyle(fontSize: 18)),
              enabled: nav.running,
              onTap: () async {
                try {
                  await nav.start(p);
                  if (context.mounted) Navigator.pop(context);
                } catch (_) {
                  if (context.mounted)
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Bật vị trí trên điện thoại rồi chọn lại điểm đến',
                        ),
                      ),
                    );
                }
              },
            ),
          TextButton(
            onPressed: () async {
              await nav.stop();
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text('Dừng dẫn đường'),
          ),
        ],
      ),
    ),
  ),
);
