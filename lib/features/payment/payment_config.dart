import 'dart:convert';

import 'package:flutter/services.dart';

class Bank {
  const Bank(this.name, this.code, this.bin, this.shortName);
  final String name, code, bin, shortName;
  static Future<List<Bank>> load() async {
    final json =
        jsonDecode(await rootBundle.loadString('assets/banks_vn.json')) as Map;
    return [
      for (final b in json['banks'])
        if (b['transferSupported'] == 1)
          Bank(b['name'], b['code'], b['bin'], b['shortName']),
    ]..sort((a, b) => a.shortName.compareTo(b.shortName));
  }
}

class PaymentConfig {
  const PaymentConfig({
    this.mode = 'image',
    this.bin = '',
    this.bankName = '',
    this.account = '',
    this.holder = '',
    this.amount = '',
    this.note = '',
    this.payload = '',
    this.originalPath = '',
    this.centerPath = '',
    this.brandPath = '',
    this.renderedPath = '',
    this.rebuild = false,
    this.hideAccount = false,
  });
  final String mode, bin, bankName, account, holder, amount, note, payload;
  final String originalPath, centerPath, brandPath, renderedPath;
  final bool rebuild, hideAccount;
  bool get usesRendered => mode == 'generated' || rebuild;
  String get displayPath => usesRendered ? renderedPath : originalPath;
  Map<String, dynamic> toJson() => {
    'mode': mode,
    'bin': bin,
    'bankName': bankName,
    'account': account,
    'holder': holder,
    'amount': amount,
    'note': note,
    'payload': payload,
    'originalPath': originalPath,
    'centerPath': centerPath,
    'brandPath': brandPath,
    'renderedPath': renderedPath,
    'rebuild': rebuild,
    'hideAccount': hideAccount,
  };
  factory PaymentConfig.fromJson(Map<String, dynamic> j) => PaymentConfig(
    mode: j['mode'] as String? ?? 'image',
    bin: j['bin'] as String? ?? '',
    bankName: j['bankName'] as String? ?? '',
    account: j['account'] as String? ?? '',
    holder: j['holder'] as String? ?? '',
    amount: j['amount'] as String? ?? '',
    note: j['note'] as String? ?? '',
    payload: j['payload'] as String? ?? '',
    originalPath: j['originalPath'] as String? ?? '',
    centerPath: j['centerPath'] as String? ?? '',
    brandPath: j['brandPath'] as String? ?? '',
    renderedPath: j['renderedPath'] as String? ?? '',
    rebuild: j['rebuild'] == true,
    hideAccount: j['hideAccount'] == true,
  );
}
