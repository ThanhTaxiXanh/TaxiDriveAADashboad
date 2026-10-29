import 'dart:convert';

import 'nav_models.dart';
import '../road_data/road_models.dart';

Map<String, dynamic> navigationStyle(
  Map<String, dynamic> base, {
  List<RoadSign> pins = const [],
  NavRoute? route,
  Place? goal,
  required bool dark,
}) {
  final style = jsonDecode(jsonEncode(base)) as Map<String, dynamic>;
  final layers = (style['layers'] as List).cast<Map>();
  final sources = style['sources'] as Map;
  // Use actual source height attributes; do not invent towers where heights
  // are absent in the data. Liberty already has an extrusion layer.
  if (!layers.any((l) => l['type'] == 'fill-extrusion')) {
    final footprint = layers
        .where((l) => l['source-layer'] == 'building')
        .firstOrNull;
    if (footprint != null)
      layers.add({
        'id': 'taxi-buildings-3d',
        'type': 'fill-extrusion',
        'source': footprint['source'],
        'source-layer': 'building',
        'minzoom': 14,
        'paint': {
          'fill-extrusion-color': dark ? '#626b7d' : '#c8d5df',
          'fill-extrusion-height': [
            'to-number',
            ['get', 'render_height'],
            ['get', 'height'],
            0,
          ],
          'fill-extrusion-base': [
            'to-number',
            ['get', 'render_min_height'],
            ['get', 'min_height'],
            0,
          ],
          'fill-extrusion-opacity': .9,
        },
      });
  }
  sources['taxi-route'] = {
    'type': 'geojson',
    'data': {
      'type': 'Feature',
      'properties': <String, dynamic>{},
      'geometry': {
        'type': 'LineString',
        'coordinates': [
          if (route != null)
            for (final p in route.points) [p.longitude, p.latitude],
        ],
      },
    },
  };
  sources['taxi-goal'] = {
    'type': 'geojson',
    'data': {
      'type': 'FeatureCollection',
      'features': [
        if (goal != null)
          {
            'type': 'Feature',
            'properties': <String, dynamic>{},
            'geometry': {
              'type': 'Point',
              'coordinates': [goal.point.longitude, goal.point.latitude],
            },
          },
      ],
    },
  };
  // An empty FeatureCollection is valid before a route is selected.
  if (route == null)
    (sources['taxi-route'] as Map)['data'] = {
      'type': 'FeatureCollection',
      'features': <dynamic>[],
    };
  sources['taxi-pins'] = {'type': 'geojson', 'data': {'type': 'FeatureCollection', 'features': [for (final pin in pins) {'type': 'Feature', 'properties': {'id': pin.id}, 'geometry': {'type': 'Point', 'coordinates': [pin.point.longitude, pin.point.latitude]}}]}};
  final added = <Map<String, dynamic>>[
    {'id': 'taxi-pin-dot', 'type': 'circle', 'source': 'taxi-pins', 'paint': {'circle-radius': 7, 'circle-color': '#ed4545', 'circle-stroke-color': '#ffffff', 'circle-stroke-width': 3}},
    {
      'id': 'taxi-route-casing',
      'type': 'line',
      'source': 'taxi-route',
      'layout': {'line-cap': 'round', 'line-join': 'round'},
      'paint': {'line-color': '#ffffff', 'line-width': 10},
    },
    {
      'id': 'taxi-route-line',
      'type': 'line',
      'source': 'taxi-route',
      'layout': {'line-cap': 'round', 'line-join': 'round'},
      'paint': {'line-color': '#168aff', 'line-width': 6},
    },
    {
      'id': 'taxi-goal-dot',
      'type': 'circle',
      'source': 'taxi-goal',
      'paint': {
        'circle-radius': 8,
        'circle-color': '#ed4545',
        'circle-stroke-color': '#ffffff',
        'circle-stroke-width': 2,
      },
    },
  ];
  final index = layers.indexWhere((l) => l['type'] == 'symbol');
  layers.insertAll(index < 0 ? layers.length : index, added);
  style['layers'] = layers;
  return style;
}
