# Tiến độ và việc còn lại

Cập nhật ngày 29/10/2026. Thanh cho phép tiếp tục GĐ6 sau khi dùng v0.5.1 và xác nhận “tạm ổn”. Các thao tác GitHub cần thiết đã được cho phép, không cần hỏi lại xác nhận thường lệ.

| Giai đoạn | Trạng thái | Việc còn lại |
|---|---|---|
| 0 · Thử Flutter trên Android Auto | Đã có APK ký và Thanh đã thử xe | Giữ kiến trúc Surface/VirtualDisplay đã chạy |
| 1 · Bố cục | Đã triển khai và dùng thực tế | Kiểm tra lại trong đợt chạy một giờ GĐ7 |
| 2 · Lịch/sự kiện | Thanh xác nhận ổn định | Giữ kiểm thử lịch và nhập/xuất JSON |
| 3 · QR/logo | Đã triển khai, sửa nền PNG và logo dưới QR | Giữ kiểm thử dựng/giải mã và dữ liệu riêng |
| 4 · Bản đồ/GPS | Thanh đã dùng bản 3D 60° | Giữ kiểm thử camera, Theo xe và ngắt AA |
| 5 · Tốc độ/biển | v0.5.1 tạm ổn, được chỉ đạo tiếp | Chưa có số đo xác nhận sai lệch dưới 50 m tại 3 biển thật; chưa xác nhận ranh khu đông dân cư |
| 6 · Media/YouTube | Đã triển khai mã v0.6.0; chờ nghiệm thu | Theo dõi CI/APK; thử app nhạc, playlist 30 phút và khóa video trên xe |
| 7 · Hoàn thiện | Chưa bắt đầu | Hiệu năng/pin, mất kết nối, nhật ký, hướng dẫn cài lại; chạy một giờ và v1.0 |

## GĐ6

- [x] Đọc API MediaSession/NotificationListener, Media3 và SurfaceProducer; kiểm tra thư viện/giấy phép lấy luồng.
- [x] Viết cầu nối điều khiển phiên nhạc khác và hàng Media.
- [x] Viết một trình phát native, hàng đợi dùng chung và resolver nền, không phụ thuộc màn hình điện thoại còn mở.
- [x] Viết tìm kiếm/lưu playlist trên điện thoại, danh sách lớn trên xe; giữ bản đồ khi mở YouTube.
- [x] Khóa video ở UI và native theo GPS mới/chính xác, tốc độ dưới 5 km/h; mất GPS/AA thì hình khóa, âm thanh tiếp tục.
- [x] Có bộ kiểm thử và pipeline biên dịch/ký; APK chỉ cập nhật sau khi các kiểm tra đạt. [Run mới nhất](https://github.com/ThanhTaxiXanh/TaxiDriveAADashboad/actions/workflows/ci.yml) · [APK được phát hành](https://github.com/ThanhTaxiXanh/TaxiDriveAADashboad/releases/tag/nightly). Xem đúng phiên bản trên trang phát hành.
- [ ] Xác nhận lấy và phát luồng trên Redmi Note 12 Pro; phép thử từ IP CI chưa chứng minh được khả năng phát trên điện thoại.
- [ ] Điều khiển được app nhạc đang phát bằng hàng 3.
- [ ] Playlist YouTube phát liên tục ít nhất 30 phút; thử chuyển bài, hết danh sách, tắt màn hình điện thoại và giọng dẫn đường.
- [ ] Video tự ẩn trên 5 km/h và khi vị trí không còn tin cậy; sau khi dừng phải bấm bật lại.

Các ô thử xe chỉ đánh dấu sau phản hồi thực tế của Thanh; CI không thay thế các phép thử này.
