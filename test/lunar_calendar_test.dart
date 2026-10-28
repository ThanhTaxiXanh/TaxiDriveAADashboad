import 'package:flutter_test/flutter_test.dart';
import 'package:taxi_driver_aa_dashboard/features/calendar/lunar_calendar.dart';

void main() {
  test('Tet and can chi reference vectors', () {
    for (final values in [
      [10, 2, 2024],
      [29, 1, 2025],
      [17, 2, 2026],
      [6, 2, 2027],
    ]) {
      expect(
        LunarCalendar.solarToLunar(values[0], values[1], values[2]),
        LunarDate(1, 1, values[2], false),
      );
    }
    expect(LunarCalendar.canChi(2024), 'Giáp Thìn');
    expect(LunarCalendar.canChi(2026), 'Bính Ngọ');
    expect(
      LunarCalendar.solarToLunar(25, 7, 2025),
      const LunarDate(1, 6, 2025, true),
    );
    expect(
      LunarCalendar.solarToLunar(22, 3, 2023),
      const LunarDate(1, 2, 2023, true),
    );
  });
  test('Every civil day 2000–2050 survives solar/lunar round trip', () {
    var count = 0;
    for (
      var day = DateTime.utc(2000);
      day.isBefore(DateTime.utc(2051));
      day = day.add(const Duration(days: 1))
    ) {
      final lunar = LunarCalendar.solarToLunar(day.day, day.month, day.year);
      final roundTrip = LunarCalendar.lunarToSolar(
        lunar.day,
        lunar.month,
        lunar.year,
        lunar.leap,
      );
      expect(roundTrip, [
        day.day,
        day.month,
        day.year,
      ], reason: '$day -> $lunar');
      count++;
    }
    expect(count, 18628);
  });
  test('Reject absent lunar days and leap flags rather than silently rolling dates', () {
    expect(LunarCalendar.lunarToSolar(31, 1, 2026, false), isNull);
    expect(LunarCalendar.lunarToSolar(1, 1, 2026, true), isNull);
    expect(LunarCalendar.lunarToSolar(1, 5, 2025, true), isNull);
    expect(() => LunarCalendar.solarToLunar(30, 2, 2026), throwsArgumentError);
  });
  test('Vietnam day changes at 17:00 UTC regardless of device zone', () {
    expect(
      LunarCalendar.vietnamToday(DateTime.utc(2026, 2, 16, 16, 59)),
      DateTime.utc(2026, 2, 16),
    );
    expect(
      LunarCalendar.vietnamToday(DateTime.utc(2026, 2, 16, 17)),
      DateTime.utc(2026, 2, 17),
    );
  });
}
