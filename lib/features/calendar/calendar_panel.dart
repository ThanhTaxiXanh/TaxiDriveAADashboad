import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'event_item.dart';
import 'lunar_calendar.dart';

class CalendarPanel extends StatefulWidget {
  const CalendarPanel({
    super.key,
    this.events = const [],
    this.showMonthly = false,
    this.today,
    this.fontScale = 1,
    this.expanded = false,
    this.initialPage = 0,
    this.onExpand,
    this.onCollapse,
  });
  final List<EventItem> events;
  final bool showMonthly;
  final DateTime? today;
  final double fontScale;
  final bool expanded;
  final int initialPage;
  final ValueChanged<int>? onExpand;
  final VoidCallback? onCollapse;
  @override
  State<CalendarPanel> createState() => _CalendarPanelState();
}

class _CalendarPanelState extends State<CalendarPanel> {
  late int page = widget.initialPage;
  DateTime? displayed;
  DateTime? selected;
  static const weekdays = [
    'Thứ Hai',
    'Thứ Ba',
    'Thứ Tư',
    'Thứ Năm',
    'Thứ Sáu',
    'Thứ Bảy',
    'Chủ Nhật',
  ];
  String solarText(DateTime date) => '${date.day}/${date.month}/${date.year}';
  @override
  Widget build(BuildContext context) {
    final today = widget.today ?? LunarCalendar.vietnamToday();
    final lunar = LunarCalendar.solarToLunar(
      today.day,
      today.month,
      today.year,
    );
    final next = upcomingEvents(
      widget.events,
      today,
      showMonthly: widget.showMonthly,
    );
    return LayoutBuilder(
      builder: (context, box) {
        final compact = box.maxHeight < 155;
        final titleSize = math.min(
          math.max(22.0, 24 * widget.fontScale),
          math.max(22.0, (box.maxHeight - 16) / 1.5),
        );
        final bodySize = math.max(16.0, 18 * widget.fontScale);
        Widget heading() => Row(
          children: [
            Expanded(
              child: InkWell(
                key: const ValueKey('calendar-cycle'),
                onTap: () => setState(() => page = (page + 1) % 3),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Text(
                    ['Hôm nay', 'Lưới tháng', 'Sự kiện gần nhất'][page],
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: titleSize,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
            if (!widget.expanded && widget.onExpand != null)
              IconButton(
                tooltip: 'Mở lịch đầy đủ',
                onPressed: () => widget.onExpand!(page),
                icon: const Icon(Icons.open_in_full),
              ),
          ],
        );
        if (compact) {
          return Padding(
            padding: const EdgeInsets.all(4),
            child: Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () => setState(() => page = (page + 1) % 3),
                    child: Text(
                      page == 0
                          ? '${today.day}/${today.month} · ${lunar.day}/${lunar.month}${lunar.leap ? "N" : ""} âm'
                          : page == 1
                          ? 'Tháng ${today.month}'
                          : next.isEmpty
                          ? 'Chưa có sự kiện'
                          : next.first.event.title,
                      maxLines: box.maxHeight > 85 ? 2 : 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: titleSize),
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Mở lịch đầy đủ',
                  onPressed: widget.onExpand == null
                      ? null
                      : () => widget.onExpand!(page),
                  icon: const Icon(Icons.open_in_full),
                ),
              ],
            ),
          );
        }
        Widget body;
        if (page == 0) {
          final lines = <Widget>[
            Text(
              '${weekdays[today.weekday - 1]} · ${solarText(today)}',
              style: TextStyle(
                fontSize: math.max(22, 28 * widget.fontScale),
                fontWeight: FontWeight.bold,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              'Âm: $lunar',
              style: TextStyle(fontSize: bodySize),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              'Năm ${LunarCalendar.canChi(lunar.year)}',
              style: TextStyle(fontSize: bodySize),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ];
          for (final item in next.take(3)) {
            lines.add(
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 8, right: 6),
                    child: Icon(
                      Icons.circle,
                      size: 8,
                      color: Color(item.event.color),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      '${item.event.title} · ${item.daysFrom(today) == 0 ? "Hôm nay" : "còn ${item.daysFrom(today)} ngày"}',
                      style: TextStyle(fontSize: bodySize),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            );
          }
          body = SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: lines,
            ),
          );
        } else if (page == 1) {
          if (box.maxHeight < 370) {
            body = Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Tháng ${today.month}/${today.year}',
                  style: TextStyle(fontSize: bodySize),
                ),
                Text(
                  'Âm hôm nay: $lunar',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: bodySize),
                ),
                TextButton(
                  onPressed: widget.onExpand == null
                      ? null
                      : () => widget.onExpand!(1),
                  child: const Text('Xem tháng đầy đủ'),
                ),
              ],
            );
          } else {
            body = monthGrid(today);
          }
        } else {
          body = next.isEmpty
              ? const Text(
                  'Chưa có sự kiện đang bật',
                  style: TextStyle(fontSize: 16),
                )
              : ListView(
                  children: [
                    for (final item in next)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Text(
                          '${item.event.title}\n${solarText(item.date)} · ${item.daysFrom(today) == 0 ? "Hôm nay" : "còn ${item.daysFrom(today)} ngày"}${item.leap ? " · tháng nhuận" : ""}${item.adjusted ? " · 29 thay 30 âm" : ""}',
                          style: TextStyle(fontSize: bodySize),
                        ),
                      ),
                  ],
                );
        }
        return InkWell(
          onTap: () => setState(() => page = (page + 1) % 3),
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (widget.expanded)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton(
                      onPressed: widget.onCollapse,
                      child: const Text('Thu gọn lịch'),
                    ),
                  ),
                heading(),
                Expanded(child: body),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget monthGrid(DateTime today) {
    final month = displayed ?? DateTime.utc(today.year, today.month);
    final chosen = selected ?? today;
    final lunar = LunarCalendar.solarToLunar(
      chosen.day,
      chosen.month,
      chosen.year,
    );
    final start = month.weekday - 1;
    final days = DateTime.utc(month.year, month.month + 1, 0).day;
    final cells = ((start + days + 6) ~/ 7) * 7;
    return SingleChildScrollView(
      child: Column(
        children: [
          Row(
            children: [
              IconButton(
                tooltip: 'Tháng trước',
                onPressed: month.year <= 2000 && month.month == 1
                    ? null
                    : () => setState(() {
                        displayed = DateTime.utc(month.year, month.month - 1);
                        selected = displayed;
                      }),
                icon: const Icon(Icons.chevron_left),
              ),
              Expanded(
                child: Text(
                  '${month.month}/${month.year}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 22),
                ),
              ),
              IconButton(
                tooltip: 'Tháng sau',
                onPressed: month.year >= 2050 && month.month == 12
                    ? null
                    : () => setState(() {
                        displayed = DateTime.utc(month.year, month.month + 1);
                        selected = displayed;
                      }),
                icon: const Icon(Icons.chevron_right),
              ),
            ],
          ),
          Row(
            children: [
              for (final day in ['T2', 'T3', 'T4', 'T5', 'T6', 'T7', 'CN'])
                Expanded(
                  child: Text(
                    day,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 16),
                  ),
                ),
            ],
          ),
          SizedBox(
            height: cells / 7 * 40,
            child: LayoutBuilder(
              builder: (context, box) => GridView.builder(
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 7,
                  childAspectRatio:
                      (box.maxWidth / 7) / (box.maxHeight / (cells / 7)),
                ),
                itemCount: cells,
                itemBuilder: (context, index) {
                  final day = index - start + 1;
                  if (day < 1 || day > days) return const SizedBox();
                  final date = DateTime.utc(month.year, month.month, day);
                  final lunar = LunarCalendar.solarToLunar(
                    day,
                    month.month,
                    month.year,
                  );
                  final isSelected =
                      chosen.year == date.year &&
                      chosen.month == date.month &&
                      chosen.day == day;
                  return InkWell(
                    onTap: () => setState(() => selected = date),
                    child: Container(
                      decoration: BoxDecoration(
                        color: isSelected
                            ? Theme.of(context).colorScheme.primaryContainer
                            : null,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      alignment: Alignment.center,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '$day',
                            style: const TextStyle(fontSize: 18, height: 1),
                          ),
                          Text(
                            '${lunar.day}',
                            style: TextStyle(
                              fontSize: 16,
                              height: 1,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          Text(
            '${solarText(chosen)} · Âm $lunar',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 16),
          ),
        ],
      ),
    );
  }
}
