# Taxi Xanh · Android Auto Dashboard

**Giai đoạn 6 — v0.6.0: điều khiển nhạc và bảng YouTube.** Thanh xác nhận v0.5.1 tạm ổn và chỉ đạo tiếp. [Danh sách công việc và tiêu chí còn lại](docs/PROGRESS.md). Giữ bản đồ 60°, lịch, QR, gói đường và khóa ký.

## Cài và bật vị trí trên điện thoại

1. Cài đè [APK arm64 nightly](https://github.com/ThanhTaxiXanh/TaxiDriveAADashboad/releases/download/nightly/app-arm64-v8a-release.apk) khi Releases ghi **Giai đoạn 6 · v0.6.0**. Không đổi khóa ký hoặc gỡ app.
2. Mở **Bản đồ và dẫn đường → Bật vị trí** khi app đang mở. Cấp quyền vị trí khi dùng app, bật **Vị trí chính xác**, cho phép thông báo để thấy nút **Dừng vị trí**. Sau đó bấm **Cho phép vị trí Luôn luôn → Mở cài đặt**, vào **Quyền ứng dụng → Vị trí → Luôn cho phép** (Android 13), giữ **Vị trí chính xác**. Đây là quyền riêng, cần anh bật trong cài đặt hệ thống. Dịch vụ foreground tiếp tục GPS khi điện thoại tắt màn hình.
3. Chờ dòng **GPS chính xác**. Nếu chưa có, bật GPS hệ thống/ra nơi thoáng; mở **Quyền ứng dụng** nếu trước đó từ chối. Giọng đọc cần bộ giọng Việt ngoại tuyến đã cài trong máy; nút **Cài dữ liệu giọng đọc** mở công cụ hệ thống. Thiếu giọng vẫn có chữ chỉ đường.
4. Nhập tên địa điểm rồi bấm **Tìm địa điểm**, chọn **Dẫn đường**. Có thể nhập `vĩ độ,kinh độ` để bỏ qua tra cứu mạng. Bấm sao để lưu yêu thích. Trên xe chỉ chọn **Yêu thích và gần đây**, không có bàn phím.
5. Kết nối Android Auto. Cột trái hiện bản đồ OpenFreeMap 3D nghiêng 60°, mũi tên xanh viền trắng cả khi chưa dẫn đường, tuyến xanh, thao tác tiếp theo/khoảng cách, tốc độ GPS và quãng đường/ETA ước tính. Có +/−, **Theo xe**, sao để chọn nơi đã lưu. Kéo/zoom bản đồ sẽ ngừng theo xe; bấm **Theo xe** để về tọa độ gần nhất và bật theo xe trở lại, kể cả GPS đang cũ/yếu. Tọa độ cũ có mũi tên xám; app xin vị trí mới, không phát chỉ dẫn rẽ khi GPS cũ. Camera tự mở rộng khi tốc độ tăng, phóng gần hơn khi sắp rẽ. Bản đồ vẫn nghiêng 60° khi chưa chọn tuyến. Pinch từ host thay zoom ở tâm bản đồ.
6. Dùng **Dừng dẫn đường** để xóa tuyến đang chạy. GPS tự dừng khoảng 2,5 giây sau khi Android Auto ngắt kết nối; kết nối lại sẽ tự bật nếu quyền và hệ thống cho phép. Đổi trang/bấm Home trên xe vẫn giữ GPS. Có thể bấm **Dừng vị trí** trong app hoặc thông báo bất cứ lúc nào; tự bật lại ở lần kết nối mới hoặc bấm Bật vị trí. Nếu Xiaomi chặn khởi động nền, mở app điện thoại và bấm Bật vị trí; kiểm tra tiết kiệm pin cho app nếu cần.

## Nhạc và YouTube

1. Mở **Nhạc và YouTube** trên điện thoại. Để điều khiển Spotify/Zing MP3/YouTube Music…, chọn **Ứng dụng nhạc đang chạy**, mở **Truy cập thông báo** và bật Taxi Xanh. Mở app nhạc, phát một bài, quay lại kiểm tra tên/bìa và các nút. Nếu Android 13 chặn quyền của APK cài ngoài, vào Thông tin ứng dụng → ⋮ → Cho phép cài đặt bị hạn chế rồi bật lại quyền. Ứng dụng chỉ dùng quyền để lấy MediaSession, không đọc nội dung thông báo.
2. Dùng **Tìm video** hoặc dán link và **Lưu liên kết / playlist**. Danh sách công khai được lưu riêng trên máy (tối đa 200 bài mỗi danh sách). Bấm Phát để kiểm tra mạng điện thoại trước chuyến đi. Trên xe, mở icon YouTube, chọn Yêu thích / Danh sách / Gần đây bằng nút lớn; cột bản đồ vẫn hiện.
3. Mặc định phát **âm thanh**. Khi xe đang đỗ, bật GPS chính xác, chờ có tốc độ hợp lệ dưới 5 km/h rồi bấm **Xem video khi đỗ**. Video khóa khi tốc độ từ 5 km/h, vị trí cũ/yếu hoặc GPS dừng. Tiếng tiếp tục, hình chỉ bật lại khi anh bấm; không tự xuất hiện sau khi xe dừng.
4. Hàng Media có trước/phát-tạm dừng/sau, tên bài, tiến trình; đủ cao mới thêm nghệ sĩ/bìa. App nhạc khác có thể không hỗ trợ đủ nút. Trình phát YouTube có foreground notification và tiếp tục khi tắt màn hình điện thoại. Đang dùng nguồn YouTube có thể bấm Dừng để kết thúc.
5. Cần thử trên xe: điều khiển một app nhạc; phát playlist ít nhất **30 phút**, kiểm tra tự chuyển bài và tiếng dẫn đường; kiểm tra khóa video khi di chuyển/mất GPS/ngắt AA. Đồng hồ **Thời gian phát thực** chỉ cộng lúc player đang phát. CI không thay nghiệm thu này.

YouTube dùng trình lấy luồng trực tiếp cho nội dung công khai, không cần API key/thẻ; không đăng nhập và chưa hỗ trợ livestream/DRM/nội dung riêng tư/giới hạn tuổi. Luồng có thể bị YouTube chặn hoặc thay đổi. Phép thử mạng trên CI chưa xác nhận phát trên điện thoại; chưa tuyên bố đạt playlist 30 phút. Chi tiết kiến trúc, phép thử và giấy phép trong [MEDIA_NOTES.md](docs/MEDIA_NOTES.md).

## Bật tốc độ và biển báo

1. Mở **Bản đồ và dẫn đường → Tốc độ và biển báo → Tải / cập nhật dữ liệu Việt Nam** bằng Wi-Fi trước chuyến đi. Chờ báo gói sẵn sàng ngoại tuyến; dung lượng thực nằm trong [manifest gói](https://github.com/ThanhTaxiXanh/TaxiDriveAADashboad/releases/download/road-data/manifest.json). Gói riêng, không cần cài lại APK mỗi tháng.
2. Loại xe mặc định **Ô tô con · VF e34**. Hạn tốc hiện cạnh tốc độ GPS, ghi nguồn **ghim của anh**, **OSM** hoặc **ước tính**. Số nét đứt chỉ là suy đoán, có thể tắt. Xe con: đường hai chiều có dải phân cách cứng 60/90 (trong/ngoài khu đông dân cư), không có 50/80; đường một chiều ≥2 làn cơ giới cũng nhóm 60/90. Vạch sơn/tổng số làn hai chiều không chứng minh có dải phân cách cứng. Giới hạn cụ thể theo đoạn và chiều được ưu tiên. Chưa đủ dữ liệu/khớp đường/GPS thì hiện **—**, không gán mặc định 120 cho cao tốc.
3. Biển OSM quanh GPS và ghim riêng hiện trực tiếp bằng biểu tượng trên bản đồ 2D/3D, kể cả lúc đứng yên/chưa dẫn đường. Chạm trên điện thoại để xem nguồn/hướng; ghim riêng có thể sửa. Nhãn **Đoạn** và viền nét đứt chỉ điểm đầu đoạn OSM, không xác nhận biển thật. Biển phía trước có hướng và khoảng cách; tối đa ba mục. Nhãn **Đoạn OSM** là đầu đoạn có dữ liệu tốc độ, không xác nhận vị trí biển thật. Vượt mức + dung sai 5 km/h đổi cam/nhấp nháy; có chỉnh dung sai và bật bíp (mặc định tắt; không bíp mức ước tính).
4. **Nhấn giữ bản đồ trên điện thoại** để ghim; chạm ghim hoặc mở danh sách để sửa/xóa. Chọn loại biển, tốc độ, hướng xe đi (0° Bắc, 90° Đông) hoặc hai chiều. Ghim hạn tốc áp dụng sau vị trí đó trong phạm vi chọn, mặc định 300 m, ưu tiên hơn OSM. Nên tải gói trước để gắn đúng đoạn đường.
5. **Xuất ghim JSON** để sao lưu riêng. **Nhập ghim JSON** thay danh sách hiện tại sau khi kiểm tệp. Ghim/vị trí không đưa lên repo, gói công khai hoặc Chia sẻ nhật ký. Trên xe chỉ xem cảnh báo; chỉnh ghim trên điện thoại.

Dữ liệu có thể thiếu hoặc sai; luôn tuân theo biển thực tế. Không nhận diện biển bằng camera. Gói OSM Việt Nam dựng hằng tháng, số liệu và nguồn trong [ROAD_DATA.md](docs/ROAD_DATA.md). Sau khi tải, tốc độ/biển báo dùng offline; nền bản đồ vùng chưa cache và tuyến mới vẫn cần mạng.

## QR và logo đã sửa

- Khung ảnh/logo đặt nền trắng; PNG vẫn giữ alpha, không bị ghép lên nền đen. Bước ZXing ghép lên trắng để đọc đúng ảnh QR trong suốt.
- Logo thương hiệu luôn ngay dưới QR ở hàng thường lẫn lúc mở rộng. Giữ đúng tỷ lệ, dùng hết chiều rộng khi chiều cao cho phép; ưu tiên logo rõ nét, không kéo méo. Ảnh giữ cạnh dài tới 2048 px và dùng lọc chất lượng cao. Hàng quá thấp có thể tăng trọng số QR trong **Chỉnh bố cục**.
- Ảnh đã mất alpha từ trước cần chọn lại PNG gốc. Tài khoản/logo chỉ lưu trong app, không lên repo hoặc nhật ký. [Hướng dẫn QR đầy đủ](docs/PHASE_3.md).

## Thử một tuyến thật

Chuẩn bị điểm đến và quyền khi xe đang đỗ. Đi trọn một tuyến trong thành phố, kiểm tra vị trí/hướng, câu rẽ Việt, âm thanh và khoảng cách. Thử ra khỏi tuyến để tính lại; thử tắt mạng ngắn ở vùng vừa xem để kiểm tra bản đồ/tuyến còn hiện. Sau đó kết nối lại có dây/không dây và kiểm tra QR/lịch/Home.

GPS cũ hơn 10 giây hoặc sai số trên 50 m ngừng phát chỉ dẫn; lệch tuyến trên 50 m qua ba fix tốt mới xin tuyến mới. Hai engine dùng một khóa tính đường, ít nhất 5 giây giữa các lần; lỗi mạng chờ 30 giây. Tuyến đã tải được giữ riêng; 3D có cache HTTP riêng tối đa 300 MB, dùng lại tài nguyên còn hạn theo cache header máy chủ; 2D có cache tiles riêng tối đa 300 MB. Đây là cache vùng vừa xem, không phải gói bản đồ offline; vùng chưa tải/tuyến mới cần mạng. Chưa có tìm đường ngoại tuyến hoặc giao thông trực tiếp. ETA chỉ ước tính. GĐ5 đã bổ sung gói đường riêng và ghim; GĐ6 bổ sung Media/YouTube với phép thử thiết bị riêng.

Cổng GĐ5: kiểm tra khoảng cách báo trước ở **ba biển thực tế, sai lệch dưới 50 m**, thử chiều ngược lại và mất mạng sau khi cài gói. Bộ GPX/OSM mẫu trong CI không thay cho kiểm tra trên xe. Thanh đã cho phép tiếp tục GĐ6 sau khi v0.5.1 tạm ổn; tiêu chí khoảng cách này vẫn chưa được xác nhận bằng số đo.

## Dịch vụ, riêng tư và kiểm tra

- Mặc định dùng MapLibre Native qua maplibre_flutter_gpu 0.2.0 và Flutter GPU, không PlatformView trên VirtualDisplay. Android tối thiểu 10; dùng APK arm64 cho Redmi Note 12 Pro. Đây là thư viện mới, CI kiểm tra biên dịch/đóng gói, còn độ mượt và tương thích GPU cần thử trên điện thoại/xe thật. Nếu lỗi khởi tạo có bản đồ 2D dự phòng; có thể tắt **Bản đồ 3D · nghiêng 60°** trong cài đặt dẫn đường để chủ động dùng 2D. Nhà 3D theo chiều cao có trong dữ liệu OSM, không đảm bảo mô hình chi tiết như ảnh Chicago; khu vực thiếu dữ liệu vẫn có mặt đường, marker và góc nghiêng. 2D dùng flutter_map + flutter_map_vector_tiles. Style Liberty/Dark theo giao diện, nhãn bản đồ từ 16 dp, tên tiếng Việt nếu dữ liệu có. Ghi nguồn OpenFreeMap, OpenMapTiles, OpenStreetMap luôn hiện.
- Photon tìm địa điểm theo nút bấm, có User-Agent, cache 64 truy vấn, cách nhau ít nhất 1,1 giây, không autocomplete. Valhalla mặc định yêu cầu vi-VN; nếu máy chủ không đáp ứng, dùng OSRM và câu Việt theo loại thao tác. Có đổi máy chủ HTTPS trên điện thoại. Không cần tài khoản, khóa API hay thẻ thanh toán. Máy chủ công cộng không có cam kết sẵn sàng; giới hạn FOSSGIS tối đa 1 yêu cầu/giây được áp dụng chặt hơn ở app.
- Truy vấn tìm kiếm đi tới Photon; tọa độ đầu/đích đi tới máy chủ tìm đường; vùng bản đồ đi tới OpenFreeMap. GPS tức thời chỉ trong RAM; điểm đã lưu, cache truy vấn và tuyến gần nhất ở bộ nhớ riêng, Android backup tắt. Không đưa tọa độ/địa điểm/tuyến vào **Chia sẻ nhật ký**, repo hoặc JSON sự kiện. Không ghi lịch sử hành trình.
- Android LocationManager + foreground service và TextToSpeech dùng chung cả hai engine. Cầu nối navigation riêng, không dùng kênh nhật ký kỹ thuật; native chống phát câu trùng và phản hồi tuyến cũ. Các thư viện Dart thực hiện luật tuyến, hiển thị và mạng.
- CI unit/widget kiểm tra alpha/QR, lịch, hình học tuyến, polyline6, Valhalla/OSRM, stale GPS, lease giữa engine, cấu hình HTTPS, camera theo tốc độ/chỗ rẽ, hồi quy về vị trí sau khi kéo/zoom với GPS cũ, GeoJSON/nhà 3D và bố cục cột hẹp. APK arm64 được kiểm tra có thư viện MapLibre và shader GPU. Test headless không khởi tạo GPU thật. **Public map service probes** dùng duy nhất tọa độ mẫu công khai ở trung tâm Bắc Giang; báo khả dụng riêng, không thay thử xe thật.

[Tiến độ](docs/PROGRESS.md) · [Media/YouTube](docs/MEDIA_NOTES.md) · [Tốc độ/biển báo và dữ liệu](docs/ROAD_DATA.md) · [Chi tiết bản đồ và nguồn](docs/NAVIGATION_NOTES.md) · [QR](docs/QR_NOTES.md) · [Lịch](docs/CALENDAR_NOTES.md) · [Đặc tả](docs/SPECIFICATION.md) · [Nghiên cứu Fermata](docs/FERMATA_REVIEW.md).

Giữ ciphertext android/signing/personal.jks.gpg và Secret ANDROID_SIGNING_PASSWORD; không tạo lại khóa. Noto Sans theo SIL OFL, giấy phép đóng gói cùng APK. Thông báo giấy phép các gói được Flutter đóng gói; bản đồ/dữ liệu OSM theo ghi nguồn/ODbL.
