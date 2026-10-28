import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'payment_config.dart';
import 'payment_panel.dart';
import 'payment_store.dart';
import 'qr_codec.dart';
import 'vietqr.dart';

class PaymentScreen extends StatefulWidget {
  const PaymentScreen({super.key, required this.store});
  final PaymentStore store;
  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  final account = TextEditingController(),
      holder = TextEditingController(),
      amount = TextEditingController(),
      note = TextEditingController();
  List<Bank> banks = [];
  String mode = 'image',
      bin = '',
      bankName = '',
      original = '',
      center = '',
      brand = '',
      importedPayload = '';
  bool rebuild = false, hideAccount = false, busy = false;
  String? message;
  PaymentConfig? preview;
  PaymentStore get store => widget.store;
  @override
  void initState() {
    super.initState();
    final c = store.config;
    mode = c.mode;
    bin = c.bin;
    bankName = c.bankName;
    account.text = c.account;
    holder.text = c.holder;
    amount.text = c.amount;
    note.text = c.note;
    original = c.originalPath;
    center = c.centerPath;
    brand = c.brandPath;
    importedPayload = mode == 'image' ? c.payload : '';
    rebuild = c.rebuild;
    hideAccount = c.hideAccount;
    preview = c.displayPath.isEmpty ? null : c;
    load();
  }

  Future<void> load() async {
    try {
      final list = await Bank.load();
      await store.recovery;
      if (!mounted) return;
      setState(() => banks = list);
      if (store.recovered != null) {
        final file = store.recovered!;
        final role = store.recoveredRole ?? 'original';
        store.recovered = null;
        await action(() => acceptImage(file.path, role));
      }
    } catch (_) {
      if (mounted)
        setState(
          () => message =
              'Không đọc được danh sách ngân hàng hoặc ảnh khôi phục. Hãy thử mở lại.',
        );
    }
  }

  @override
  void dispose() {
    account.dispose();
    holder.dispose();
    amount.dispose();
    note.dispose();
    super.dispose();
  }

  Future<void> action(Future<void> Function() work) async {
    if (busy) return;
    setState(() {
      busy = true;
      message = null;
    });
    try {
      await work();
    } on FormatException catch (e) {
      if (mounted) setState(() => message = e.message);
    } catch (_) {
      if (mounted)
        setState(
          () => message =
              'Không thực hiện được. Kiểm tra ảnh và thử lại; QR đã lưu vẫn được giữ.',
        );
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> pick(String role) => action(() async {
    await store.setPickRole(role);
    final file = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      requestFullMetadata: false,
    );
    if (file != null) await acceptImage(file.path, role);
    await store.setPickRole(null);
  });
  Future<void> acceptImage(String path, String role) async {
    final bytes = await normalizePickedImage(path, logo: role != 'original');
    final saved = await store.writeImage(bytes);
    String? decoded;
    if (role == 'original') decoded = await compute(decodeQrBytes, bytes);
    if (!mounted) return;
    setState(() {
      preview = null;
      if (role == 'center')
        center = saved;
      else if (role == 'brand')
        brand = saved;
      else {
        original = saved;
        importedPayload = '';
        rebuild = false;
        // Never retain bank/account labels belonging to the previous image.
        bin = '';
        bankName = '';
        account.clear();
        amount.clear();
        note.clear();
        holder.clear();
        try {
          final parsed = VietQr.parse(decoded ?? '');
          importedPayload = decoded!;
          bin = parsed.bin;
          account.text = parsed.account;
          amount.text = parsed.amount;
          note.text = parsed.note;
          bankName =
              banks.where((b) => b.bin == bin).firstOrNull?.shortName ??
              'BIN $bin';
          message =
              'Đã đọc VietQR và CRC hợp lệ. Có thể bật Dựng lại QR sắc nét.';
        } catch (_) {
          message =
              'Giữ ảnh gốc. Chưa xác minh được VietQR/CRC; hãy quét thử bằng ứng dụng ngân hàng.';
        }
      }
    });
  }

  Future<void> selectBank() async {
    final selected = await showModalBottomSheet<Bank>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _BankPicker(banks: banks),
    );
    if (selected != null && mounted)
      setState(() {
        bin = selected.bin;
        bankName = selected.shortName;
        preview = null;
      });
  }

  Future<void> save() => action(() async {
    if (holder.text.trim().length > 100)
      throw const FormatException('Tên chủ tài khoản tối đa 100 ký tự');
    var payload = '';
    var rendered = '';
    if (mode == 'generated') {
      if (!banks.any((b) => b.bin == bin))
        throw const FormatException('Chọn ngân hàng trong danh sách');
      payload = VietQr(
        bin: bin,
        account: account.text.trim(),
        amount: amount.text.trim(),
        note: note.text,
      ).build();
      VietQr.parse(payload);
    } else {
      if (original.isEmpty) throw const FormatException('Chọn ảnh QR trước');
      if (rebuild) {
        VietQr.parse(importedPayload);
        payload = importedPayload;
      } else {
        payload = importedPayload;
      }
    }
    if (mode == 'generated' || rebuild) {
      final bytes = await renderPaymentQr(
        payload,
        logoBytes: center.isEmpty ? null : await File(center).readAsBytes(),
      );
      rendered = await store.writeImage(bytes);
    }
    final imported = mode == 'image' && payload.isNotEmpty
        ? VietQr.parse(payload)
        : null;
    final savedBin = mode == 'image' ? imported?.bin ?? '' : bin;
    final savedBank = mode == 'image'
        ? (savedBin.isEmpty
              ? ''
              : banks.where((b) => b.bin == savedBin).firstOrNull?.shortName ??
                    'BIN $savedBin')
        : bankName;
    final c = PaymentConfig(
      mode: mode,
      bin: savedBin,
      bankName: savedBank,
      account: mode == 'image' ? imported?.account ?? '' : account.text.trim(),
      holder: holder.text.trim(),
      amount: mode == 'image' ? imported?.amount ?? '' : amount.text.trim(),
      note: mode == 'generated'
          ? VietQr.asciiNote(note.text)
          : imported?.note ?? '',
      payload: payload,
      originalPath: original,
      centerPath: center,
      brandPath: brand,
      renderedPath: rendered,
      rebuild: mode == 'image' && rebuild,
      hideAccount: hideAccount,
    );
    await store.save(c);
    if (mounted)
      setState(() {
        preview = c;
        message =
            'Đã lưu trên máy và cập nhật lên xe. Hãy quét kiểm tra bằng app ngân hàng.';
      });
  });
  Future<void> clear() async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Xóa QR và logo đã lưu?'),
        content: const Text('Bạn có thể chọn lại ảnh hoặc tạo mã mới sau đó.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Hủy'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Xóa'),
          ),
        ],
      ),
    );
    if (yes == true && mounted)
      await action(() async {
        await store.clear();
        if (mounted) Navigator.pop(context);
      });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('QR thanh toán')),
    body: AbsorbPointer(
      absorbing: busy,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Cấu hình trên điện thoại. Sau khi lưu, quét thử để kiểm tra đúng ngân hàng, số tài khoản, tên người nhận và số tiền.',
          ),
          const SizedBox(height: 12),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'image', label: Text('Ảnh có sẵn')),
              ButtonSegment(value: 'generated', label: Text('Tạo VietQR')),
            ],
            selected: {mode},
            onSelectionChanged: (value) => setState(() {
              mode = value.first;
              preview = null;
              rebuild = false;
            }),
          ),
          const SizedBox(height: 12),
          if (mode == 'image') ...[
            FilledButton.icon(
              onPressed: () => pick('original'),
              icon: const Icon(Icons.photo_library_outlined),
              label: Text(
                original.isEmpty ? 'Chọn ảnh QR' : 'Chọn ảnh QR khác',
              ),
            ),
            if (original.isNotEmpty)
              SizedBox(
                height: 220,
                child: Image.file(
                  File(original),
                  fit: BoxFit.contain,
                  errorBuilder: (_, _, _) =>
                      const Text('Ảnh không còn; hãy chọn lại'),
                ),
              ),
            if (importedPayload.isNotEmpty)
              SwitchListTile(
                title: const Text('Dựng lại QR sắc nét'),
                subtitle: const Text(
                  'Giữ nguyên chuỗi VietQR đã giải mã và kiểm tra CRC',
                ),
                value: rebuild,
                onChanged: (v) => setState(() {
                  rebuild = v;
                  preview = null;
                }),
              ),
          ] else ...[
            ListTile(
              title: Text(bankName.isEmpty ? 'Chọn ngân hàng' : bankName),
              subtitle: Text(bin.isEmpty ? 'Tìm tên, mã hoặc BIN' : 'BIN $bin'),
              trailing: const Icon(Icons.search),
              onTap: banks.isEmpty ? null : selectBank,
            ),
            TextField(
              controller: account,
              decoration: const InputDecoration(labelText: 'Số tài khoản'),
              maxLength: 19,
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp('[A-Za-z0-9]')),
              ],
            ),
            TextField(
              controller: amount,
              decoration: const InputDecoration(
                labelText: 'Số tiền VND (có thể để trống)',
              ),
              maxLength: 12,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            ),
            TextField(
              controller: note,
              decoration: const InputDecoration(
                labelText: 'Nội dung (có thể để trống)',
                helperText: 'Tự bỏ dấu; tối đa 50 ký tự sau chuyển đổi',
              ),
              maxLength: 100,
            ),
          ],
          TextField(
            controller: holder,
            decoration: const InputDecoration(
              labelText: 'Tên chủ tài khoản (chỉ hiển thị)',
              helperText: 'Không tra cứu hoặc xác minh tên qua mạng',
            ),
            maxLength: 100,
          ),
          SwitchListTile(
            title: const Text('Ẩn số tài khoản dạng chữ'),
            subtitle: const Text(
              'Mã QR vẫn chứa số tài khoản để nhận tiền. Ảnh gốc có chữ thì chữ vẫn hiện.',
            ),
            value: hideAccount,
            onChanged: (v) => setState(() => hideAccount = v),
          ),
          if (mode == 'generated' || rebuild) ...[
            _logoRow('Logo tròn giữa QR', 'center', center),
            const Text(
              'Logo giữa có viền trắng và chiếm tối đa 17% chiều rộng mã. Chỉ lưu khi ảnh QR giải mã lại thành công.',
            ),
          ],
          _logoRow('Logo thương hiệu dưới QR', 'brand', brand),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: save,
            icon: const Icon(Icons.save),
            label: const Text('Lưu QR và cập nhật lên xe'),
          ),
          if (busy) const LinearProgressIndicator(),
          if (message != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(message!, style: const TextStyle(fontSize: 16)),
            ),
          if (preview != null)
            SizedBox(
              height: 520,
              child: PaymentPanel(config: preview!, expanded: true),
            ),
          OutlinedButton(
            onPressed: clear,
            child: const Text('Xóa QR và logo đã lưu'),
          ),
          const Text(
            'QR, tài khoản và logo được lưu riêng trên máy, dùng được khi tắt mạng. Chạm QR trên xe để phóng to cột phải 10 giây.',
          ),
        ],
      ),
    ),
  );
  Widget _logoRow(String label, String role, String path) => ListTile(
    leading: path.isEmpty
        ? const Icon(Icons.image_outlined)
        : SizedBox(
            width: 48,
            height: 48,
            child: Image.file(
              File(path),
              errorBuilder: (_, _, _) =>
                  const Icon(Icons.broken_image_outlined),
            ),
          ),
    title: Text(label),
    onTap: () => pick(role),
    trailing: path.isEmpty
        ? const Icon(Icons.add_photo_alternate_outlined)
        : IconButton(
            tooltip: 'Bỏ logo',
            icon: const Icon(Icons.close),
            onPressed: () => setState(() {
              if (role == 'center')
                center = '';
              else
                brand = '';
              preview = null;
            }),
          ),
  );
}

class _BankPicker extends StatefulWidget {
  const _BankPicker({required this.banks});
  final List<Bank> banks;
  @override
  State<_BankPicker> createState() => _BankPickerState();
}

class _BankPickerState extends State<_BankPicker> {
  String query = '';
  @override
  Widget build(BuildContext context) {
    final q = VietQr.asciiNote(query);
    final matches = widget.banks.where(
      (b) => VietQr.asciiNote(
        '${b.name} ${b.shortName} ${b.code} ${b.bin}',
      ).contains(q),
    );
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: SizedBox(
          height: MediaQuery.sizeOf(context).height * .75,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: TextField(
                  autofocus: true,
                  decoration: const InputDecoration(
                    labelText: 'Tìm ngân hàng / BIN',
                    prefixIcon: Icon(Icons.search),
                  ),
                  onChanged: (v) => setState(() => query = v),
                ),
              ),
              Expanded(
                child: ListView(
                  children: [
                    for (final b in matches)
                      ListTile(
                        title: Text(b.shortName),
                        subtitle: Text('${b.name} · ${b.bin}'),
                        onTap: () => Navigator.pop(context, b),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
