# Media và YouTube · v0.6.0

Thanh chỉ đạo tiếp GĐ6 sau bản v0.5.1 “tạm ổn”. [Danh sách tiến độ](PROGRESS.md) giữ riêng các tiêu chí chưa đo trên xe.

## API và quyết định kỹ thuật

- [MediaSessionManager](https://developer.android.com/reference/android/media/session/MediaSessionManager#getActiveSessions(android.content.ComponentName)): dùng NotificationListener đã được người dùng cấp quyền để lấy active sessions và TransportControls. Không xin quyền đặc biệt MEDIA_CONTENT_CONTROL, root hoặc Accessibility. Listener không đọc hay chuyển tiếp nội dung thông báo. Metadata/ảnh bìa lấy trực tiếp từ phiên media, không tải URI ảnh tùy ý.
- [Media3 phát nền](https://developer.android.com/media/media3/session/background-playback), [Media3 1.11.1](https://developer.android.com/jetpack/androidx/releases/media3): ExoPlayer/MediaSession nằm trong một MediaSessionService dùng chung cho cả hai UI. Có foreground media notification, audio focus, becoming-noisy và wake mode khi phát mạng. Điều khiển trước/phát-dừng/sau chuyển vào hàng đợi riêng. Lời dẫn đường dùng audio focus navigation hiện có.
- Đặc tả gợi ý just_audio/audio_service. Chọn Media3 native ở đây để giữ **một** player/queue qua nhiều FlutterEngine và kết hợp Surface trên VirtualDisplay. Không đưa hai player vào hai engine. Service sở hữu một engine resolver headless; đóng service thì giải phóng resolver/player/session.
- [Flutter SurfaceProducer](https://docs.flutter.dev/release/breaking-changes/android-surface-plugins) và [callback](https://api.flutter.dev/javadoc/io/flutter/view/TextureRegistry.SurfaceProducer.Callback.html): video vào Flutter Texture qua SurfaceProducer, không thêm PlatformView. Gỡ Surface khi cleanup/đổi owner và cập nhật khi có Surface mới. Texture có lease riêng, phản hồi cũ không được giải phóng texture của màn hình mới. Nếu AA kết nối, quyền hiển thị hình thuộc UI xe.

## Lấy luồng và giới hạn đã biết

- Chọn [youtube_explode_dart 3.1.0](https://github.com/Hexer10/youtube_explode_dart/tree/3.1.0) (BSD-3-Clause; giấy phép đóng trong APK). Interface YoutubeStreamProvider để thay provider khi YouTube thay đổi. Thử client Android SDKless rồi Android VR, mỗi lần có timeout và đóng HTTP client, hủy kết quả khi đổi bài. Không dùng solver Deno/Node ở Android. [README chính thức](https://github.com/Hexer10/youtube_explode_dart#using-a-signature-solver) nói rõ một số client cần JavaScript runtime.
- Đã kiểm tra [NewPipeExtractor LICENSE](https://github.com/TeamNewPipe/NewPipeExtractor/blob/dev/LICENSE), GPL-3.0. Chưa tích hợp NewPipe, không sao chép mã Fermata và không quảng cáo có fallback NewPipe đang hoạt động.
- Chọn audio progressive, ưu tiên MP4; video AVC tối đa 1280×720, ghép audio/video bằng MergingMediaSource. Mặc định không chọn/giải mã video. Nếu video lỗi, thử tiếp tục audio; lỗi luồng cho phép làm mới một lần và giữ vị trí. Không cài IMA/ad SDK, không nhúng WebView và không tải video về tệp.
- Chỉ hỗ trợ nội dung công khai truy cập được từ mạng đang dùng. Chưa hỗ trợ đăng nhập, nội dung riêng tư/giới hạn tuổi/DRM, livestream HLS hoặc tải offline. Link hết hạn không lưu lại; video có thể không cung cấp luồng phù hợp. Việc lấy luồng có thể bị YouTube chặn/thay đổi và có rủi ro điều khoản như đặc tả đã nêu.
- Probe CI dùng video công khai Big Buck Bunny của Blender Foundation. Kết quả lấy luồng từ IP máy chủ **không thay** thử trên mạng điện thoại. Chưa thể khẳng định đạt playlist 30 phút chỉ từ unit tests.

## Vị trí, dữ liệu riêng và vòng đời

Native MediaPolicy yêu cầu GPS đang chạy, age monotonic 0–10 giây, accuracy ≤30 m, có tốc độ hợp lệ và dưới 5 km/h. Trên/ngang 5 km/h, GPS cũ hoặc tắt GPS thì bỏ yêu cầu video, tắt video track và gỡ Surface, giữ audio. UI cũng không dựng Texture trong các trạng thái này. Sau khi dừng cần bấm bật video lại; không tự hiện hình trở lại. Ngắt AA vẫn giữ quy tắc GPS cũ: location service dừng và video bị khóa.

Hàng đợi tối đa 200 bài, 60 danh sách và 40 bài gần đây, lưu metadata trong SharedPreferences riêng, tổng thư viện bị chặn 2 MiB. Không tự tải toàn playlist vô hạn. Query tìm kiếm, metadata và stream được gửi trực tiếp đến YouTube/Googlevideo theo thao tác. Không đưa thư viện, tên bài, query, ảnh bìa hay signed URL vào Diagnostics, nhật ký kỹ thuật, gói đường hoặc repo. Ảnh bìa external được thu nhỏ trước khi đưa qua channel. Các tick tiến trình không phát lại toàn thư viện. Đồng hồ “thời gian phát thực” chỉ cộng lúc native player đang phát; dùng để hỗ trợ thử 30 phút, không phải chứng nhận chất lượng âm thanh.

## Thử trên VF e34 / Redmi Android 13

1. Cài đè APK. Mở Nhạc và YouTube → nguồn app nhạc. Bật Truy cập thông báo cho Taxi Xanh; nếu Android chặn APK cài ngoài, cho phép cài đặt bị hạn chế trong Thông tin ứng dụng. Mở app nhạc và phát một bài; kiểm tra tên/bìa, trước/phát-dừng/sau và tiến trình.
2. Trên điện thoại tìm hoặc dán link video/playlist công khai, lưu và phát thử bằng mạng Wi-Fi/di động. Kết nối AA, mở icon YouTube; chỉ chọn danh sách đã lưu/yêu thích/gần đây. Cột bản đồ vẫn hiện.
3. Phát danh sách tổng trên 30 phút, tắt màn hình điện thoại; kiểm tra tự sang bài, điều khiển trên xe và tiếng dẫn đường/ducking. Ghi lại đồng hồ phát thực và bài nào lỗi, không gửi signed URL.
4. Khi đỗ, bật GPS chính xác và chờ có tốc độ hợp lệ; bấm Xem video khi đỗ. Kiểm tra video tự ẩn khi xe vượt 5 km/h, tắt GPS hoặc ngắt AA; âm thanh vẫn hoạt động. Dừng lại không tự bật hình. Kiểm tra lại Theo xe, QR và lịch.

Không đánh dấu các bước này đạt khi chưa có thử xe thật.
