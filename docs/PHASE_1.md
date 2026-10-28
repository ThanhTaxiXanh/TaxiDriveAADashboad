# Taxi Xanh · Android Auto Dashboard

**Giai đoạn 1 — khung bố cục.** VF e34 (màn hình nguyên bản), Redmi Note 12 Pro / Android 13, Android Auto có dây và không dây.

Thanh đã xác nhận GĐ0: chữ Việt rõ, chạm đúng, Home hoạt động. Nhật ký ghi nhận khung đầu ~259 ms, 16 chạm, FPS Flutter ổn định ~31, Car API 8. CI xanh, khóa ký ổn định và APK nightly đã có. GĐ1 tiếp tục giữ cầu nối Surface đã chạy.

## Tải và thử khi xe đang đỗ

1. Vào [Releases/nightly](https://github.com/ThanhTaxiXanh/TaxiDriveAADashboad/releases/tag/nightly), tải `app-arm64-v8a-release.apk` cho Redmi Note 12 Pro và cài đè. Chờ ghi chú phát hành ghi **Giai đoạn 1** trước khi thử bố cục mới.
2. Mở Taxi Xanh trên điện thoại → **Chỉnh bố cục**. Đổi chiều rộng bản đồ, trọng số hàng, bật/tắt hàng, sáng/tối và cỡ chữ. Quan sát thay đổi ngay trên xe.
3. Trên xe bấm icon bánh răng, dùng nút +/− để chỉnh; vuốt dọc để cuộn danh sách. Không cần bàn phím. Bấm **Về bảng điều khiển** để xem kết quả.
4. Thử tắt một hàng (các hàng còn lại chia đều), tắt cả ba (bản đồ mở hết chiều ngang), rồi **Đặt lại mặc định**. Ngắt/kết nối Android Auto và khởi động lại ứng dụng: cấu hình phải được giữ.
5. Thử bốn icon gốc Android Auto: **Home** thoát về Android Auto; **YouTube** mở chỗ giữ; **Cài đặt** mở bố cục; **+** mở danh sách module đang trống.
6. Gửi kết quả: bố cục có vừa vùng nhìn thấy, có tràn/cắt chữ, đồng bộ hai chiều và lưu sau khởi động lại được không. Dùng **Chia sẻ nhật ký** nếu lỗi.

Lịch, QR, bản đồ dẫn đường và media hiện là ô giữ chỗ, có ghi rõ giai đoạn dự kiến. Không dùng hình đường minh họa để dẫn đường. YouTube chưa phát nội dung. Dữ liệu QR trong ảnh đã gửi chưa được đưa lên repo hoặc vào APK.

## Cấu hình và kiểm tra

`LayoutConfig` là cấu hình chung: cột trái 40–75% (mặc định 58%), trọng số `[1, 1.2, .8]`, mỗi hàng bật ít nhất 15%; khi tắt hàng, các hàng còn lại chia đều. Cỡ chữ 0.8–1.6, chế độ tự động/sáng/tối. Trên xe chế độ tự động theo sáng/tối của Android Auto. Cấu hình lưu trong SharedPreferences native; MethodChannel ghi, EventChannel phát lại cho hai engine trong cùng tiến trình. Cập nhật đồng thời sử dụng giá trị được native tiếp nhận sau cùng.

CI kiểm tra unit test, widget test (1280×720, 1920×720, 803×843 và 800×480), build APK debug và release ký. Artifact **ui-previews** có chín PNG với Noto Sans; đây là ảnh golden tạo lần đầu để duyệt, chưa phải baseline được Thanh duyệt để so sánh hồi quy pixel. Bài kiểm tra bố cục vẫn kiểm tra cấu trúc và lỗi tràn độc lập.

VF e34 đã báo Surface 934×843, che 131 px bên phải: widget áp dụng visibleArea và kiểm tra vùng nội dung xấp xỉ 803×843. Ở trạng thái tĩnh FPS có thể thấp vì ứng dụng chỉ vẽ khi cần; số này không dùng thay cho phép thử hoạt ảnh 30 Hz của GĐ0. Cầu nối vẫn báo FPS Flutter, không đo trực tiếp khung quét màn xe.

## Cài Android Auto và chẩn đoán

Android Auto → cài đặt → chạm **Phiên bản** 10 lần; menu nhà phát triển → bật **Nguồn không xác định**. Trong **Tùy chỉnh trình khởi chạy**, bật Taxi Xanh rồi kết nối lại. Host có thể giới hạn app cài ngoài tùy phiên bản.

Chẩn đoán trên điện thoại hiển thị Surface, vùng nhìn thấy, số chạm, FPS và lỗi; nút chia sẻ chỉ mở hộp chọn ứng dụng nhận. Nhật ký chỉ lưu trường kỹ thuật/cấu hình bố cục, không tài khoản ngân hàng hay GPS.

## Khóa ký

Khóa đã khởi tạo dưới dạng ciphertext `android/signing/personal.jks.gpg`. **Giữ nguyên Secret `ANDROID_SIGNING_PASSWORD` và sao lưu cả mật khẩu lẫn tệp mã hóa. Không chạy khởi tạo lại để thay khóa.** CI giải mã trên runner, chỉ upload APK. Không commit hoặc gửi khóa thô vào chat/log. Mất khóa hoặc mật khẩu sẽ không cập nhật đè được.

Kho mới hoàn toàn có thể làm theo hướng dẫn khởi tạo trong [tài liệu GĐ0](docs/PHASE_0.md). Khóa hiện tại không nằm trong workspace và không bị thay trong GĐ1.

## Phạm vi tiếp theo

Cổng GĐ1 cần Thanh xác nhận trên xe: đổi tỷ lệ có hiệu lực ngay, cấu hình giữ sau kết nối lại, chữ vừa và Home vẫn hoạt động. Sau đó mới triển khai GĐ2 lịch Âm/Dương và sự kiện.

[Đặc tả](docs/SPECIFICATION.md) · [Nghiên cứu Fermata](docs/FERMATA_REVIEW.md). Mã tự viết, không nhúng mã GPL Fermata. Phông Noto Sans được đóng gói theo SIL Open Font License 1.1, kèm bản quyền tại `assets/fonts/OFL.txt`.
