# Taxi Xanh · Android Auto Dashboard

**Giai đoạn 2 — v0.2.0: lịch Âm/Dương và sự kiện ngoại tuyến.** Thanh đã xác nhận GĐ1 chỉnh bố cục hoạt động mượt trên VF e34 / Redmi Note 12 Pro, Android 13.

## Cài và thử trên điện thoại

1. Tải [APK arm64 từ nightly](https://github.com/ThanhTaxiXanh/TaxiDriveAADashboad/releases/download/nightly/app-arm64-v8a-release.apk) và cài đè sau khi Releases ghi **Giai đoạn 2**. Giữ nguyên khóa ký hiện tại.
2. Mở **Lịch và sự kiện**. Dùng **Đối chiếu một ngày** để chọn năm ngày bất kỳ trong 2000–2050 rồi so ngày âm với lịch anh thường dùng. Kiểm tra tháng nhuận và Can Chi.
3. **Thêm sự kiện**: đặt tên, lịch âm/dương, ngày/tháng, lặp hằng năm hoặc năm cụ thể, màu và ghi chú. Nếu là âm lịch, có lựa chọn tính cả tháng nhuận. Chạm sự kiện riêng để sửa; nút thùng rác để xóa. Sự kiện khởi tạo chỉ có công tắc ẩn/hiện.
4. Bật **Mùng Một và ngày Rằm hằng tháng** nếu cần. Ngày 30 âm không tồn tại dùng 29; danh sách có nhãn “29 thay 30 âm”. Sự kiện 29/2 dương chỉ xuất hiện trong năm có ngày này.
5. **Xuất JSON** mở hộp chia sẻ để lưu bản sao. **Nhập JSON** mở bộ chọn tệp và cho xem số mục trước khi nhập gộp. Tệp sai hoặc quá lớn được từ chối, không xóa dữ liệu cũ. Trùng ID cập nhật, ID khác vẫn giữ. Nội dung sự kiện riêng có trong tệp xuất, không có trong nhật ký chẩn đoán.

## Thử trên xe khi đang đỗ

- Hàng lịch hiển thị ngày dương, âm (có nhãn nhuận), Can Chi và ba sự kiện gần nhất có số ngày còn lại. Nếu hàng thấp, vuốt dọc để đọc thêm hoặc bấm icon mở rộng.
- Chạm hàng/tiêu đề để luân phiên **Hôm nay → Lưới tháng → Sự kiện gần nhất**. Ở hàng quá thấp có nút mở rộng lịch; khi mở, lịch chiếm toàn cột phải và vẫn giữ ô bản đồ bên trái. Nút **Thu gọn lịch** khôi phục ba hàng.
- Lưới tháng có ngày dương và ngày âm ở từng ô; nút trước/sau đổi tháng, chạm ô xem đầy đủ ngày âm ở dòng dưới. Cỡ ô có thể cuộn nếu không đủ chỗ, không thu chữ xuống dưới 16 dp.
- Tắt mạng, thêm/sửa/ẩn một sự kiện trên điện thoại, xem xe cập nhật. Kết nối lại và mở lại ứng dụng để kiểm tra vẫn còn. Trên xe chỉ đọc, không nhập tên/ghi chú.
- Kiểm tra bố cục và Home vẫn hoạt động. Nếu lỗi, dùng **Chia sẻ nhật ký** trên điện thoại.

Cổng GĐ2 cần Thanh đối chiếu năm ngày và xác nhận lịch/sự kiện trên xe. Sau đó mới sang QR thanh toán GĐ3. Bản đồ dẫn đường, QR và media vẫn giữ chỗ.

## Kiểm tra và kiến trúc

CI kiểm tra 18.628 ngày (2000–2050) qua vòng dương→âm→dương, bốn mốc Tết trong đặc tả, năm nhuận 2023/2025, Can Chi, ngày không tồn tại, lặp sự kiện, nhập/xuất JSON và bố cục. Ảnh PNG đầu tiên trong artifact **ui-previews** dùng Noto Sans và ngày cố định 28/10/2026 để dễ so sánh; chưa phải baseline pixel được Thanh duyệt.

Dữ liệu lưu SQLite chung cho hai engine qua cầu nối native thay cho drift; quy tắc lịch/sự kiện và UI ở Dart. EventChannel chỉ báo revision, engine đọc lại khi dữ liệu đổi. Không log tên, ghi chú hay nội dung JSON của sự kiện. FileProvider chỉ chia sẻ tệp xuất do anh yêu cầu; không tự gửi lên máy chủ. Bộ chọn tệp không cần quyền toàn bộ bộ nhớ.

[Chi tiết lịch, nguồn và khác biệt với Kotlin](docs/CALENDAR_NOTES.md) · [GĐ1 và cách chỉnh bố cục](docs/PHASE_1.md) · [Đặc tả](docs/SPECIFICATION.md) · [Nghiên cứu Fermata](docs/FERMATA_REVIEW.md).

## Khóa ký và cài Android Auto

Giữ nguyên ciphertext `android/signing/personal.jks.gpg` và Secret `ANDROID_SIGNING_PASSWORD`; sao lưu cả hai. Không khởi tạo hoặc thay khóa để cập nhật bản này. Android Auto: bật chế độ nhà phát triển, bật Nguồn không xác định và Taxi Xanh trong Tùy chỉnh trình khởi chạy như GĐ0.

Mã tự viết, không nhúng mã GPL Fermata. Noto Sans theo SIL OFL 1.1, kèm giấy phép ở assets/fonts/OFL.txt.
