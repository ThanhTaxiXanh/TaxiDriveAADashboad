import 'lunar_calendar.dart';

class EventItem {
  EventItem({
    required this.id,
    required this.title,
    required this.calendar,
    required this.day,
    required this.month,
    this.year,
    this.isPublicHoliday = false,
    this.color = 0xff41b69b,
    this.note = '',
    this.source = 'user',
    this.enabled = true,
    this.includeLeap = false,
  }) {
    if (!RegExp(r'^[A-Za-z0-9_-]{1,80}$').hasMatch(id) ||
        title.trim().isEmpty ||
        title.length > 120 ||
        note.length > 2000 ||
        !['solar', 'lunar'].contains(calendar) ||
        !['seed', 'user'].contains(source) ||
        month < 1 ||
        month > 12 ||
        day < 1 ||
        day >
            (calendar == 'lunar'
                ? 30
                : DateTime.utc(year ?? 2000, month + 1, 0).day) ||
        (year != null && (year! < 1900 || year! > 2100)) ||
        color < 0 ||
        color > 0xffffffff)
      throw FormatException('Sự kiện có trường không hợp lệ');
    if (source == 'user' && !RegExp(r'^user_[A-Za-z0-9_-]{1,75}$').hasMatch(id))
      throw FormatException('ID sự kiện riêng không hợp lệ');
  }
  final String id;
  final String title;
  final String calendar;
  final int day;
  final int month;
  final int? year;
  final bool isPublicHoliday;
  final int color;
  final String note;
  final String source;
  final bool enabled;
  final bool includeLeap;
  bool get monthly => id.startsWith('seed_monthly_');
  factory EventItem.fromJson(Map<String, dynamic> json) => EventItem(
    id: json['id'] as String,
    title: json['title'] as String,
    calendar: json['calendar'] as String,
    day: json['day'] as int,
    month: json['month'] as int,
    year: json['year'] as int?,
    isPublicHoliday: json['isPublicHoliday'] as bool? ?? false,
    color: json['color'] as int? ?? 0xff41b69b,
    note: json['note'] as String? ?? '',
    source: json['source'] as String? ?? 'user',
    enabled: json['enabled'] as bool? ?? true,
    includeLeap: json['includeLeap'] as bool? ?? false,
  );
  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'calendar': calendar,
    'day': day,
    'month': month,
    'year': year,
    'isPublicHoliday': isPublicHoliday,
    'color': color,
    'note': note,
    'source': source,
    'enabled': enabled,
    'includeLeap': includeLeap,
  };
  EventItem withEnabled(bool value) =>
      EventItem.fromJson({...toJson(), 'enabled': value});
  List<EventOccurrence> occurrences(DateTime from, {int yearsAhead = 6}) {
    if (!enabled) return [];
    final today = DateTime.utc(from.year, from.month, from.day);
    final end = DateTime.utc(today.year + yearsAhead, today.month, today.day);
    final result = <EventOccurrence>[];
    final startYear = year ?? today.year - 1;
    final lastYear = year ?? today.year + yearsAhead;
    for (var y = startYear; y <= lastYear; y++) {
      if (calendar == 'solar') {
        final date = DateTime.utc(y, month, day);
        if (date.month == month &&
            date.day == day &&
            !date.isBefore(today) &&
            (year != null || !date.isAfter(end)))
          result.add(EventOccurrence(this, date));
      } else {
        for (final leap in includeLeap ? [false, true] : [false]) {
          var solar = LunarCalendar.lunarToSolar(day, month, y, leap);
          var adjusted = false;
          if (solar == null && day == 30) {
            solar = LunarCalendar.lunarToSolar(29, month, y, leap);
            adjusted = solar != null;
          }
          if (solar != null) {
            final date = DateTime.utc(solar[2], solar[1], solar[0]);
            if (!date.isBefore(today) && (year != null || !date.isAfter(end)))
              result.add(
                EventOccurrence(this, date, leap: leap, adjusted: adjusted),
              );
          }
        }
      }
    }
    result.sort((a, b) => a.date.compareTo(b.date));
    return result;
  }
}

class EventOccurrence {
  const EventOccurrence(
    this.event,
    this.date, {
    this.leap = false,
    this.adjusted = false,
  });
  final EventItem event;
  final DateTime date;
  final bool leap;
  final bool adjusted;
  int daysFrom(DateTime today) =>
      date.difference(DateTime.utc(today.year, today.month, today.day)).inDays;
}

List<EventOccurrence> upcomingEvents(
  List<EventItem> events,
  DateTime today, {
  bool showMonthly = false,
  int limit = 20,
}) {
  final values = <EventOccurrence>[];
  for (final event in events) {
    if (!showMonthly && event.monthly) continue;
    final next = event.occurrences(today);
    if (next.isNotEmpty) values.add(next.first);
  }
  values.sort((a, b) {
    final order = a.date.compareTo(b.date);
    return order != 0 ? order : a.event.title.compareTo(b.event.title);
  });
  return values.take(limit).toList();
}

class EventArchive {
  EventArchive(this.events, {this.showMonthly = false});
  final List<EventItem> events;
  final bool showMonthly;
  factory EventArchive.fromJson(Map<String, dynamic> json) {
    if (json['version'] != 1 ||
        json['events'] is! List ||
        (json['events'] as List).length > 1000)
      throw FormatException('Không phải tệp sự kiện phiên bản 1');
    final events = (json['events'] as List)
        .map(
          (value) =>
              EventItem.fromJson(Map<String, dynamic>.from(value as Map)),
        )
        .toList();
    if (events.map((e) => e.id).toSet().length != events.length)
      throw FormatException('ID sự kiện bị trùng');
    return EventArchive(
      events,
      showMonthly: json['showMonthly'] as bool? ?? false,
    );
  }
  Map<String, dynamic> toJson() => {
    'version': 1,
    'events': events.map((e) => e.toJson()).toList(),
    'showMonthly': showMonthly,
  };
}
