# Giai đoạn 4 — bản đồ và dẫn đường

## Nguồn đã kiểm tra

- [flutter_map](https://pub.dev/packages/flutter_map) và [flutter_map_vector_tiles](https://pub.dev/packages/flutter_map_vector_tiles): dùng 8.3.2 / 2.10.1 sau khi đọc tài liệu và constructor StyleReader/VectorTileLayer. Gói vector_map_tiles cũ 8.0.0 khác với flutter_map_vector_tiles; không dùng nhầm. Lớp vẽ Dart, không PlatformView.
- [OpenFreeMap Quick Start](https://openfreemap.org/quick_start/): style liberty/dark, không khóa. App chỉ tải vùng đang xem, không tải hàng loạt. Giới hạn tải offline công khai 3.000 tiles hoặc 50 MB/lần không bị dùng để xây gói offline; cache viewport tự nhiên được giữ tối đa khoảng 300 MB. Có thể chưa có vùng mới khi mất mạng.
- [StyleReader source](https://github.com/JonasGrunau/flutter-map-vector-tiles/blob/main/lib/src/style/style_reader.dart): bundle/style/TileJSON/sprite cache, headers chuyển tới tile provider; style.dispose giải phóng tài nguyên. Logger.noop tránh đưa tile URL vào nhật ký.
- [Valhalla API](https://valhalla.github.io/valhalla/api/route/api-reference/), [locale vi-VN](https://github.com/valhalla/valhalla/blob/master/locales/vi-VN.json): yêu cầu costing auto, kilometers, vi-VN, shape polyline6. Chỉ dùng instruction tiếng Việt khi phản hồi xác nhận trip.language vi-VN. Nếu ngôn ngữ khác, dùng bảng maneuver type trong tài liệu để tạo câu Việt. Nếu API lỗi, dùng OSRM.
- [OSRM API](https://project-osrm.org/docs/v5.24.0/api/#route-service), [FOSSGIS usage](https://routing.openstreetmap.de/about.html): routed-car/route/v1/driving, GeoJSON lon/lat, steps true, User-Agent, tối đa 1 yêu cầu/giây. App giới hạn tuyến toàn cục 5 giây và backoff lỗi 30 giây; mỗi nhà cung cấp chỉ nhận một yêu cầu mỗi lượt.
- [Photon](https://github.com/komoot/photon): API /api/?q=...&limit=5, GeoJSON. Dùng cá nhân với bộ nhớ đệm và bấm tìm thủ công, không tra cứu định kỳ. Máy chủ Photon/Valhalla/OSRM thay được không cần cập nhật APK; chỉ chấp nhận HTTPS không chứa userinfo/query/fragment. Không dùng Nominatim làm dịch vụ tra cứu mặc định.
- [Android permissions](https://developer.android.com/develop/sensors-and-location/location/permissions), [location foreground service](https://developer.android.com/develop/background-work/services/fgs/service-types#location): xin coarse/fine cùng lượt, khởi động từ Activity đang mở sau cấp quyền. Service loại location giữ GPS khi màn hình tắt. Không xin ACCESS_BACKGROUND_LOCATION; không tự khởi động sau boot/process kill.

## Kiến trúc và hành vi

Một NavigationState native giữ GPS hiện tại trong RAM và chia sẻ trạng thái qua kênh riêng taxi/navigation/events. Tệp tuyến/địa điểm/cache tìm kiếm trong bộ nhớ riêng, không FileProvider. Không nhận tọa độ qua Diagnostics và không log exception chứa URL tìm đường. Thông báo foreground chỉ có tên app và nút dừng, không lộ điểm đến.

Hai Dart engine có controller riêng nhưng native cấp một lease có thời hạn 45 giây cho việc tính tuyến, kèm goalRevision. Phản hồi không trùng lease/revision bị bỏ qua. Chỉ tính khi bắt đầu hoặc lệch tuyến qua ba fix tốt; tối thiểu 5 giây/lần, lỗi 30 giây. Dừng/đổi đích vô hiệu hóa phản hồi cũ. Native dedup câu đọc bằng routeRevision/maneuver/bucket khoảng cách, dùng giọng Việt đã cài không cần mạng và audio focus navigation. Không có giọng Việt: UI báo thiếu, vẫn có chữ.

RouteProgress chiếu lên từng đoạn polyline bằng mặt phẳng địa phương, tính khoảng cách dọc tuyến bằng đường tích lũy. Ở giao cắt lặp ưu tiên tiến độ gần fix trước (penalty bị chặn 30 m); đây không phải map-matching đầy đủ hoặc hướng dẫn làn xe. Không phát câu khi lệch tuyến, vị trí quá 10 giây/sai số trên 50 m; khi vào 30 m đích và còn dưới 45 m tuyến mới coi đã đến. Không tính hạn tốc pháp lý từ tốc độ GPS.

Bản đồ xoay/làm mượt hướng theo cung ngắn, zoom theo tốc độ. Kéo/zoom tắt theo xe; nút Theo xe bật lại. Pinch host đổi zoom ở tâm (chưa neo chính xác theo focus). Theme Liberty/Dark, nhãn style được đặt tối thiểu 16; chỉ phần đã cache hiển thị khi offline. Bản đầu không tính tuyến offline, không lane guidance/live traffic. Dùng thử tuyến thật là điều kiện nghiệm thu, chưa tuyên bố được kiểm tra trên xe bởi CI.

## Kiểm tra

Hermetic tests dùng tuyến chữ L và phản hồi JSON giả lập, không gọi mạng: polyline6, thứ tự lon/lat, câu Việt, chiếu tuyến, vòng heading 350→10, GPS cũ/sai số, lease hai engine, nhập tọa độ tránh geocoding, nguồn bản đồ/nút zoom ở cột hẹp. Hồi quy QR có PNG alpha thật và vòng raster→ZXing.

Workflow Public map service probes gọi các dịch vụ một lần với fixture công khai ở Bắc Giang, ghi kết quả gọn không có dữ liệu người dùng. Không giả vờ test thực tế nếu máy chủ demo không đáp ứng. Cổng GĐ4: Thanh đi hết một tuyến nội thành và thử mất mạng ngắn ở vùng vừa tải.
