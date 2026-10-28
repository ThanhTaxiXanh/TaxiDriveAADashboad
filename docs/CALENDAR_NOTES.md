# Lịch Việt Nam và dữ liệu sự kiện

Port tệp Kotlin do Thanh cung cấp sang Dart, giữ EPOCH=2415021.076998695, SYNODIC=29.530588853, TZ=7 và các hệ số thiên văn. Phép chia số nguyên đổi thành `~/`. Cache chỉ giúp tránh tính lại, không thay kết quả.

Khác biệt có chủ đích: `lunarToSolar` kiểm tra ngược sau chuyển đổi và từ chối cờ nhuận trong năm không nhuận. Bản Kotlin có thể trả một ngày dương cho ngày 30 không tồn tại hoặc cho cờ nhuận sai; không sửa dữ liệu để ép vector khớp. Lớp sự kiện mới áp dụng riêng quy tắc chuyển ngày 30 âm sang 29 khi tháng thiếu, và đánh dấu rõ trong danh sách.

CI kiểm tra bốn mốc Tết trong đặc tả (10/2/2024, 29/1/2025, 17/2/2026, 6/2/2027), tháng nhuận năm 2023/2025, Can Chi, ngày không hợp lệ và mọi ngày dương từ 1/1/2000 đến 31/12/2050 (18.628 ngày) qua vòng chuyển đổi hai chiều. Vòng hai chiều kiểm tra tính nhất quán của port, không thay thế đối chiếu lịch thiên văn độc lập. Thanh đối chiếu thêm năm ngày bất kỳ qua nút “Đối chiếu một ngày”.

Ngày hiện tại luôn lấy UTC+7 từ thời điểm UTC, không phụ thuộc múi giờ điện thoại. Tất cả hiệu ngày tính trên civil date UTC để không lệch vì DST của máy. Ngày âm 29/30 và tháng nhuận ghi rõ; Can Chi theo năm âm.

## Nguồn đối chiếu

- [Bảng lịch 2023 của Hong Kong Observatory](https://www.hko.gov.hk/en/gts/time/calendar/pdf/files/2023e.pdf) và [2025](https://www.hko.gov.hk/en/gts/time/calendar/pdf/files/2025e.pdf) cho hai mốc tháng lặp trong test. HKO dùng UTC+8; chỉ đối chiếu hai mốc trùng kết quả (22/3/2023 và 25/7/2025), không dùng lịch HKO thay lịch Việt Nam UTC+7.
- Tệp `reference/LunarCalendar.kt` và các vector do Thanh cung cấp trong đặc tả.
- [Mùng 1 Tết 2024 là 10/2/2024](https://www2.en.baochinhphu.vn/kiem-tra-du-an-duong-day-500kv-mach-3-ngay-dau-nam-moi-10224021109124226.htm).
- [Mùng 1 Tết 2025 là 29/1/2025](https://baochinhphu.vn/da-nang-nhon-nhip-chao-don-du-khach-quoc-te-xong-dat-dau-nam-102250129115334451.htm).
- [Mùng 1 Tết 2026 là 17/2/2026](https://tphcm.baochinhphu.vn/hanh-khach-di-lai-mien-phi-tren-tau-metro-so-1-ngay-29-thang-chap-den-mong-1-tet-binh-ngo-2026-101260204190908512.htm).
- [Bộ luật Lao động 45/2019/QH14](https://chinhphu.vn/?docid=198540&pageid=27160), Điều 112; [giải thích chính thức](https://baochinhphu.vn/tu-2021-them-nhieu-quyen-loi-cho-nguoi-lao-dong-102285092.htm).

52 sự kiện trong assets: 19 mốc dương, 9 mốc âm theo danh sách Thanh yêu cầu, 24 mốc Mùng Một/Rằm (mặc định ẩn). Sáu cờ ngày lễ là các mốc 1/1, 30/4, 1/5, 2/9 dương và 1/1, 10/3 âm. Cờ là ngày mốc, không tự sinh toàn bộ lịch nghỉ Tết/Quốc khánh, không tính ngày nghỉ bù hằng năm. Những ngày kỷ niệm khác không gắn cờ nghỉ lễ. Không khẳng định tất cả mốc truyền thống đã được một cơ quan công bố thành lịch nghỉ.

## Lưu và sao lưu

Dùng SQLite qua cầu nối Kotlin thay cho gói drift gợi ý. Một SQLiteOpenHelper duy nhất phục vụ hai engine, nên không có hai bộ cache dữ liệu sự kiện. Thuật toán, mô hình và quy tắc lặp ở Dart. Chỉ engine điện thoại được phép ghi; engine xe chỉ nhận bản đọc và thông báo revision.

Nguồn seed cố định trong APK, chỉ sửa enabled. Sự kiện user được thêm/sửa/xóa. Nhập JSON v1 là gộp theo ID; bản ghi riêng trùng ID được cập nhật, các ID khác vẫn giữ. Với seed chỉ lấy enabled, không thay định nghĩa ngày lễ. Toàn bộ nhập được kiểm tra trước rồi ghi một giao dịch SQLite. Tệp sai không làm xóa dữ liệu cũ. Giới hạn 1 MB/1.000 mục mỗi tệp nhập. Lặp 29/2 dương bỏ qua năm không có 29/2; lặp 30 âm dùng 29 nếu tháng thiếu; chỉ tính tháng thường trừ khi bật cả tháng nhuận.

Ngày/sự kiện/ghi chú không đi vào diagnostics.values hoặc log. Log chỉ có revision và loại lỗi kỹ thuật. Xuất JSON có thể chứa nội dung riêng; chỉ mở hộp chia sẻ để Thanh tự chọn nơi lưu hoặc người nhận. Nhập dùng Android Storage Access Framework, không xin quyền truy cập toàn bộ bộ nhớ.
