# Taxi Xanh · Android Auto Dashboard

**Giai đoạn 0: spike Flutter trên Surface xe. Chưa phải dashboard hoàn chỉnh.**

Thiết bị mục tiêu: VinFast VF e34, màn hình nguyên bản, Android Auto có dây và không dây; Xiaomi Redmi Note 12 Pro, Android 13.

## Đã triển khai

- FlutterEngineGroup: điện thoại `main`, xe `carMain` có giữ entrypoint trong AOT.
- CarAppService NAVIGATION / minCarApi 5, VirtualDisplay → Presentation → FlutterView texture.
- Chữ tiếng Việt, nút đếm chạm, hoạt ảnh thử ~30 Hz, lề visibleArea.
- Chẩn đoán Surface, kích thước/DPI, khung đầu, số chạm, FPS Flutter và lỗi; nút chia sẻ nhật ký bằng FileProvider.
- Dọn engine/display khi ngắt; nhật ký giới hạn khoảng 256 KiB, chỉ trường kỹ thuật, không GPS/tài khoản.
- CI format/analyze/widget tests và APK; xuất bản nightly chỉ khi có khóa ký cá nhân.

Lịch âm, QR theo ảnh, dẫn đường, biển báo và media **chưa triển khai**. Tệp Kotlin đính kèm lưu ở `reference/` để port tại GĐ2. [Đặc tả](docs/SPECIFICATION.md) và [phân tích Fermata](docs/FERMATA_REVIEW.md).

## Tải và cài bằng điện thoại

1. Mở **Actions → CI → run mới nhất → Artifacts → phase-0-apk**, tải zip rồi giải nén và cài `app-debug.apk`. Đây chỉ là bản thử; khóa debug có thể đổi giữa các runner, chưa đảm bảo cập nhật đè. Nếu đổi khóa, Android báo không thể cập nhật; không gỡ app khi đã có dữ liệu cần giữ.
2. APK ký ổn định (khi cấu hình đủ secrets) sẽ ở **Releases → nightly** sau khi main build thành công. Không công bố APK unsigned hoặc debug dưới tên bản ký ổn định.
3. Mở ứng dụng trên điện thoại, xem **Chẩn đoán**.
4. Android Auto → cài đặt → chạm mục **Phiên bản** 10 lần để bật nhà phát triển. Menu ba chấm → cài đặt nhà phát triển → bật **Nguồn không xác định**.
5. Android Auto → **Tùy chỉnh trình khởi chạy**, bật Taxi Xanh. Rút/cắm lại dây hoặc kết nối lại không dây. Bật nguồn không xác định không đảm bảo mọi bản Android Auto đều chấp nhận ứng dụng cài ngoài.

## Thử trên xe khi đang đỗ

1. Thử có dây trước, mở Taxi Xanh trong Android Auto. Kiểm tra rõ dòng “Tiếng Việt: Âm lịch · Đường phố · Nguyễn”.
2. Chạm nút **Chạm thử** 5 lần. Bộ đếm Flutter phải tăng đúng 5; điện thoại phải nhận số chạm từ xe.
3. Chờ 15 giây; xem FPS trong Chẩn đoán. Mục tiêu >=20 FPS; chỉ là FPS pipeline Flutter, cần quan sát xe có giật hay không.
4. Bấm icon taxi ở thanh Android Auto để thoát bằng `finishCarApp()`.
5. Ngắt/kết nối lại 3 lần, lặp lại không dây và kiểm tra điện thoại vẫn dùng độc lập.
6. Chia sẻ nhật ký và báo hình rõ/đen, chữ đúng/lỗi, chạm đúng/sai, FPS, phiên bản Android Auto. Hộp chia sẻ chỉ gửi đi khi anh tự chọn ứng dụng nhận.

Chưa qua cổng GĐ0 cho đến khi anh xác nhận trên xe và có bản ký ổn định. Không chuyển tiếp sang GĐ1 chỉ dựa vào CI xanh.

## Khóa ký ổn định

Cách làm hoàn toàn bằng điện thoại sau khi PR được gộp:

1. Vào **Settings → Secrets and variables → Actions → New repository secret**. Tên `ANDROID_SIGNING_PASSWORD`, giá trị mật khẩu ngẫu nhiên ít nhất 20 ký tự, giữ bí mật và sao lưu riêng.
2. Vào **Actions → Initialize personal signing → Run workflow → main**. Workflow tạo khóa đúng một lần, chỉ commit bản mã hóa GPG AES256 vào `android/signing/personal.jks.gpg`; khóa thô không rời runner. Không chạy lại để thay khóa.
3. Vào **Actions → CI → Run workflow → main**. APK release được giải mã/ký bằng secret trên runner, sau đó lên Releases/nightly khi CI xanh.
4. Sao lưu cả tệp mã hóa và mật khẩu; không đổi mật khẩu secret tùy tiện vì sẽ không giải mã được khóa cũ. Repo công khai chỉ chứa ciphertext; độ an toàn phụ thuộc mật khẩu ngẫu nhiên đủ mạnh. Không tải khóa giải mã vào repo.

Kết nối GitHub hiện có không cung cấp API ghi Secrets, nên anh cần tự nhập secret qua trang Settings. Nếu đã có keystore từ trước, dùng bốn secrets này thay cho cách khởi tạo ở trên:

- `ANDROID_KEYSTORE_BASE64`
- `ANDROID_KEY_ALIAS`
- `ANDROID_KEY_PASSWORD`
- `ANDROID_STORE_PASSWORD`

Không dán khóa vào chat, issue, log hay mã nguồn. Chưa có secrets thì CI chỉ tạo APK thử. Workflow dừng nếu chỉ có một phần secrets; không âm thầm tạo khóa khác. Sao lưu khóa ở nơi riêng tư; mất khóa sẽ không cập nhật đè được. Không có bước yêu cầu Android Studio hoặc máy tính cá nhân. Workflow khởi tạo một lần giúp tạo khóa ngay trên GitHub Actions, không cần máy tính.

## Build và kiểm tra

Flutter ghim 3.47.1, JDK 17, minSdk 28 / targetSdk 36. Actions tạo Gradle wrapper từ template SDK; các tệp ứng dụng Android đã được commit và không bị ghi đè. Test widget kiểm tra tiếng Việt, nút chạm và không overflow tại 1280×720, 1920×720, 800×480. Golden và các test tính năng thuộc các giai đoạn tiếp theo.

Mã tự viết; không nhúng mã GPL của Fermata. Giữ tham chiếu thuật toán lịch âm do người dùng cung cấp, chưa port hoặc phân phối nó trong APK GĐ0.
