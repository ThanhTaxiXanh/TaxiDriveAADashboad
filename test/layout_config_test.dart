import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:taxi_driver_aa_dashboard/core/layout_config.dart';

void main() {
  test('Default weights keep requested proportions', () {
    final values = LayoutConfig().fractions;
    expect(values[0], closeTo(1 / 3, 1e-10));
    expect(values[1], closeTo(.4, 1e-10));
  });
  test('Every enabled row has >=15% and shares add to one', () {
    for (var mask = 0; mask < 8; mask++) {
      for (final weights in [[.1, 10.0, .1], [9.0, .1, .1], [1.0, 1.2, .8]]) {
        final enabled = List.generate(3, (i) => (mask & (1 << i)) != 0);
        final values = LayoutConfig(rowWeights: weights, rowEnabled: enabled).fractions;
        expect(values.reduce((a, b) => a + b), closeTo(mask == 0 ? 0 : 1, 1e-10));
        for (var i = 0; i < 3; i++) {
          expect(values[i], enabled[i] ? greaterThanOrEqualTo(.15) : 0);
        }
        if (mask != 7 && mask != 0) {
          expect(values.where((v) => v > 0).toSet().length, 1);
        }
      }
    }
  });
  test('Bounds, nonfinite inputs, short lists and JSON round trip', () {
    final config = LayoutConfig(leftFraction: double.nan, fontScale: 100, rowWeights: [double.infinity], theme: 'unknown');
    expect(config.leftFraction, .58);
    expect(config.fontScale, 1.6);
    expect(config.rowWeights, [1, 1, 1]);
    expect(config.theme, 'auto');
    expect(LayoutConfig(leftFraction: -1).leftFraction, .4);
    expect(LayoutConfig.fromJson(jsonDecode(jsonEncode(config.toJson()))).toJson(), config.toJson());
    expect(() => config.rowWeights[0] = 2, throwsUnsupportedError);
  });
}
