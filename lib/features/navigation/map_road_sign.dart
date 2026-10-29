import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

import '../road_data/road_models.dart';
import '../road_data/sign_painter.dart';

// OSM way starts and restriction relations describe road rules. Their point
// is not a surveyed physical sign, so keep them visually distinct on the map.
bool isInferredMapSign(RoadSign sign) {
  final note = sign.note.toLowerCase();
  return sign.source == 'osm' &&
      (note.contains('đầu đoạn') || note.contains('quan hệ hạn chế'));
}

const mapSignWidth = 48.0, mapSignHeight = 64.0;

String mapSignDirection(RoadSign sign) {
  if (sign.bearing != null)
    return 'Hướng xe áp dụng: ${sign.bearing!.round()}°';
  if (sign.source == 'user' || sign.note.toLowerCase().contains('hai chiều'))
    return 'Áp dụng hai chiều theo dữ liệu';
  return 'Dữ liệu chưa xác định hướng áp dụng';
}

class MapSignCluster {
  MapSignCluster(List<RoadSign> records) : signs = List.unmodifiable(records) {
    final distinct = <String, RoadSign>{};
    for (final sign in signs) {
      distinct.putIfAbsent(
        '${sign.kind}/${sign.value}/${isInferredMapSign(sign)}',
        () => sign,
      );
    }
    displayed = List.unmodifiable(distinct.values.take(3));
  }
  final List<RoadSign> signs;
  late final List<RoadSign> displayed;
  LatLng get point => signs.first.point;
  int get hiddenCount => signs.length - displayed.length;
  double get width =>
      mapSignWidth * (displayed.length + (hiddenCount > 0 ? 1 : 0));
}

// One approximately one-metre cell groups colocated OSM nodes, directional
// records and private pins. Details retain every record, including bearings.
List<MapSignCluster> groupMapSigns(List<RoadSign> signs) {
  final cells = <(int, int), List<RoadSign>>{};
  for (final sign in signs) {
    final key = (
      (sign.point.latitude * 100000).round(),
      (sign.point.longitude * 100000).round(),
    );
    (cells[key] ??= []).add(sign);
  }
  return [for (final records in cells.values) MapSignCluster(records)];
}

Rect mapSignClusterRect(MapSignCluster group, Offset point, Size viewport) {
  final width = math.min(group.width, viewport.width);
  final height = math.min(mapSignHeight, viewport.height);
  return Rect.fromLTWH(
    (point.dx - width / 2).clamp(0.0, viewport.width - width),
    (point.dy - 23).clamp(0.0, viewport.height - height),
    width,
    height,
  );
}

class MapRoadSignGroup extends StatelessWidget {
  const MapRoadSignGroup({super.key, required this.group, this.onTap});
  final MapSignCluster group;
  final void Function(RoadSign)? onTap;
  @override
  Widget build(BuildContext context) => RepaintBoundary(
    child: SizedBox(
      width: group.width,
      height: mapSignHeight,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final sign in group.displayed)
            MapRoadSign(
              key: ValueKey('road-sign-${sign.id}'),
              sign: sign,
              onTap: onTap == null ? null : () => onTap!(sign),
            ),
          if (group.hiddenCount > 0)
            SizedBox(
              width: mapSignWidth,
              height: 46,
              child: TextButton(
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  backgroundColor: Theme.of(context).colorScheme.surface,
                  foregroundColor: Theme.of(context).colorScheme.onSurface,
                ),
                onPressed: onTap == null
                    ? null
                    : () => showMapSignGroupDetails(context, group),
                child: Text(
                  '+${group.hiddenCount}',
                  textScaler: TextScaler.noScaling,
                  style: const TextStyle(fontSize: 16),
                ),
              ),
            ),
        ],
      ),
    ),
  );
}

Future<void> showMapSignGroupDetails(
  BuildContext context,
  MapSignCluster group,
) => showDialog<void>(
  context: context,
  builder: (context) => AlertDialog(
    insetPadding: const EdgeInsets.all(8),
    titlePadding: const EdgeInsets.fromLTRB(12, 16, 12, 0),
    contentPadding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
    title: Text('${group.signs.length} bản ghi tại vị trí này'),
    content: SizedBox(
      width: 360,
      height: math.min(420.0, group.signs.length * 88.0),
      child: ListView.builder(
        itemCount: group.signs.length,
        itemBuilder: (context, index) {
          final sign = group.signs[index];
          return ListTile(
            contentPadding: EdgeInsets.zero,
            minLeadingWidth: 36,
            horizontalTitleGap: 8,
            leading: SignIcon(kind: sign.kind, value: sign.value, size: 36),
            title: Text(sign.title),
            subtitle: Text(
              '${sign.source == 'user' ? 'Ghim của anh' : 'OSM'} · ${mapSignDirection(sign)}',
            ),
            onTap: () => showMapSignDetails(context, sign),
          );
        },
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Đóng'),
      ),
    ],
  ),
);

class MapRoadSign extends StatelessWidget {
  const MapRoadSign({super.key, required this.sign, this.onTap});
  final RoadSign sign;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) {
    final inferred = isInferredMapSign(sign);
    final label =
        '${sign.title} · ${sign.source == 'user' ? 'ghim của anh' : 'OSM'}'
        '${inferred ? ' · vị trí quy tắc đoạn đường, chưa xác nhận vị trí biển' : ''}'
        ' · ${mapSignDirection(sign)}';
    return Semantics(
      label: label,
      button: onTap != null,
      child: ExcludeSemantics(
        child: GestureDetector(
          onTap: onTap,
          behavior: HitTestBehavior.opaque,
          child: SizedBox(
            width: mapSignWidth,
            height: mapSignHeight,
            child: Column(
              children: [
                Opacity(
                  opacity: inferred ? .7 : 1,
                  child: SignIcon(
                    kind: sign.kind,
                    value: sign.value,
                    estimated: inferred,
                    size: 46,
                  ),
                ),
                if (inferred)
                  Container(
                    color: Theme.of(context).colorScheme.surface,
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    child: Text(
                      'Đoạn',
                      maxLines: 1,
                      textScaler: TextScaler.noScaling,
                      style: TextStyle(
                        fontSize: 16,
                        height: 1,
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

Future<void> showMapSignDetails(
  BuildContext context,
  RoadSign sign,
) => showDialog<void>(
  context: context,
  builder: (context) => AlertDialog(
    title: Text(sign.title),
    content: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SignIcon(kind: sign.kind, value: sign.value),
          const SizedBox(height: 12),
          Text(sign.source == 'user' ? 'Ghim của anh' : 'Nguồn: OpenStreetMap'),
          if (isInferredMapSign(sign))
            const Text(
              'Điểm quy tắc của đoạn đường OSM, chưa xác nhận vị trí biển ngoài thực tế.',
            ),
          Text(
            '${mapSignDirection(sign)}. Biểu tượng trên bản đồ không tự kích hoạt cảnh báo; cảnh báo chỉ xét khi khớp hướng và đoạn đường.',
          ),
          if (sign.note.isNotEmpty) Text(sign.note),
          const Text('Luôn tuân theo biển báo thực tế.'),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Đóng'),
      ),
    ],
  ),
);

// Use adopted-frame projection, rather than an asynchronous camera listener,
// to keep upright Flutter signs attached to the 60-degree GPU map while it moves.
// Only visible signs become widgets; the cap bounds work in dense junctions.
class MapSignOverlay extends StatefulWidget {
  const MapSignOverlay({
    super.key,
    required this.signs,
    required this.viewport,
    required this.project,
    this.onTap,
  });
  final List<RoadSign> signs;
  final Size viewport;
  final Offset Function(LatLng) project;
  final void Function(RoadSign)? onTap;
  static const maximumSigns = 96;
  static const maximumGroups = maximumSigns ~/ 3;
  @override
  State<MapSignOverlay> createState() => _MapSignOverlayState();
}

class _MapSignOverlayState extends State<MapSignOverlay> {
  late List<MapSignCluster> groups = groupMapSigns(widget.signs);
  @override
  void didUpdateWidget(MapSignOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.signs, widget.signs))
      groups = groupMapSigns(widget.signs);
  }

  @override
  Widget build(BuildContext context) {
    final viewport = widget.viewport, project = widget.project;
    final onTap = widget.onTap;
    if (viewport.isEmpty) return const SizedBox.shrink();
    final bounds = Offset.zero & viewport;
    final center = viewport.center(Offset.zero);
    final visible = <(MapSignCluster, Offset)>[];
    for (final group in groups) {
      final point = project(group.point);
      if (point.dx.isFinite && point.dy.isFinite && bounds.contains(point))
        visible.add((group, point));
    }
    visible.sort((a, b) {
      final inferred = (a.$1.signs.every(isInferredMapSign) ? 1 : 0).compareTo(
        b.$1.signs.every(isInferredMapSign) ? 1 : 0,
      );
      if (inferred != 0) return inferred;
      final distance = (a.$2 - center).distanceSquared.compareTo(
        (b.$2 - center).distanceSquared,
      );
      return distance != 0
          ? distance
          : a.$1.signs.first.id.compareTo(b.$1.signs.first.id);
    });
    return IgnorePointer(
      ignoring: onTap == null,
      child: Stack(
        clipBehavior: Clip.hardEdge,
        children: [
          for (final item in visible.take(MapSignOverlay.maximumGroups))
            Positioned.fromRect(
              rect: mapSignClusterRect(item.$1, item.$2, viewport),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.topCenter,
                child: MapRoadSignGroup(group: item.$1, onTap: onTap),
              ),
            ),
        ],
      ),
    );
  }
}
