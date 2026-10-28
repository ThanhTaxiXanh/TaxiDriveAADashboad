import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:taxi_driver_aa_dashboard/features/calendar/event_item.dart';
import 'package:taxi_driver_aa_dashboard/features/calendar/lunar_calendar.dart';

void main() {
  test('Annual solar, leap day and once-only events', () {
    final annual = EventItem(
      id: 'user_1',
      title: 'Sinh nhật',
      calendar: 'solar',
      day: 3,
      month: 2,
    );
    expect(
      annual.occurrences(DateTime.utc(2026, 2, 4)).first.date,
      DateTime.utc(2027, 2, 3),
    );
    final once = EventItem(
      id: 'user_2',
      title: 'Một lần',
      calendar: 'solar',
      day: 3,
      month: 2,
      year: 2026,
    );
    expect(once.occurrences(DateTime.utc(2026, 2, 4)), isEmpty);
    final feb29 = EventItem(
      id: 'user_3',
      title: 'Ngày nhuận',
      calendar: 'solar',
      day: 29,
      month: 2,
    );
    expect(
      feb29.occurrences(DateTime.utc(2026)).first.date,
      DateTime.utc(2028, 2, 29),
    );
  });
  test('Explicit future year remains visible beyond annual search horizon', () {
    final future = EventItem(
      id: 'user_future',
      title: 'Một lần năm 2050',
      calendar: 'solar',
      day: 1,
      month: 1,
      year: 2050,
    );
    expect(
      future.occurrences(DateTime.utc(2026)).first.date,
      DateTime.utc(2050),
    );
  });
  test('Lunar day 30 uses 29 in short months; leap month is opt-in', () {
    final plain = EventItem(
      id: 'user_4',
      title: 'Tháng sáu',
      calendar: 'lunar',
      day: 1,
      month: 6,
      year: 2025,
    );
    final both = EventItem.fromJson({...plain.toJson(), 'includeLeap': true});
    expect(plain.occurrences(DateTime.utc(2025)).length, 1);
    expect(both.occurrences(DateTime.utc(2025)).length, 2);
    expect(both.occurrences(DateTime.utc(2025)).last.leap, true);
    var checked = false;
    for (var month = 1; month <= 12; month++) {
      if (LunarCalendar.lunarToSolar(30, month, 2026, false) == null) {
        final event = EventItem(
          id: 'user_short',
          title: 'Giỗ',
          calendar: 'lunar',
          day: 30,
          month: month,
          year: 2026,
        );
        final next = event.occurrences(DateTime.utc(2026)).first;
        final lunar = LunarCalendar.solarToLunar(
          next.date.day,
          next.date.month,
          next.date.year,
        );
        expect(lunar.day, 29);
        expect(next.adjusted, true);
        checked = true;
        break;
      }
    }
    expect(checked, true);
  });
  test(
    'Seed archive, visibility, monthly toggles, sorting and backup round trip',
    () {
      final json = jsonDecode(
        File('assets/events_vn.json').readAsStringSync(),
      ) as Map<String, dynamic>;
      final archive = EventArchive.fromJson(json);
      expect(archive.events.length, 52);
      expect(archive.events.where((e) => e.monthly).length, 24);
      expect(archive.events.where((e) => e.isPublicHoliday).length, 6);
      final restored = EventArchive.fromJson(
        jsonDecode(jsonEncode(archive.toJson())),
      );
      expect(restored.toJson(), archive.toJson());
      final today = DateTime.utc(2026, 10, 28);
      final next = upcomingEvents(archive.events, today, limit: 100);
      expect(next.any((e) => e.event.monthly), false);
      expect(
        upcomingEvents(
          archive.events,
          today,
          showMonthly: true,
          limit: 100,
        ).any((e) => e.event.monthly),
        true,
      );
      expect(next.first.event.title, 'Nhà giáo Việt Nam');
      expect(next.first.daysFrom(today), 23);
      expect(
        upcomingEvents([archive.events.first.withEnabled(false)], today),
        isEmpty,
      );
    },
  );
  test(
    'Invalid import version, duplicates, impossible days and empty titles fail',
    () {
      expect(
        () => EventArchive.fromJson({'version': 2, 'events': []}),
        throwsFormatException,
      );
      expect(
        () => EventItem(
          id: 'user_bad',
          title: '',
          calendar: 'solar',
          day: 1,
          month: 1,
        ),
        throwsFormatException,
      );
      expect(
        () => EventItem(
          id: 'user_bad',
          title: 'Sai',
          calendar: 'solar',
          day: 31,
          month: 4,
        ),
        throwsFormatException,
      );
      expect(
        () => EventItem(
          id: 'user_bad',
          title: 'Sai',
          calendar: 'lunar',
          day: 31,
          month: 4,
        ),
        throwsFormatException,
      );
      final event = EventItem(
        id: 'user_dup',
        title: 'A',
        calendar: 'solar',
        day: 1,
        month: 1,
      ).toJson();
      expect(
        () => EventArchive.fromJson({
          'version': 1,
          'events': [event, event],
        }),
        throwsFormatException,
      );
    },
  );
}
