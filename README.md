# Taxi Xanh · Android Auto Dashboard

**Giai đoạn 3 — v0.3.0: QR thanh toán ngoại tuyến.** Thanh đã nghiệm thu GĐ2 hoạt động ổn định trên VinFast VF e34 / Redmi Note 12 Pro Android 13, Android Auto có dây và không dây.

## Cài và thử trên điện thoại

1. Cài đè [APK arm64 nightly](https://github.com/ThanhTaxiXanh/TaxiDriveAADashboad/releases/download/nightly/app-arm64-v8a-release.apk) khi Releases ghi **Giai đoạn 3**. Giữ nguyên khóa ký.
2. Mở **QR thanh toán**. Chọn **Ảnh có sẵn** để lấy ảnh bằng bộ chọn ảnh hệ thống, hoặc **Tạo VietQR** để tìm ngân hàng, nhập tài khoản, tên hiển thị, số tiền/nội dung tùy chọn. Nội dung tự bỏ dấu; số tiền là số nguyên VND, để trống để khách tự nhập.
3. Nếu đọc được VietQR tài khoản NAPAS và CRC đúng, có thể bật **Dựng lại QR sắc nét**. Chuỗi gốc được giữ nguyên khi dựng lại. Nếu không đọc được, giữ ảnh gốc để thử quét.
4. Chọn logo giữa (tự cắt tròn, viền trắng, tổng 17% chiều rộng mã) và logo thương hiệu phía dưới. Logo giữa chỉ áp dụng với QR tạo/dựng lại. **Lưu QR và cập nhật lên xe** kiểm tra giải mã lại ảnh QR trước khi lưu. Nếu không đọc được, bỏ logo giữa hoặc rút ngắn nội dung rồi thử lại.
5. Quét bằng **ứng dụng ngân hàng thật** và đối chiếu ngân hàng, tài khoản, tên người nhận, số tiền/nội dung. Tên nhập trong app chỉ để hiển thị, không phải xác minh người nhận. Không cần thực hiện chuyển tiền để nghiệm thu.

## Thử trên xe khi đang đỗ

- Chạm hàng QR để mở toàn cột phải trong **10 giây**; ô bản đồ bên trái giữ nguyên. Chạm lần nữa để đóng sớm. Hàng nhỏ ưu tiên toàn bộ diện tích cho mã; khi phóng to có thông tin và logo bên dưới.
- Thử cả ảnh có sẵn và mã tự tạo, có/không logo. Nếu mã quá nhỏ, mở rộng cột phải trong **Chỉnh bố cục**. Kiểm tra khách ngồi sau quét được.
- Bật **Ẩn số tài khoản dạng chữ** nếu muốn. QR luôn chứa tài khoản để nhận tiền; chữ có sẵn trong ảnh gốc vẫn hiện.
- Tắt mạng, kết nối lại Android Auto và mở lại app: QR phải còn. Thử Lịch, Home và bố cục cũ.
- **Xóa QR và logo đã lưu** có xác nhận, chỉ xóa dữ liệu thanh toán.

Cổng GĐ3: CI xanh, CRC và dựng ảnh→giải mã đạt; Thanh quét bằng app ngân hàng và xác nhận đúng người nhận/tài khoản. Chờ nghiệm thu này trước khi bắt đầu bản đồ GĐ4. Bản đồ dẫn đường và media còn giữ chỗ.

## Dữ liệu và kiểm tra

76 ngân hàng trong bản chụp công khai từ API VietQR ngày 28/10/2026; mục có hỗ trợ chuyển khoản được dùng trong bộ chọn. File assets/banks_vn.json đóng gói tên, mã, BIN và URL logo nguồn. Ứng dụng không tải logo ngân hàng hoặc gọi API lúc chạy; hai logo hiển thị do người dùng chọn. Workflow **Public bank snapshot** tải/kiểm tra danh sách mới để duyệt và commit trước khi phát hành lần sau.

QR, tài khoản và logo chỉ trong SharedPreferences/bộ nhớ riêng, không vào repo, nhật ký chẩn đoán hoặc tệp JSON sự kiện. Không dùng API tạo QR/tra cứu tài khoản, không cần khóa hay thẻ. Android backup đã tắt. Hai engine đọc chung cấu hình qua native bridge, chỉ broadcast revision. Ảnh được chép thành PNG riêng, tên tệp mới mỗi lần để tránh cache cũ. Gỡ ứng dụng/xóa dữ liệu sẽ mất QR; giữ ảnh gốc bên ngoài để chọn lại.

CI kiểm tra CRC 29B1, cấu trúc TLV, từ chối payload sai, tạo ảnh QR mức H và giải mã bằng ZXing khớp hoàn toàn với/không logo, thời gian mở rộng và hồi quy lịch/bố cục. PNG trong **ui-previews** là ảnh duyệt đầu tiên, chưa phải baseline được người dùng duyệt. Thử quét vật lý cần thực hiện trên xe thật.

[Chi tiết QR và nguồn](docs/QR_NOTES.md) · [Lịch/sự kiện GĐ2](docs/PHASE_2.md) · [Bố cục GĐ1](docs/PHASE_1.md) · [Đặc tả](docs/SPECIFICATION.md) · [Nghiên cứu Fermata](docs/FERMATA_REVIEW.md).

## Khóa ký và cài Android Auto

Giữ nguyên ciphertext android/signing/personal.jks.gpg và Secret ANDROID_SIGNING_PASSWORD; không khởi tạo lại khóa. Android Auto: chế độ nhà phát triển, Nguồn không xác định và Taxi Xanh trong Tùy chỉnh trình khởi chạy như GĐ0.

Mã tự viết, không nhúng mã GPL Fermata. Noto Sans theo SIL OFL 1.1. qr_flutter và zxing2 theo BSD-3-Clause; image theo MIT; image_picker theo Apache-2.0, thông báo giấy phép được Flutter đóng gói.
