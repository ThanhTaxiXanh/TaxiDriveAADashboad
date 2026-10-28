# Nghiên cứu Fermata và quyết định Giai đoạn 0

Đã đọc mã gốc ngày 28/10/2026, không sao chép mã vào ứng dụng:

- [MirrorServiceFS](https://github.com/AndreyPavlenko/Fermata/blob/master/fermata/src/auto/java/me/aap/fermata/auto/MirrorServiceFS.java): lấy Surface qua Car App Library; NavigationTemplate có Action.PAN. onClick đưa tọa độ sang MirrorDisplay.
- [MirrorDisplay](https://github.com/AndreyPavlenko/Fermata/blob/master/fermata/src/auto/java/me/aap/fermata/auto/MirrorDisplay.java): MediaProjection tạo VirtualDisplay xuất ảnh điện thoại lên Surface xe; giữ thức và đổi cấu hình màn hình, nhiều nhánh điều khiển không phù hợp với ràng buộc của dự án.
- [Manifest auto](https://github.com/AndreyPavlenko/Fermata/blob/master/fermata/src/auto/AndroidManifest.xml): NAVIGATION, quyền Surface, minCarApi 5; có thêm nhiều quyền và tích hợp không mang sang đây.
- [Workflow APK](https://github.com/AndreyPavlenko/Fermata/blob/master/.github/workflows/build-apk.yml): JDK 17, secrets keystore, build ABI và artifacts 30 ngày.

Chỉ học mô hình service/surface và cách tổ chức CI. Mã mới dùng FlutterEngineGroup, Presentation và FlutterTextureView; không yêu cầu root, Xposed, Accessibility, overlay hay MediaProjection ở spike đầu tiên. Hai entrypoint dùng chung native diagnostics + EventChannel; chưa có cơ sở dữ liệu tính năng ở GĐ0.

## Tài liệu chính thức đã kiểm tra

- [SurfaceCallback](https://developer.android.com/reference/androidx/car/app/SurfaceCallback)
- [Tương tác bản đồ](https://developer.android.com/training/cars/apps/library/interact-map): chạm cần API 5; phải có Action.PAN; map action strip tối đa 4 icon. Spike chỉ có Home và PAN, chưa đưa thêm các icon của GĐ1.
- [FlutterView](https://api.flutter.dev/javadoc/io/flutter/embedding/android/FlutterView.html): texture hỗ trợ composite view, cần kiểm tra hiệu năng thực tế.
- [FlutterEngineGroup](https://api.flutter.dev/javadoc/io/flutter/embedding/engine/FlutterEngineGroup.html)
- [DisplayManager](https://developer.android.com/reference/android/hardware/display/DisplayManager)
- [Flutter 3.47.1 engine ref](https://github.com/flutter/flutter/blob/3.47.1/bin/internal/engine.version): xác minh ref tồn tại trước khi ghim SDK. Không khẳng định đây là bản stable mới nhất.

## Điều chưa chứng minh

Presentation trên virtual display xuất được Flutter texture, host cho hiển thị app sideload, chữ Việt, tọa độ chạm, reconnect và >=20 FPS đều cần thử VF e34 thật. Không suy ra hoạt động chỉ từ APK build thành công. FPS trong app đếm FrameTiming hoàn tất trong cửa sổ 5 giây khi animation chủ động ~30Hz; không đo được khung thực sự quét trên màn xe.

GĐ0 chỉ chuyển tiếp khi: CI xanh, khóa ký ổn định, APK ký trên Releases và Thanh xác nhận trên xe. Nếu đen/giật/mất chạm thì dùng nhật ký để quyết định triển khai MediaProjection; chưa có phương án dự phòng hoạt động trong phiên bản này. Kéo/vuốt/chụm được hoãn sang giai đoạn bố cục/bản đồ; spike này chỉ chứng minh chạm.

HostValidator đang ALLOW_ALL_HOSTS để thử cài ngoài cho cá nhân. Không phải cấu hình phát hành Google Play. Không xin GPS, thông báo, media vì GĐ0 chưa cần chúng. Không lưu QR hoặc dữ liệu từ ảnh QR người dùng gửi trong giai đoạn này.
