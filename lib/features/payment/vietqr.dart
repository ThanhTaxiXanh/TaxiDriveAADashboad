import 'dart:convert';

// NAPAS account-transfer profile. All generated values use ASCII, so TLV
// byte lengths and Dart string lengths are identical.
class VietQr {
  const VietQr({
    required this.bin,
    required this.account,
    this.amount = '',
    this.note = '',
  });
  final String bin;
  final String account;
  final String amount;
  final String note;

  static int crc16(String value) {
    var crc = 0xffff;
    for (final byte in utf8.encode(value)) {
      crc ^= byte << 8;
      for (var bit = 0; bit < 8; bit++) {
        crc = ((crc << 1) ^ ((crc & 0x8000) != 0 ? 0x1021 : 0)) & 0xffff;
      }
    }
    return crc;
  }

  static String tlv(String tag, String value) {
    if (!RegExp(r'^\d{2}$').hasMatch(tag) ||
        value.length > 99 ||
        !isAscii(value)) {
      throw const FormatException('Trường QR không hợp lệ');
    }
    return '$tag${value.length.toString().padLeft(2, '0')}$value';
  }

  static bool isAscii(String text) =>
      text.codeUnits.every((c) => c >= 32 && c <= 126);
  static String asciiNote(String text) {
    const groups = [
      'àáạảãâầấậẩẫăằắặẳẵ',
      'èéẹẻẽêềếệểễ',
      'ìíịỉĩ',
      'òóọỏõôồốộổỗơờớợởỡ',
      'ùúụủũưừứựửữ',
      'ỳýỵỷỹ',
      'đ',
    ];
    const letters = 'aeiouyd';
    var value = text.toLowerCase();
    for (var i = 0; i < groups.length; i++) {
      for (final rune in groups[i].runes) {
        value = value.replaceAll(String.fromCharCode(rune), letters[i]);
      }
    }
    // Also remove combining accents from decomposed Vietnamese input.
    return value
        .replaceAll(RegExp(r'[\u0300-\u036f]'), '')
        .toUpperCase()
        .replaceAll(RegExp(r'[^A-Z0-9 .,_-]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  String build() {
    if (!RegExp(r'^\d{6}$').hasMatch(bin) ||
        !RegExp(r'^[A-Za-z0-9]{1,19}$').hasMatch(account)) {
      throw const FormatException(
        'Kiểm tra ngân hàng và số tài khoản (1–19 chữ/số)',
      );
    }
    if (amount.isNotEmpty && !RegExp(r'^[1-9][0-9]{0,11}$').hasMatch(amount)) {
      throw const FormatException(
        'Số tiền phải là số nguyên VND từ 1 đến 999999999999',
      );
    }
    final content = asciiNote(note);
    if (content.length > 50)
      throw const FormatException('Nội dung sau khi bỏ dấu tối đa 50 ký tự');
    final merchant =
        tlv('00', 'A000000727') +
        tlv('01', tlv('00', bin) + tlv('01', account)) +
        tlv('02', 'QRIBFTTA');
    final body =
        tlv('00', '01') +
        tlv('01', amount.isEmpty ? '11' : '12') +
        tlv('38', merchant) +
        tlv('53', '704') +
        (amount.isEmpty ? '' : tlv('54', amount)) +
        tlv('58', 'VN') +
        (content.isEmpty ? '' : tlv('62', tlv('08', content))) +
        '6304';
    return '$body${crc16(body).toRadixString(16).toUpperCase().padLeft(4, '0')}';
  }

  static Map<String, String> parseTlv(String text) {
    final fields = <String, String>{};
    var offset = 0;
    while (offset < text.length) {
      if (offset + 4 > text.length) throw const FormatException('TLV bị cắt');
      final tag = text.substring(offset, offset + 2);
      final lengthText = text.substring(offset + 2, offset + 4);
      if (!RegExp(r'^\d{2}$').hasMatch(tag) ||
          !RegExp(r'^\d{2}$').hasMatch(lengthText) ||
          fields.containsKey(tag))
        throw const FormatException('TLV sai hoặc trùng');
      final end = offset + 4 + int.parse(lengthText);
      if (end > text.length) throw const FormatException('Độ dài TLV sai');
      fields[tag] = text.substring(offset + 4, end);
      offset = end;
    }
    return fields;
  }

  static VietQr parse(String payload) {
    if (payload.length > 1024 ||
        !isAscii(payload) ||
        payload.length < 8 ||
        payload.substring(payload.length - 8, payload.length - 4) != '6304')
      throw const FormatException('Không phải VietQR tài khoản được hỗ trợ');
    final expected = crc16(
      payload.substring(0, payload.length - 4),
    ).toRadixString(16).toUpperCase().padLeft(4, '0');
    if (payload.substring(payload.length - 4).toUpperCase() != expected)
      throw const FormatException('CRC không đúng');
    final f = parseTlv(payload);
    if (f['00'] != '01' ||
        !['11', '12'].contains(f['01']) ||
        f['53'] != '704' ||
        f['58'] != 'VN' ||
        f.keys.last != '63')
      throw const FormatException('Sai cấu trúc VietQR');
    final m = parseTlv(f['38'] ?? '');
    if (m['00'] != 'A000000727' || m['02'] != 'QRIBFTTA')
      throw const FormatException('Không phải chuyển khoản tài khoản NAPAS');
    final a = parseTlv(m['01'] ?? '');
    final qr = VietQr(
      bin: a['00'] ?? '',
      account: a['01'] ?? '',
      amount: f['54'] ?? '',
      note: parseTlv(f['62'] ?? '')['08'] ?? '',
    );
    qr.build(); // Validate supported bank/account/amount lengths; preserve original payload when redrawing.
    return qr;
  }
}
