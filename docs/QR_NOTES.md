# Giai đoạn 3 — ghi chú QR

## Nguồn và phạm vi

- [VietQR API Bank](https://www.vietqr.io/api-bank): GET https://api.vietqr.io/v2/banks, chỉ metadata công khai. tools/update_banks.py chạy CI, kiểm tra code 00, BIN 6 chữ số duy nhất, đủ số mục rồi xuất artifact/nhật ký dữ liệu công khai. Lưu bản chụp vào repo; không gọi khi chạy app. Thông báo API tháng 10/2026 không ảnh hưởng bộ tạo TLV nội bộ.
- [NAPAS VietQR](https://napas.com.vn/dich-vu-chuyen-nhan-tien-nhanh-napas-247-bang-ma-qr): phạm vi mã chuyển khoản tài khoản. Không tuyên bố chứng nhận NAPAS hoặc xác minh chủ tài khoản.
- [Mô tả TLV/CRC trong đặc tả người dùng](https://viblo.asia/p/tu-viet-bo-tao-va-doc-ma-vietqr-bang-javascript-tlv-crc16-va-6-loi-hay-gap-3RL1BowpVao). Tự viết bộ tạo/parser, không sao chép mã từ bài.
- [CRC catalogue](https://reveng.sourceforge.io/crc-catalogue/16.htm#crc.cat.crc-16-ibm-3740): CCITT-FALSE/IBM-3740 poly 1021, init FFFF, không reflect, xorout 0, check 29B1.
- [DENSO WAVE quiet zone](https://www.qrcode.com/en/howto/code.html): tối thiểu 4 module trắng mỗi cạnh.
- [qr_flutter 4.1.0](https://pub.dev/packages/qr_flutter), [zxing2 0.2.4](https://pub.dev/packages/zxing2), [image_picker 1.2.4](https://pub.dev/packages/image_picker), [image](https://pub.dev/packages/image): đọc tài liệu API trước khi tích hợp. Android 13 dùng Photo Picker, không xin quyền toàn bộ thư viện ảnh. retrieveLostData chạy trên engine điện thoại khi khởi động; ảnh khôi phục được đưa lại vào trang QR với vai trò đã lưu.

## Cấu trúc và giới hạn

00=01; 01=11 khi không có tiền, 12 khi có tiền; 38 gồm GUID A000000727, nested BIN/tài khoản và service QRIBFTTA; 53=704; 54 tùy chọn; 58=VN; 62/08 nội dung ASCII; CRC 63 cuối cùng. CRC tính cả 6304. Parser từ chối TLV trùng/cắt/sai CRC và profile khác. Khi dựng lại ảnh, giữ nguyên toàn bộ payload gốc (kể cả trường mở rộng), không tạo lại từ vài trường đã phân tích.

Chỉ hỗ trợ tài khoản 1–19 chữ/số ASCII, BIN 6 số; tiền nguyên 1–999999999999 VND; nội dung sau bỏ dấu tối đa 50 ký tự. Giao diện không làm tra cứu người nhận. Các profile như merchant QR, QR ví, hoặc payload ngoài giới hạn vẫn dùng ảnh gốc nhưng không được đánh dấu đã kiểm tra VietQR.

Bộ vẽ dùng qr_flutter mức H, đen trên trắng, lề đúng 4 module. Logo tròn gồm cả viền trắng 17% chiều rộng mã; ảnh vuông 1024 được kiểm tra bằng zxing2 trước khi lưu. Nếu kiểm tra không đạt, từ chối thay cấu hình đã lưu. Không đảm bảo mọi camera/app ngân hàng đọc được ở mọi khoảng cách — cần nghiệm thu vật lý.

Ảnh gốc được giữ nguyên nội dung, chuyển PNG và thu nhỏ cạnh dài tối đa 2048; logo tối đa 768; ảnh chọn tối đa 20 MB, PNG lưu tối đa 8 MB. Toàn ảnh nằm vừa khung trên nền trắng, thêm viền ngoài bằng 4/29 cạnh khung. Với ảnh thẻ/QR cắt sát hoặc lẫn nền bên trong, không thể chứng nhận quiet zone của vùng mã khi chưa giải mã được; cần ảnh nguồn rõ hoặc dùng dựng lại. Không chèn logo giữa lên ảnh gốc.

SQLite lịch không đổi. PaymentStorage native giữ một cấu hình và ảnh riêng dùng chung cho hai engine. Thao tác ghi chỉ trên điện thoại. Config commit thành công rồi mới dọn ảnh cũ; lỗi không thay config cũ. FileProvider chỉ chia sẻ nhật ký/sự kiện, không có đường dẫn payment. Không log payload/ảnh/tài khoản; EventChannel chỉ có paymentRevision.

## Nghiệm thu

Tự động: CRC chuẩn, TLV/round-trip/static/dynamic, số 0 đầu tài khoản, Unicode bỏ dấu, dữ liệu sai, dựng PNG thật rồi ZXing giải mã với/không logo ở payload thường và tối đa; chạm mở cột phải 10 giây, chạm đóng, tắt hàng khi đang mở.

Thủ công trên VF e34: quét app ngân hàng cả ảnh và mã tự tạo, đối chiếu người nhận/tài khoản/tiền/nội dung; quét có logo; thử tắt mạng/mở lại/kết nối lại; kiểm tra lịch/Home. GĐ2 đã được Thanh xác nhận ổn định. GĐ3 chờ Thanh xác nhận trước GĐ4.
