import 'package:flutter/material.dart';

import 'road_controller.dart';
import 'road_models.dart';
import 'sign_painter.dart';

class SpeedBadge extends StatefulWidget {
  const SpeedBadge({super.key, required this.status});
  final RoadStatus status;
  @override
  State<SpeedBadge> createState() => _SpeedBadgeState();
}

class _SpeedBadgeState extends State<SpeedBadge>
    with SingleTickerProviderStateMixin {
  late final animation = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 650),
  );
  @override
  void initState() {
    super.initState();
    if (widget.status.overspeed) animation.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(SpeedBadge oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.status.overspeed && !oldWidget.status.overspeed) {
      animation.repeat(reverse: true);
    } else if (!widget.status.overspeed) {
      animation.stop();
      animation.value = 0;
    }
  }

  @override
  void dispose() {
    animation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: animation,
    builder: (context, _) => Tooltip(
      message: widget.status.limit.reason,
      child: Container(
        width: 76,
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: widget.status.overspeed
              ? Colors.orange.withValues(alpha: .35 + animation.value * .5)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SignIcon(
              kind: 'speed',
              value: widget.status.limit.value,
              estimated: widget.status.limit.estimated,
            ),
            ColoredBox(
              color: Theme.of(context).colorScheme.surface,
              child: Text(
                widget.status.limit.label,
                style: const TextStyle(fontSize: 16),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class RoadWarnings extends StatelessWidget {
  const RoadWarnings({super.key, required this.controller});
  final RoadController controller;
  @override
  Widget build(BuildContext context) {
    final items = controller.status.upcoming;
    if (items.isEmpty || !controller.enabled) return const SizedBox.shrink();
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final item in items)
            Tooltip(
              message: '${item.sign.title}\n${item.sign.note}',
              child: Card(
                color: Theme.of(context).colorScheme.surface
                    .withValues(alpha: .95),
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: SizedBox(
                    width: 82,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SignIcon(
                          kind: item.sign.kind,
                          value: item.sign.value,
                          size: 44,
                        ),
                        Text(
                          '${(item.distance / 10).round() * 10} m',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          item.sign.source == 'user'
                              ? 'Ghim'
                              : item.sign.note.startsWith('Đầu đoạn')
                              ? 'Đoạn OSM'
                              : 'OSM',
                          style: const TextStyle(fontSize: 16),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
