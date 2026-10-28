import 'package:flutter_test/flutter_test.dart';
import 'package:taxi_driver_aa_dashboard/features/payment/vietqr.dart';

void main() {
  test(
    'CRC-CCITT-FALSE published check value and Vietnamese normalization',
    () {
      expect(VietQr.crc16('123456789'), 0x29b1);
      expect(
        VietQr.asciiNote('Thanh toán cước xe — Đặng Ánh'),
        'THANH TOAN CUOC XE DANG ANH',
      );
      expect(VietQr.asciiNote('Đa\u0306\u0323ng'), 'DANG');
    },
  );
  test('Static and dynamic NAPAS payload fields and round trips', () {
    for (final qr in [
      const VietQr(bin: '970436', account: '0123456789'),
      const VietQr(
        bin: '970422',
        account: '001234567890',
        amount: '250000',
        note: 'Cuốc xe sân bay',
      ),
      const VietQr(
        bin: '970416',
        account: 'ABC0123456789012345',
        amount: '999999999999',
        note: '12345678901234567890123456789012345678901234567890',
      ),
    ]) {
      final payload = qr.build();
      final parsed = VietQr.parse(payload);
      expect(parsed.bin, qr.bin);
      expect(parsed.account, qr.account);
      expect(parsed.amount, qr.amount);
      expect(parsed.note, VietQr.asciiNote(qr.note));
      expect(parsed.build(), payload);
      final fields = VietQr.parseTlv(payload);
      expect(fields['01'], qr.amount.isEmpty ? '11' : '12');
      expect(fields['53'], '704');
      expect(fields['58'], 'VN');
      final merchant = VietQr.parseTlv(fields['38']!);
      expect(merchant['00'], 'A000000727');
      expect(merchant['02'], 'QRIBFTTA');
    }
  });
  test(
    'CRC corruption, truncation, duplicate TLV, unsupported profile fail',
    () {
      final payload = const VietQr(
        bin: '970436',
        account: '0123456789',
      ).build();
      expect(
        () => VietQr.parse(payload.replaceFirst('970436', '970437')),
        throwsFormatException,
      );
      expect(() => VietQr.parse(payload.substring(1)), throwsFormatException);
      expect(() => VietQr.parseTlv('000201000201'), throwsFormatException);
      expect(() => VietQr.parseTlv('0006ABC'), throwsFormatException);
      final body = payload
          .substring(0, payload.length - 4)
          .replaceFirst('QRIBFTTA', 'QRIBFTTC');
      expect(
        () => VietQr.parse(
          '$body${VietQr.crc16(body).toRadixString(16).padLeft(4, '0')}',
        ),
        throwsFormatException,
      );
    },
  );
  test('Published independent VietQR static fixture matches exactly', () {
    // Public interoperability fixture, NOT the user's payment account.
    // https://github.com/xuannghia/vietnam-qr-pay#vietqr-tĩnh
    const expected =
        '00020101021138530010A0000007270123000697041601092576788590208QRIBFTTA53037045802VN6304AE9F';
    expect(const VietQr(bin: '970416', account: '257678859').build(), expected);
    final parsed = VietQr.parse(expected);
    expect(parsed.bin, '970416');
    expect(parsed.account, '257678859');
  });
  test('Reject invalid bank/account/amount and overlong normalized note', () {
    for (final qr in [
      const VietQr(bin: '12345', account: '123'),
      const VietQr(bin: '970436', account: ''),
      const VietQr(bin: '970436', account: '123 456'),
      const VietQr(bin: '970436', account: '12345678901234567890'),
      const VietQr(bin: '970436', account: '123', amount: '0'),
      const VietQr(bin: '970436', account: '123', amount: '1.5'),
      const VietQr(bin: '970436', account: '123', amount: '001'),
      VietQr(bin: '970436', account: '123', note: 'A' * 51),
    ]) {
      expect(qr.build, throwsFormatException);
    }
  });
}
