import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:taxi_driver_aa_dashboard/features/navigation/map_3d_style.dart';
import 'package:taxi_driver_aa_dashboard/features/navigation/nav_models.dart';

void main() {
  Map<String, dynamic> fixture() => {
    'version': 8,
    'sources': {
      'world': {'type': 'vector', 'url': 'https://example.org/tiles.json'},
    },
    'layers': [
      {
        'id': 'buildings',
        'type': 'fill',
        'source': 'world',
        'source-layer': 'building',
      },
      {'id': 'labels', 'type': 'symbol', 'source': 'world'},
    ],
  };
  test(
    'Idle 3D style has valid empty GeoJSON and real building height fields',
    () {
      final base = fixture(), original = jsonEncode(fixture());
      final style = navigationStyle(base, dark: true);
      expect(jsonEncode(base), original);
      final sources = style['sources'] as Map;
      for (final key in ['taxi-route', 'taxi-goal']) {
        expect(sources[key]['data']['type'], 'FeatureCollection');
        expect(sources[key]['data']['features'], isEmpty);
      }
      final layer = (style['layers'] as List).singleWhere(
        (l) => l['type'] == 'fill-extrusion',
      );
      expect(layer['source'], 'world');
      expect(layer['paint']['fill-extrusion-height'], [
        'to-number',
        ['get', 'render_height'],
        ['get', 'height'],
        0,
      ]);
      expect(layer['paint']['fill-extrusion-base'], [
        'to-number',
        ['get', 'render_min_height'],
        ['get', 'min_height'],
        0,
      ]);
      expect(layer['paint']['fill-extrusion-color'], '#626b7d');
    },
  );
  test('Route/goal preserve longitude-latitude order and existing 3D layers', () {
    final base = fixture();
    (base['layers'] as List).insert(1, {
      'id': 'native-buildings',
      'type': 'fill-extrusion',
      'source': 'world',
      'source-layer': 'building',
    });
    final route = NavRoute(
      [const LatLng(21.281, 106.194), const LatLng(21.282, 106.196)],
      [],
      60,
      'fixture',
    );
    final style = navigationStyle(
      base,
      dark: false,
      route: route,
      goal: const Place('Đích mẫu', LatLng(21.282, 106.196)),
    );
    expect(style['sources']['taxi-route']['data']['geometry']['coordinates'], [
      [106.194, 21.281],
      [106.196, 21.282],
    ]);
    expect(
      style['sources']['taxi-goal']['data']['features'][0]['geometry']['coordinates'],
      [106.196, 21.282],
    );
    final layers = style['layers'] as List;
    expect(layers.where((l) => l['type'] == 'fill-extrusion'), hasLength(1));
    expect(
      layers.indexWhere((l) => l['id'] == 'taxi-route-line'),
      lessThan(layers.indexWhere((l) => l['id'] == 'labels')),
    );
    expect(
      navigationStyle(
        base,
        dark: false,
      )['sources']['taxi-route']['data']['features'],
      isEmpty,
    );
  });
}
