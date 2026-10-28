import 'package:flutter/material.dart';
import 'calendar_store.dart';
import 'event_item.dart';
import 'lunar_calendar.dart';

class EventScreen extends StatefulWidget {
  const EventScreen({super.key, required this.store});
  final CalendarStore store;
  @override
  State<EventScreen> createState() => _EventScreenState();
}
class _EventScreenState extends State<EventScreen> {
  String? error;
  Future<void> action(Future<void> Function() work) async {
    try { await work(); if (mounted) setState(() => error = null); }
    catch (_) { if (mounted) setState(() => error = 'Không thực hiện được. Kiểm tra tệp, ngày và thử lại.'); }
  }
  Future<void> importFile() => action(() async {
    final archive = await widget.store.pickImport();
    if (archive == null || !mounted) return;
    final confirmed = await showDialog<bool>(context: context, builder: (context) => AlertDialog(title: const Text('Nhập gộp sự kiện?'), content: Text('${archive.events.length} mục. ID trùng được cập nhật; sự kiện cũ không có trong tệp vẫn giữ. Mục khởi tạo chỉ cập nhật ẩn/hiện.'), actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Hủy')), FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Nhập gộp'))]));
    if (confirmed == true) await widget.store.importArchive(archive);
  });
  Future<void> checkDate() async {
    final today = LunarCalendar.vietnamToday();
    final date = await showDatePicker(context: context, initialDate: today, firstDate: DateTime(2000), lastDate: DateTime(2050, 12, 31));
    if (date == null || !mounted) return;
    final lunar = LunarCalendar.solarToLunar(date.day, date.month, date.year);
    await showDialog<void>(context: context, builder: (context) => AlertDialog(title: const Text('Đối chiếu Âm/Dương'), content: Text('Dương: ${date.day}/${date.month}/${date.year}\nÂm: $lunar\nNăm ${LunarCalendar.canChi(lunar.year)}\nMúi giờ Việt Nam UTC+7'), actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Đóng'))]));
  }
  @override
  Widget build(BuildContext context) => ListenableBuilder(listenable: widget.store, builder: (context, _) {
    final store = widget.store;
    final events = store.events.where((e) => !e.monthly || store.showMonthly).toList()..sort((a, b) { final source = b.source.compareTo(a.source); return source != 0 ? source : a.title.compareTo(b.title); });
    return Scaffold(appBar: AppBar(title: const Text('Lịch và sự kiện')), floatingActionButton: FloatingActionButton.extended(onPressed: store.ready ? () => showDialog<void>(context: context, builder: (_) => EventEditor(store: store)) : null, icon: const Icon(Icons.add), label: const Text('Thêm sự kiện')), body: ListView(padding: const EdgeInsets.only(bottom: 96), children: [
      Padding(padding: const EdgeInsets.all(16), child: Wrap(spacing: 8, runSpacing: 8, children: [OutlinedButton(onPressed: checkDate, child: const Text('Đối chiếu một ngày')), OutlinedButton(onPressed: store.ready ? () => action(store.export) : null, child: const Text('Xuất JSON')), OutlinedButton(onPressed: store.ready ? importFile : null, child: const Text('Nhập JSON'))])),
      SwitchListTile(title: const Text('Mùng Một và ngày Rằm hằng tháng'), value: store.showMonthly, onChanged: store.ready ? (value) => action(() => store.setMonthly(value)) : null),
      const Padding(padding: EdgeInsets.all(16), child: Text('Mốc ngày lễ không phải lịch nghỉ bù. Sự kiện khởi tạo chỉ ẩn/hiện; sự kiện riêng được sửa và xóa. Trên xe chỉ đọc.')),
      if (!store.ready) const LinearProgressIndicator(),
      if (error != null || store.error != null) Padding(padding: const EdgeInsets.all(16), child: Text(error ?? store.error!)),
      for (final event in events) ListTile(
        leading: CircleAvatar(backgroundColor: Color(event.color), child: Icon(event.calendar == 'lunar' ? Icons.nightlight_round : Icons.event, color: Colors.white)),
        title: Text(event.title, maxLines: 2, overflow: TextOverflow.ellipsis),
        subtitle: Text('${event.day}/${event.month}${event.year == null ? " hằng năm" : "/${event.year}"} · ${event.calendar == "lunar" ? "Âm lịch" : "Dương lịch"}${event.includeLeap ? " · cả tháng nhuận" : ""}${event.isPublicHoliday ? " · Mốc ngày lễ" : ""}${event.note.isEmpty ? "" : "\n${event.note}"}', maxLines: 3, overflow: TextOverflow.ellipsis),
        onTap: event.source == 'user' ? () => showDialog<void>(context: context, builder: (_) => EventEditor(store: store, event: event)) : null,
        trailing: Row(mainAxisSize: MainAxisSize.min, children: [Switch(value: event.enabled, onChanged: (value) => action(() => store.toggle(event, value))), if (event.source == 'user') IconButton(tooltip: 'Xóa sự kiện', icon: const Icon(Icons.delete_outline), onPressed: () async {
          final confirmed = await showDialog<bool>(context: context, builder: (context) => AlertDialog(title: const Text('Xóa sự kiện riêng?'), content: Text(event.title), actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Hủy')), FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Xóa'))]));
          if (confirmed == true) await action(() => store.delete(event));
        })]),
      ),
    ]));
  });
}

class EventEditor extends StatefulWidget {
  const EventEditor({super.key, required this.store, this.event});
  final CalendarStore store;
  final EventItem? event;
  @override
  State<EventEditor> createState() => _EventEditorState();
}
class _EventEditorState extends State<EventEditor> {
  late final title = TextEditingController(text: widget.event?.title ?? '');
  late final note = TextEditingController(text: widget.event?.note ?? '');
  late final year = TextEditingController(text: '${widget.event?.year ?? LunarCalendar.vietnamToday().year}');
  late String calendar = widget.event?.calendar ?? 'solar';
  late int day = widget.event?.day ?? 1;
  late int month = widget.event?.month ?? 1;
  late bool annual = widget.event?.year == null;
  late bool includeLeap = widget.event?.includeLeap ?? false;
  late int color = widget.event?.color ?? 0xff41b69b;
  bool saving = false;
  String? error;
  static const colors = [0xff41b69b, 0xffe75b52, 0xff4385db, 0xff9b59b6, 0xffcf7c20];
  @override
  void dispose() { title.dispose(); note.dispose(); year.dispose(); super.dispose(); }
  Future<void> save() async {
    try {
      final selectedYear = annual ? null : int.tryParse(year.text);
      if (!annual && selectedYear == null) throw FormatException();
      final event = EventItem(id: widget.event?.id ?? 'user_${DateTime.now().microsecondsSinceEpoch}', title: title.text.trim(), calendar: calendar, day: day, month: month, year: selectedYear, note: note.text, color: color, includeLeap: calendar == 'lunar' && includeLeap, enabled: widget.event?.enabled ?? true);
      setState(() { saving = true; error = null; });
      await widget.store.save(event);
      if (mounted) Navigator.pop(context);
    } catch (_) { if (mounted) setState(() { saving = false; error = 'Tên hoặc ngày không hợp lệ. Năm phải từ 1900 đến 2100.'; }); }
  }
  @override
  Widget build(BuildContext context) => AlertDialog(title: Text(widget.event == null ? 'Thêm sự kiện riêng' : 'Sửa sự kiện'), content: SizedBox(width: 440, child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
    TextField(controller: title, maxLength: 120, decoration: const InputDecoration(labelText: 'Tên sự kiện')),
    DropdownButtonFormField<String>(initialValue: calendar, items: const [DropdownMenuItem(value: 'solar', child: Text('Dương lịch')), DropdownMenuItem(value: 'lunar', child: Text('Âm lịch'))], onChanged: saving ? null : (value) => setState(() { calendar = value!; if (calendar == 'lunar' && day > 30) day = 30; })),
    Row(children: [Expanded(child: DropdownButtonFormField<int>(key: ValueKey('$calendar-$day'), initialValue: day, decoration: const InputDecoration(labelText: 'Ngày'), items: List.generate(calendar == 'lunar' ? 30 : 31, (i) => DropdownMenuItem(value: i + 1, child: Text('${i + 1}'))), onChanged: saving ? null : (value) => setState(() => day = value!))), const SizedBox(width: 16), Expanded(child: DropdownButtonFormField<int>(initialValue: month, decoration: const InputDecoration(labelText: 'Tháng'), items: List.generate(12, (i) => DropdownMenuItem(value: i + 1, child: Text('${i + 1}'))), onChanged: saving ? null : (value) => setState(() => month = value!)))]),
    SwitchListTile(contentPadding: EdgeInsets.zero, title: const Text('Lặp hằng năm'), value: annual, onChanged: saving ? null : (value) => setState(() => annual = value)),
    if (!annual) TextField(controller: year, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Năm theo lịch đã chọn')),
    if (calendar == 'lunar') SwitchListTile(contentPadding: EdgeInsets.zero, title: const Text('Tính cả tháng nhuận'), subtitle: const Text('Mặc định chỉ tháng thường. Ngày 30 không có sẽ dùng ngày 29.'), value: includeLeap, onChanged: saving ? null : (value) => setState(() => includeLeap = value)),
    DropdownButtonFormField<int>(initialValue: color, decoration: const InputDecoration(labelText: 'Màu'), items: [for (final value in {...colors, color}) DropdownMenuItem(value: value, child: Row(children: [Icon(Icons.circle, color: Color(value)), const SizedBox(width: 12), Text(value == 0xff41b69b ? 'Xanh Taxi' : value == 0xffe75b52 ? 'Đỏ' : value == 0xff4385db ? 'Xanh dương' : value == 0xff9b59b6 ? 'Tím' : 'Cam')]))], onChanged: saving ? null : (value) => setState(() => color = value!)),
    TextField(controller: note, maxLength: 2000, maxLines: 3, decoration: const InputDecoration(labelText: 'Ghi chú riêng')),
    if (error != null) Text(error!),
  ]))), actions: [TextButton(onPressed: saving ? null : () => Navigator.pop(context), child: const Text('Hủy')), FilledButton(onPressed: saving ? null : save, child: Text(saving ? 'Đang lưu…' : 'Lưu'))]);
}
