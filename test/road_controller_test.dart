import 'package:flutter_test/flutter_test.dart';
import 'package:taxi_driver_aa_dashboard/features/road_data/road_controller.dart';
import 'package:taxi_driver_aa_dashboard/features/road_data/road_models.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Map signs load without a GPS heading or route; alerts remain gated', () {
    final road = RoadController(connected: false);
    addTearDown(road.dispose);
    Map<String, dynamic> sign(
      String id,
      String kind, {
      String source = 'osm',
    }) => {
      'id': id,
      'kind': kind,
      'lat': 21.281,
      'lon': 106.194,
      'source': source,
      if (kind == 'speed') 'value': 60,
    };
    road.accept({
      'revision': 1,
      'pins': [sign('user_one', 'speed', source: 'user')],
    });
    // Native nearby queries are separate from the settings snapshot. Some
    // physical OSM signs have unknown direction: visible, never an alert here.
    road.nearby = RoadNearby.fromJson({
      'signs': [sign('n1:noEntry', 'noEntry'), sign('user_one', 'speed')],
    });
    expect(road.mapSigns.map((s) => s.kind), ['noEntry', 'speed']);
    expect(road.mapSigns.last.source, 'user');
    expect(road.status.upcoming, isEmpty);
    expect(road.status.limit.value, isNull);
    final first = road.mapSigns;
    expect(identical(first, road.mapSigns), isTrue);

    road.nearby = const RoadNearby();
    expect(road.mapSigns.map((s) => s.id), ['user_one']);
    road.accept({
      'revision': 2,
      'settings': {'enabled': false},
    });
    expect(road.mapSigns, isEmpty);
    road.accept({
      'revision': 3,
      'settings': {'enabled': true},
    });
    expect(road.mapSigns, isEmpty);
  });
}
