import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'payment_config.dart';

class PaymentPanel extends StatefulWidget {
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
  @override
  State<PaymentPanel> createState() => _PaymentPanelState();
}

class _PaymentPanelState extends State<PaymentPanel> {
  ImageStream? stream;
  ImageStreamListener? listener;
  double brandAspect = 2.4;
  PaymentConfig get config => widget.config;
  @override
  void initState() {
    super.initState();
    watchBrand();
  }

  @override
  void didUpdateWidget(PaymentPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.config.brandPath != config.brandPath) watchBrand();
  }

  void watchBrand() {
    if (listener != null) stream?.removeListener(listener!);
    brandAspect = 2.4;
    if (config.brandPath.isEmpty) return;
    stream = FileImage(
      File(config.brandPath),
    ).resolve(ImageConfiguration.empty);
    listener = ImageStreamListener((info, _) {
      if (mounted)
        setState(() => brandAspect = info.image.width / info.image.height);
    }, onError: (Object _, StackTrace? _) {});
    stream!.addListener(listener!);
  }

  @override
  void dispose() {
    if (listener != null) stream?.removeListener(listener!);
    super.dispose();
  }

  Widget image(String path, {bool logo = false}) => ColoredBox(
    color: Colors.white,
    child: Image.file(
      File(path),
      fit: BoxFit.contain,
      filterQuality: logo ? FilterQuality.high : FilterQuality.none,
      errorBuilder: (_, _, _) => const Center(
        child: Text(
          'Mở điện thoại để chọn lại ảnh',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.black, fontSize: 16),
        ),
      ),
    ),
  );
  @override
  Widget build(BuildContext context) => InkWell(
    key: const ValueKey('payment-panel'),
    onTap: widget.onTap,
    child: LayoutBuilder(
      builder: (context, cell) {
        final body = TextStyle(
          color: Colors.black,
          fontSize: math.max(16, 16 * widget.fontScale),
        );
        if (config.displayPath.isEmpty)
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
                      style: TextStyle(
                        fontSize: math.max(22, 22 * widget.fontScale),
                      ),
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
        final details = widget.expanded && cell.maxHeight > 240;
        final footerHeight = details
            ? math.min(cell.maxHeight * .25, 180.0)
            : 0.0;
        final contentHeight = cell.maxHeight - footerHeight;
        // Brand is always directly below QR. Give it the full cell width where
        // its aspect ratio fits, keeping at least 55% of the content for QR.
        final brandHeight = config.brandPath.isEmpty
            ? 0.0
            : math.min(cell.maxWidth / brandAspect, contentHeight * .45);
        final side = math.max(
          0.0,
          math.min(cell.maxWidth, contentHeight - brandHeight),
        );
        return ColoredBox(
          color: Colors.white,
          child: Column(
            children: [
              SizedBox(
                height: contentHeight,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox.square(
                      dimension: side,
                      child: config.usesRendered
                          ? image(config.displayPath)
                          : Padding(
                              padding: EdgeInsets.all(side * 4 / 29),
                              child: image(config.displayPath),
                            ),
                    ),
                    if (brandHeight > 0)
                      SizedBox(
                        key: const ValueKey('payment-brand'),
                        width: cell.maxWidth,
                        height: brandHeight,
                        child: image(config.brandPath, logo: true),
                      ),
                  ],
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
                          if (widget.onTap != null)
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
