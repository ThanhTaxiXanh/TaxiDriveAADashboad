# Giai đoạn 4 — bản đồ và dẫn đường

## Nguồn đã kiểm tra

- [flutter_map](https://pub.dev/packages/flutter_map) và [flutter_map_vector_tiles](https://pub.dev/packages/flutter_map_vector_tiles): dùng 8.3.2 / 2.10.1 sau khi đọc tài liệu và constructor StyleReader/VectorTileLayer. Gói vector_map_tiles cũ 8.0.0 khác với flutter_map_vector_tiles; không dùng nhầm. Lớp vẽ Dart, không PlatformView.
- [OpenFreeMap Quick Start](https://openfreemap.org/quick_start/): style liberty/dark, không khóa. App chỉ tải vùng đang xem, không tải hàng loạt. Giới hạn tải offline công khai 3.000 tiles hoặc 50 MB/lần không bị dùng để xây gói offline; cache viewport tự nhiên được giữ tối đa khoảng 300 MB. Có thể chưa có vùng mới khi mất mạng.
- [StyleReader source](https://github.com/JonasGrunau/flutter-map-vector-tiles/blob/main/lib/src/style/style_reader.dart): bundle/style/TileJSON/sprite cache, headers chuyển tới tile provider; style.dispose giải phóng tài nguyên. Logger.noop tránh đưa tile URL vào nhật ký.
- [Valhalla API](https://valhalla.github.io/valhalla/api/route/api-reference/), [locale vi-VN](https://github.com/valhalla/valhalla/blob/master/locales/vi-VN.json): yêu cầu costing auto, kilometers, vi-VN, shape polyline6. Chỉ dùng instruction tiếng Việt khi phản hồi xác nhận trip.language vi-VN. Nếu ngôn ngữ khác, dùng bảng maneuver type trong tài liệu để tạo câu Việt. Nếu API lỗi, dùng OSRM.
- [OSRM API](https://project-osrm.org/docs/v5.24.0/api/#route-service), [FOSSGIS usage](https://routing.openstreetmap.de/about.html): routed-car/route/v1/driving, GeoJSON lon/lat, steps true, User-Agent, tối đa 1 yêu cầu/giây. App giới hạn tuyến toàn cục 5 giây và backoff lỗi 30 giây; mỗi nhà cung cấp chỉ nhận một yêu cầu mỗi lượt.
- [Photon](https://github.com/komoot/photon): API /api/?q=...&limit=5, GeoJSON. Dùng cá nhân với bộ nhớ đệm và bấm tìm thủ công, không tra cứu định kỳ. Máy chủ Photon/Valhalla/OSRM thay được không cần cập nhật APK; chỉ chấp nhận HTTPS không chứa userinfo/query/fragment. Không dùng Nominatim làm dịch vụ tra cứu mặc định.
- [Android permissions](https://developer.android.com/develop/sensors-and-location/location/permissions), [location foreground service](https://developer.android.com/develop/background-work/services/fgs/service-types#location): xin coarse/fine cùng lượt, khởi động từ Activity đang mở sau cấp quyền. Service loại location giữ GPS khi màn hình tắt. v0.4.1 khai báo ACCESS_BACKGROUND_LOCATION, xin foreground trước; Always là bước riêng do người dùng chọn (Android 11+ mở cài đặt). Không tự khởi động sau boot.

## Kiến trúc và hành vi

Một NavigationState native giữ GPS hiện tại trong RAM và chia sẻ trạng thái qua kênh riêng taxi/navigation/events. Tệp tuyến/địa điểm/cache tìm kiếm trong bộ nhớ riêng, không FileProvider. Không nhận tọa độ qua Diagnostics và không log exception chứa URL tìm đường. Thông báo foreground chỉ có tên app và nút dừng, không lộ điểm đến.

Hai Dart engine có controller riêng nhưng native cấp một lease có thời hạn 45 giây cho việc tính tuyến, kèm goalRevision. Phản hồi không trùng lease/revision bị bỏ qua. Chỉ tính khi bắt đầu hoặc lệch tuyến qua ba fix tốt; tối thiểu 5 giây/lần, lỗi 30 giây. Dừng/đổi đích vô hiệu hóa phản hồi cũ. Native dedup câu đọc bằng routeRevision/maneuver/bucket khoảng cách, dùng giọng Việt đã cài không cần mạng và audio focus navigation. Không có giọng Việt: UI báo thiếu, vẫn có chữ.

RouteProgress chiếu lên từng đoạn polyline bằng mặt phẳng địa phương, tính khoảng cách dọc tuyến bằng đường tích lũy. Ở giao cắt lặp ưu tiên tiến độ gần fix trước (penalty bị chặn 30 m); đây không phải map-matching đầy đủ hoặc hướng dẫn làn xe. Không phát câu khi lệch tuyến, vị trí quá 10 giây/sai số trên 50 m; khi vào 30 m đích và còn dưới 45 m tuyến mới coi đã đến. Không tính hạn tốc pháp lý từ tốc độ GPS.

Bản đồ xoay/làm mượt hướng theo cung ngắn, zoom theo tốc độ. Kéo/zoom tắt theo xe; nút Theo xe bật lại. Pinch host đổi zoom ở tâm (chưa neo chính xác theo focus). Theme Liberty/Dark, nhãn style được đặt tối thiểu 16; chỉ phần đã cache hiển thị khi offline. Bản đầu không tính tuyến offline, không lane guidance/live traffic. Dùng thử tuyến thật là điều kiện nghiệm thu, chưa tuyên bố được kiểm tra trên xe bởi CI.

## Kiểm tra

Hermetic tests dùng tuyến chữ L và phản hồi JSON giả lập, không gọi mạng: polyline6, thứ tự lon/lat, câu Việt, chiếu tuyến, vòng heading 350→10, GPS cũ/sai số, lease hai engine, nhập tọa độ tránh geocoding, nguồn bản đồ/nút zoom ở cột hẹp. Hồi quy QR có PNG alpha thật và vòng raster→ZXing.

Workflow Public map service probes gọi các dịch vụ một lần với fixture công khai ở Bắc Giang, ghi kết quả gọn không có dữ liệu người dùng. Không giả vờ test thực tế nếu máy chủ demo không đáp ứng. Cổng GĐ4: Thanh đi hết một tuyến nội thành và thử mất mạng ngắn ở vùng vừa tải.


## Bổ sung v0.4.1 — camera 3D và vòng đời vị trí

[maplibre_flutter_gpu 0.2.0](https://pub.dev/packages/maplibre_flutter_gpu) (BSD-2-Clause, thư viện cộng đồng mới) dùng MapLibre Native → Flutter GPU, không AndroidView/PlatformView. Đã kiểm tra source JNI, API camera/userLocationBuilder và registry session độc lập cho hai engine. Flutter 3.47.1/Dart 3.13; minSdk 29, APK arm64 là mục tiêu kiểm thử. Có công tắc 2D và tự chuyển 2D khi widget báo lỗi khởi tạo. Không bảo đảm phục hồi mọi lỗi GPU native/process crash; cần thử thiết bị thật.

MapLibre vẽ fill-extrusion thật, pitch được khóa min=max=60°; style Liberty đã có building 3D. Khi style thiếu lớp extrusion, thêm từ source building với render_height/height và render_min_height/min_height, mặc định 0 khi không có dữ liệu. Không dựng chiều cao giả hoặc hứa mô hình chi tiết ở nơi dữ liệu OSM thiếu. Marker Flutter gradient xanh, viền trắng, bóng, 54 dp; theo vị trí/hướng đã chiếu lên viewport, hiện cả khi không dẫn đường. Tọa độ cũ/yếu chuyển xám.

FollowCamera tách trạng thái browse/follow khỏi độ chính xác dẫn đường. Zoom cơ sở 17.8 dưới 30 km/h, giảm liên tục tới 16.9 ở 60 và 15.9 ở 100 km/h. Khi dẫn đường có GPS tốt, tăng zoom tối thiểu 17.0 trong 700 m, 17.7 trong 350 m, 18.2 trong 150 m, 18.5 trong 60 m tới thao tác rẽ. Camera ease 650 ms, recenter 450 ms. Kéo thực >6 px, pinch/double-tap/scroll hoặc nút +/- tắt theo xe; cập nhật camera do app không tắt theo xe. Nút Theo xe luôn dùng fix gần nhất kể cả cũ và xin GPS mới nếu cần; không nới điều kiện phát chỉ dẫn. Shared gesture đầu tiên là baseline, tránh engine mới tự phát lại thao tác zoom cũ.

[AndroidX CarConnection](https://developer.android.com/reference/androidx/car/app/connection/CarConnection) observeForever ở Application, query authority androidx.car.app.connection. Projection kết nối tự bật foreground GPS nếu được cấp fine/coarse và đủ điều kiện foreground/background. Rời projection chờ 2,5 giây, hủy nếu nối lại, rồi stopService; onDestroy gỡ tất cả LocationManager updates, xóa fix RAM và dừng dẫn đường. Không dùng SurfaceDestroyed/onStop/Home làm tín hiệu ngắt xe. Dừng bằng app/thông báo chặn tự bật trong kết nối hiện tại; user bấm bật hoặc kết nối mới sẽ bỏ chặn. Android/Xiaomi vẫn có thể hạn chế khởi động nền: báo mở app, không cố lách hệ thống. Quyền Always không đồng nghĩa thu GPS liên tục sau ngắt xe.

Native Android renderer 0.2.0 có cache SQLite RAM. Application cài android.net.http.HttpResponseCache riêng 300 MB cho HttpURLConnection của native adapter; cache phụ thuộc response cache header, có thể bị Android dọn; không prefetch hoặc tải bulk. Style cơ sở light/dark lưu JSON riêng để mở lại khi mất mạng; route/đích chỉ ghép vào style trong RAM, không ghi thêm bản sao vào style cache. 2D giữ cache tiles 300 MB riêng. Vùng chưa tải/tài nguyên hết hạn cần mạng; chưa hỗ trợ gói offline hoàn chỉnh.

CI bổ sung regression thực thao tác camera 2D với GPS cũ, zoom theo speed/turn, gesture baseline, hướng đầu tiên, GeoJSON source/lon-lat/real heights và kiểm tra thư viện/shader trong APK arm64. CI headless không xác nhận rendering GPU trên VirtualDisplay. Cần kiểm tra VF e34: pitch/marker khi có và không có tuyến, +/-/kéo rồi Theo xe, tăng tốc/gần rẽ, tắt màn hình điện thoại, mất mạng ngắn, Home, ngắt và nối lại AA cả dây/không dây; GPS/notification phải biến mất sau ngắt.
