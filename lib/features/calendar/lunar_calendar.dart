import 'dart:math';

class LunarDate {
  const LunarDate(this.day, this.month, this.year, this.leap);
  final int day;
  final int month;
  final int year;
  final bool leap;
  @override
  bool operator ==(Object other) =>
      other is LunarDate &&
      day == other.day &&
      month == other.month &&
      year == other.year &&
      leap == other.leap;
  @override
  int get hashCode => Object.hash(day, month, year, leap);
  @override
  String toString() => '$day/$month/$year${leap ? " nhuận" : ""}';
}

// Port từ reference/LunarCalendar.kt, thuật toán Hồ Ngọc Đức, UTC+7.
class LunarCalendar {
  static const EPOCH = 2415021.076998695;
  static const SYNODIC = 29.530588853;
  static const TZ = 7.0;
  static const RAD = pi / 180;
  static const _can = [
    'Giáp',
    'Ất',
    'Bính',
    'Đinh',
    'Mậu',
    'Kỷ',
    'Canh',
    'Tân',
    'Nhâm',
    'Quý',
  ];
  static const _chi = [
    'Tý',
    'Sửu',
    'Dần',
    'Mão',
    'Thìn',
    'Tỵ',
    'Ngọ',
    'Mùi',
    'Thân',
    'Dậu',
    'Tuất',
    'Hợi',
  ];
  static final Map<int, int> _moonCache = {};
  static final Map<int, int> _month11Cache = {};
  static String canChi(int year) =>
      '${_can[(year + 6) % 10]} ${_chi[(year + 8) % 12]}';
  static DateTime vietnamToday([DateTime? instant]) {
    final now = (instant ?? DateTime.now()).toUtc().add(
      const Duration(hours: 7),
    );
    return DateTime.utc(now.year, now.month, now.day);
  }

  static int _jd(int dd, int mm, int yy) {
    final a = (14 - mm) ~/ 12;
    final y = yy + 4800 - a;
    final m = mm + 12 * a - 3;
    return dd +
        (153 * m + 2) ~/ 5 +
        365 * y +
        y ~/ 4 -
        y ~/ 100 +
        y ~/ 400 -
        32045;
  }

  static List<int> _date(int jd) {
    final int b;
    final int c;
    if (jd > 2299160) {
      final a = jd + 32044;
      b = (4 * a + 3) ~/ 146097;
      c = a - b * 146097 ~/ 4;
    } else {
      b = 0;
      c = jd + 32082;
    }
    final d = (4 * c + 3) ~/ 1461;
    final e = c - 1461 * d ~/ 4;
    final m = (5 * e + 2) ~/ 153;
    return [
      e - (153 * m + 2) ~/ 5 + 1,
      m + 3 - 12 * (m ~/ 10),
      b * 100 + d - 4800 + m ~/ 10,
    ];
  }

  static double _newMoon(double k) {
    final t = k / 1236.85;
    final t2 = t * t;
    final t3 = t2 * t;
    var jd1 =
        2415020.75933 + 29.53058868 * k + 0.0001178 * t2 - 0.000000155 * t3;
    jd1 += 0.00033 * sin((166.56 + 132.87 * t - 0.009173 * t2) * RAD);
    final m = 359.2242 + 29.10535608 * k - 0.0000333 * t2 - 0.00000347 * t3;
    final mpr = 306.0253 + 385.81691806 * k + 0.0107306 * t2 + 0.00001236 * t3;
    final f = 21.2964 + 390.67050646 * k - 0.0016528 * t2 - 0.00000239 * t3;
    var c1 = (0.1734 - 0.000393 * t) * sin(m * RAD);
    c1 += 0.0021 * sin(2 * m * RAD);
    c1 -= 0.4068 * sin(mpr * RAD);
    c1 += 0.0161 * sin(2 * mpr * RAD);
    c1 -= 0.0004 * sin(3 * mpr * RAD);
    c1 += 0.0104 * sin(2 * f * RAD);
    c1 -= 0.0051 * sin((m + mpr) * RAD);
    c1 -= 0.0074 * sin((m - mpr) * RAD);
    c1 += 0.0004 * sin((2 * f + m) * RAD);
    c1 -= 0.0004 * sin((2 * f - m) * RAD);
    c1 -= 0.0006 * sin((2 * f + mpr) * RAD);
    c1 += 0.0010 * sin((2 * f - mpr) * RAD);
    c1 += 0.0005 * sin((2 * mpr + m) * RAD);
    final deltaT = t < -11
        ? 0.001 +
              0.000839 * t +
              0.0002261 * t2 -
              0.00000845 * t3 -
              0.000000081 * t * t3
        : -0.000278 + 0.000265 * t + 0.000262 * t2;
    return jd1 + c1 - deltaT;
  }

  static int _moon(int k) => _moonCache.putIfAbsent(
    k,
    () => (_newMoon(k.toDouble()) + .5 + TZ / 24 + 1e-12).floor(),
  );
  static double _sun(double jdn) {
    final t = (jdn - 2451545.0) / 36525;
    final t2 = t * t;
    final m = 357.52910 + 35999.05030 * t - .0001559 * t2 - .00000048 * t * t2;
    final l0 = 280.46645 + 36000.76983 * t + .0003032 * t2;
    final dl =
        (1.914600 - .004817 * t - .000014 * t2) * sin(m * RAD) +
        (.019993 - .000101 * t) * sin(2 * m * RAD) +
        .000290 * sin(3 * m * RAD);
    final l = (l0 + dl) * RAD;
    return l - 2 * pi * (l / (2 * pi)).floor();
  }

  static int _sunIndex(int jdn) =>
      (_sun(jdn - .5 - TZ / 24) / pi * 6 + 1e-12).floor();
  static int _month11(int year) => _month11Cache.putIfAbsent(year, () {
    final k = ((_jd(31, 12, year) - EPOCH) / SYNODIC).floor();
    final nm = _moon(k);
    return _sunIndex(nm) >= 9 ? _moon(k - 1) : nm;
  });
  static int _leapOffset(int a11) {
    final k = ((a11 - EPOCH) / SYNODIC + .5).floor();
    var i = 1;
    var arc = _sunIndex(_moon(k + i));
    while (i < 15) {
      final next = _sunIndex(_moon(k + i + 1));
      if (next == arc) break;
      arc = next;
      i++;
    }
    return i;
  }

  static LunarDate solarToLunar(int dd, int mm, int yy) {
    final date = DateTime.utc(yy, mm, dd);
    if (date.year != yy || date.month != mm || date.day != dd)
      throw ArgumentError('Ngày dương không hợp lệ');
    final dayNumber = _jd(dd, mm, yy);
    final k = ((dayNumber - EPOCH) / SYNODIC).floor();
    var monthStart = _moon(k + 1);
    if (monthStart > dayNumber) monthStart = _moon(k);
    var a11 = _month11(yy);
    var b11 = a11;
    int lunarYear;
    if (a11 >= monthStart) {
      lunarYear = yy;
      a11 = _month11(yy - 1);
    } else {
      lunarYear = yy + 1;
      b11 = _month11(yy + 1);
    }
    final lunarDay = dayNumber - monthStart + 1;
    final diff = (monthStart - a11) ~/ 29;
    var lunarMonth = diff + 11;
    var leap = false;
    if (b11 - a11 > 365) {
      final leapDiff = _leapOffset(a11);
      if (diff >= leapDiff) {
        lunarMonth = diff + 10;
        if (diff == leapDiff) leap = true;
      }
    }
    if (lunarMonth > 12) lunarMonth -= 12;
    if (lunarMonth >= 11 && diff < 4) lunarYear--;
    return LunarDate(lunarDay, lunarMonth, lunarYear, leap);
  }

  // Giữ API [ngày, tháng, năm] hoặc null; kiểm tra ngược để loại ngày 30
  // không tồn tại và cờ nhuận trong năm không có tháng nhuận (bản Kotlin chưa chặn).
  static List<int>? lunarToSolar(int day, int month, int year, bool leap) {
    if (day < 1 || day > 30 || month < 1 || month > 12) return null;
    final a11 = _month11(month < 11 ? year - 1 : year);
    final b11 = _month11(month < 11 ? year : year + 1);
    final k = (.5 + (a11 - EPOCH) / SYNODIC).floor();
    var off = month - 11;
    if (off < 0) off += 12;
    if (b11 - a11 > 365) {
      final leapOff = _leapOffset(a11);
      var leapMonth = leapOff - 2;
      if (leapMonth < 0) leapMonth += 12;
      if (leap && month != leapMonth) return null;
      if (leap || off >= leapOff) off++;
    } else if (leap) {
      return null;
    }
    final result = _date(_moon(k + off) + day - 1);
    return solarToLunar(result[0], result[1], result[2]) ==
            LunarDate(day, month, year, leap)
        ? result
        : null;
  }
}
