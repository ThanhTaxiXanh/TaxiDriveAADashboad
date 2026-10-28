# Taxi Xanh · Android Auto Dashboard

**Giai đoạn 4 — v0.4.0: bản đồ vector, GPS và dẫn đường.** Giữ lịch/sự kiện đã nghiệm thu, sửa PNG trong suốt và luôn hiện logo lớn ngay dưới QR. Thanh đã yêu cầu tiếp tục GĐ4 ngay sau bản sửa QR; không chờ thêm xác nhận QR.

## Cài và bật vị trí trên điện thoại

1. Cài đè [APK arm64 nightly](https://github.com/ThanhTaxiXanh/TaxiDriveAADashboad/releases/download/nightly/app-arm64-v8a-release.apk) khi Releases ghi **Giai đoạn 4**. Không đổi khóa ký hoặc gỡ app.
2. Mở **Bản đồ và dẫn đường → Bật vị trí** khi app đang mở. Cấp quyền vị trí khi dùng app, bật **Vị trí chính xác**, cho phép thông báo để thấy nút **Dừng vị trí**. Không xin quyền vị trí mọi lúc. Dịch vụ foreground tiếp tục GPS khi điện thoại tắt màn hình.
3. Chờ dòng **GPS chính xác**. Nếu chưa có, bật GPS hệ thống/ra nơi thoáng; mở **Quyền ứng dụng** nếu trước đó từ chối. Giọng đọc cần bộ giọng Việt ngoại tuyến đã cài trong máy; nút **Cài dữ liệu giọng đọc** mở công cụ hệ thống. Thiếu giọng vẫn có chữ chỉ đường.
4. Nhập tên địa điểm rồi bấm **Tìm địa điểm**, chọn **Dẫn đường**. Có thể nhập `vĩ độ,kinh độ` để bỏ qua tra cứu mạng. Bấm sao để lưu yêu thích. Trên xe chỉ chọn **Yêu thích và gần đây**, không có bàn phím.
5. Kết nối Android Auto. Cột trái hiện bản đồ OpenFreeMap, vị trí, tuyến xanh, thao tác tiếp theo/khoảng cách, tốc độ GPS và quãng đường/ETA ước tính. Có +/−, **Theo xe**, sao để chọn nơi đã lưu. Kéo bản đồ sẽ ngừng theo xe; bấm **Theo xe** để bật lại. Pinch từ host thay zoom ở tâm bản đồ.
6. Dùng **Dừng dẫn đường** để xóa tuyến đang chạy. Khi kết thúc chuyến, bấm **Dừng vị trí** trong app hoặc thông báo để tắt GPS.

## QR và logo đã sửa

- Khung ảnh/logo đặt nền trắng; PNG vẫn giữ alpha, không bị ghép lên nền đen. Bước ZXing ghép lên trắng để đọc đúng ảnh QR trong suốt.
- Logo thương hiệu luôn ngay dưới QR ở hàng thường lẫn lúc mở rộng. Giữ đúng tỷ lệ, dùng hết chiều rộng khi chiều cao cho phép; ưu tiên logo rõ nét, không kéo méo. Ảnh giữ cạnh dài tới 2048 px và dùng lọc chất lượng cao. Hàng quá thấp có thể tăng trọng số QR trong **Chỉnh bố cục**.
- Ảnh đã mất alpha từ trước cần chọn lại PNG gốc. Tài khoản/logo chỉ lưu trong app, không lên repo hoặc nhật ký. [Hướng dẫn QR đầy đủ](docs/PHASE_3.md).

## Thử một tuyến thật

Chuẩn bị điểm đến và quyền khi xe đang đỗ. Đi trọn một tuyến trong thành phố, kiểm tra vị trí/hướng, câu rẽ Việt, âm thanh và khoảng cách. Thử ra khỏi tuyến để tính lại; thử tắt mạng ngắn ở vùng vừa xem để kiểm tra bản đồ/tuyến còn hiện. Sau đó kết nối lại có dây/không dây và kiểm tra QR/lịch/Home.

GPS cũ hơn 10 giây hoặc sai số trên 50 m ngừng phát chỉ dẫn; lệch tuyến trên 50 m qua ba fix tốt mới xin tuyến mới. Hai engine dùng một khóa tính đường, ít nhất 5 giây giữa các lần; lỗi mạng chờ 30 giây. Tuyến đã tải và các ô bản đồ đã xem có cache khoảng 300 MB; vùng chưa tải/tuyến mới cần mạng. Chưa có tìm đường ngoại tuyến hoặc giao thông trực tiếp. ETA chỉ ước tính. Biển báo/giới hạn tốc độ thuộc GĐ5, chưa được triển khai.

Cổng GĐ4 chờ Thanh xác nhận **đi trọn một tuyến thật và bản đồ còn khi mất mạng ngắn** trước GĐ5.

## Dịch vụ, riêng tư và kiểm tra

- Vẽ thuần Flutter bằng flutter_map + flutter_map_vector_tiles; không dùng PlatformView trên VirtualDisplay. Style Liberty/Dark theo giao diện, nhãn bản đồ từ 16 dp, tên tiếng Việt nếu dữ liệu có. Ghi nguồn OpenFreeMap, OpenMapTiles, OpenStreetMap luôn hiện.
- Photon tìm địa điểm theo nút bấm, có User-Agent, cache 64 truy vấn, cách nhau ít nhất 1,1 giây, không autocomplete. Valhalla mặc định yêu cầu vi-VN; nếu máy chủ không đáp ứng, dùng OSRM và câu Việt theo loại thao tác. Có đổi máy chủ HTTPS trên điện thoại. Không cần tài khoản, khóa API hay thẻ thanh toán. Máy chủ công cộng không có cam kết sẵn sàng; giới hạn FOSSGIS tối đa 1 yêu cầu/giây được áp dụng chặt hơn ở app.
- Truy vấn tìm kiếm đi tới Photon; tọa độ đầu/đích đi tới máy chủ tìm đường; vùng bản đồ đi tới OpenFreeMap. GPS tức thời chỉ trong RAM; điểm đã lưu, cache truy vấn và tuyến gần nhất ở bộ nhớ riêng, Android backup tắt. Không đưa tọa độ/địa điểm/tuyến vào **Chia sẻ nhật ký**, repo hoặc JSON sự kiện. Không ghi lịch sử hành trình.
- Android LocationManager + foreground service và TextToSpeech dùng chung cả hai engine. Cầu nối navigation riêng, không dùng kênh nhật ký kỹ thuật; native chống phát câu trùng và phản hồi tuyến cũ. Các thư viện Dart thực hiện luật tuyến, hiển thị và mạng.
- CI unit/widget kiểm tra alpha/QR, lịch, hình học tuyến, polyline6, Valhalla/OSRM, stale GPS, lease giữa engine, cấu hình HTTPS và bố cục cột hẹp. **Public map service probes** dùng duy nhất tọa độ mẫu công khai ở trung tâm Bắc Giang; báo khả dụng riêng, không thay thử xe thật.

[Chi tiết bản đồ và nguồn](docs/NAVIGATION_NOTES.md) · [QR](docs/QR_NOTES.md) · [Lịch](docs/CALENDAR_NOTES.md) · [Đặc tả](docs/SPECIFICATION.md) · [Nghiên cứu Fermata](docs/FERMATA_REVIEW.md).

Giữ ciphertext android/signing/personal.jks.gpg và Secret ANDROID_SIGNING_PASSWORD; không tạo lại khóa. Noto Sans theo SIL OFL, giấy phép đóng gói cùng APK. Thông báo giấy phép các gói được Flutter đóng gói; bản đồ/dữ liệu OSM theo ghi nguồn/ODbL.
