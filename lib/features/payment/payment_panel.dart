import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'payment_config.dart';

class PaymentPanel extends StatelessWidget {
  const PaymentPanel({
    super.key,
    required this.config,
    this.expanded = false,
    this.fontScale = 1,
    this.onTap,
  });
  final PaymentConfig config;
  final bool expanded;
  final double fontScale;
  final VoidCallback? onTap;
  Widget image(String path, {BoxFit fit = BoxFit.contain}) => Image.file(
    File(path),
    fit: fit,
    filterQuality: FilterQuality.none,
    errorBuilder: (_, _, _) => const Center(
      child: Text(
        'Mở điện thoại để chọn lại ảnh',
        textAlign: TextAlign.center,
        style: TextStyle(color: Colors.black, fontSize: 16),
      ),
    ),
  );
  @override
  Widget build(BuildContext context) => InkWell(
    key: const ValueKey('payment-panel'),
    onTap: onTap,
    child: LayoutBuilder(
      builder: (context, cell) {
        final body = TextStyle(
          color: Colors.black,
          fontSize: math.max(16, 16 * fontScale),
        );
        if (config.displayPath.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'QR thanh toán',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: math.max(22, 22 * fontScale)),
                    ),
                    const Text(
                      'Chọn ảnh hoặc tạo VietQR trên điện thoại',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 16),
                    ),
                  ],
                ),
              ),
            ),
          );
        }
        // Compact cells dedicate all available space to the QR. Text/logos move
        // below it when expanded. Never crop an imported payment card.
        final details = expanded && cell.maxHeight > 240;
        final footerHeight = details
            ? math.min(cell.maxHeight * .4, 230.0)
            : 0.0;
        final side = math.max(
          0.0,
          math.min(cell.maxWidth, cell.maxHeight - footerHeight),
        );
        return ColoredBox(
          color: Colors.white,
          child: Column(
            children: [
              SizedBox(
                height: cell.maxHeight - footerHeight,
                child: Center(
                  child: SizedBox.square(
                    dimension: side,
                    child: config.usesRendered
                        ? image(config.displayPath)
                        : Padding(
                            padding: EdgeInsets.all(side * 4 / 29),
                            child: image(config.displayPath),
                          ),
                  ),
                ),
              ),
              if (details)
                SizedBox(
                  height: footerHeight,
                  child: SingleChildScrollView(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Column(
                        children: [
                          if (config.brandPath.isNotEmpty)
                            SizedBox(
                              height: math.min(60, footerHeight / 3),
                              child: image(config.brandPath),
                            ),
                          if (config.bankName.isNotEmpty)
                            Text(
                              config.bankName,
                              textAlign: TextAlign.center,
                              style: body,
                            ),
                          if (!config.hideAccount && config.account.isNotEmpty)
                            Text(
                              config.account,
                              textAlign: TextAlign.center,
                              style: body.copyWith(fontWeight: FontWeight.bold),
                            ),
                          if (config.holder.isNotEmpty)
                            Text(
                              config.holder,
                              textAlign: TextAlign.center,
                              style: body,
                            ),
                          if (onTap != null)
                            Text(
                              'Chạm để thu gọn · Tự đóng sau 10 giây',
                              textAlign: TextAlign.center,
                              style: body,
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    ),
  );
}
