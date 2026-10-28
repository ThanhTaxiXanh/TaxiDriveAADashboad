import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../../core/car_bridge.dart';
import 'event_item.dart';

class CalendarStore extends ChangeNotifier {
  CalendarStore({this.connected = true}) {
    if (connected) {
      subscription = CarBridge.watch().listen((event) {
        final next = event['calendarRevision'] as int? ?? 0;
        if (next != revision) { revision = next; unawaited(reload()); }
      });
      unawaited(reload());
    }
  }
  final bool connected;
  List<EventItem> events = [];
  bool showMonthly = false;
  bool ready = false;
  String? error;
  int revision = -1;
  int generation = 0;
  bool closed = false;
  StreamSubscription<Map<String, dynamic>>? subscription;
  static const files = MethodChannel('taxi/calendar_files');
  Future<void> reload() async {
    final token = ++generation;
    try {
      final raw = await CarBridge.methods.invokeMethod<String>('getCalendar');
      final archive = EventArchive.fromJson(jsonDecode(raw!) as Map<String, dynamic>);
      if (closed || token != generation) return;
      events = List.unmodifiable(archive.events);
      showMonthly = archive.showMonthly;
      ready = true;
      error = null;
      notifyListeners();
    } catch (_) { if (!closed && token == generation) { error = 'Không đọc được sự kiện. Hãy thử mở lại ứng dụng.'; notifyListeners(); } }
  }
  Future<void> save(EventItem event) => CarBridge.methods.invokeMethod('saveEvent', {'event': jsonEncode(event.toJson())});
  Future<void> toggle(EventItem event, bool enabled) => CarBridge.methods.invokeMethod('toggleEvent', {'id': event.id, 'enabled': enabled});
  Future<void> delete(EventItem event) => CarBridge.methods.invokeMethod('deleteEvent', {'id': event.id});
  Future<void> setMonthly(bool enabled) => CarBridge.methods.invokeMethod('setMonthly', {'enabled': enabled});
  Future<void> export() => files.invokeMethod('export', {'json': jsonEncode(EventArchive(events, showMonthly: showMonthly).toJson())});
  Future<EventArchive?> pickImport() async {
    final raw = await files.invokeMethod<String>('import');
    if (raw == null) return null;
    return EventArchive.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  }
  Future<void> importArchive(EventArchive archive) => CarBridge.methods.invokeMethod('importCalendar', {'json': jsonEncode(archive.toJson())});
  @override
  void dispose() { closed = true; subscription?.cancel(); super.dispose(); }
}
