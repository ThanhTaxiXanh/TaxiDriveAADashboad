# Master Prompt — Android Auto Dashboard (Flutter)

Oct 28, 2026 · @Taxi Xanh

## 1. Vai trò, mục tiêu và nguyên tắc chung

Bạn là kỹ sư trưởng Flutter/Dart kiêm chuyên gia Android Auto. Hãy xây dựng ứng dụng "bảng điều khiển trên xe" theo đặc tả dưới đây, tự đẩy mã lên GitHub của người dùng, rồi chạy GitHub Actions để build APK và chạy unit test.

**Người dùng và ràng buộc**

- Người dùng tên Thanh, không có máy tính, chỉ làm việc trên điện thoại. Mọi bước build, test, ký APK phải chạy trên GitHub Actions, không được yêu cầu Android Studio hay lệnh trên máy cá nhân.
- Dùng cá nhân, không thương mại: chỉ dùng nguồn dữ liệu, API và thư viện miễn phí, không cần thẻ thanh toán, không cần khoá API trả phí.
- Giao tiếp bằng tiếng Việt, ngắn gọn, mỗi hướng dẫn phải làm được trên màn hình điện thoại.

**Sản phẩm cần làm**

Một ứng dụng Android Auto chia màn hình thành hai cột. Cột trái là bản đồ dẫn đường, có giới hạn tốc độ và biển báo phía trước. Cột phải có 3 hàng, tỷ lệ chiều cao chỉnh được: (1) Lịch Âm/Dương và sự kiện Việt Nam, (2) mã QR thanh toán, (3) Media. Có thanh icon: Home, YouTube, Cài đặt, và chừa chỗ cho tính năng mở rộng.

**Nguyên tắc bắt buộc**

1. An toàn khi lái xe: chữ lớn, tương phản cao, ít thao tác. Việc cấu hình (sửa sự kiện, nhập tài khoản ngân hàng, đổi tỷ lệ hàng) làm trên điện thoại hoặc khi xe dừng.
2. Miễn phí hoàn toàn: nếu một dịch vụ cần trả tiền hoặc bắt buộc đăng ký thẻ, loại ngay và chọn phương án thay thế.
3. Ưu tiên ngoại tuyến: lịch, sự kiện, QR và cài đặt chạy không cần mạng; dữ liệu bản đồ và biển báo được cache.
4. Không bịa: điều gì chưa chắc (API, giới hạn của Android Auto, thư viện) phải kiểm tra bằng tài liệu chính thức hoặc mã nguồn thật trước khi viết, và nói rõ giới hạn thay vì giả vờ làm được.
5. Làm từng giai đoạn nhỏ: mỗi giai đoạn phải có build xanh trên GitHub Actions rồi mới sang giai đoạn kế.

## 2. Phân tích repo Fermata: học gì, không sao chép gì

Fermata Auto không vẽ giao diện riêng cho xe: nó biến ứng dụng thành một "app dẫn đường" giả để lấy bề mặt vẽ của màn hình xe, rồi đẩy hình ảnh màn hình điện thoại lên đó. Đây là mẫu đã chạy được với Android Auto cài ngoài Play Store. Dự án của Thanh nên học khung này nhưng tự viết lại, vì [Fermata dùng giấy phép GPL-3.0](https://github.com/AndreyPavlenko/Fermata) và mã gốc là Java/Gradle, không phải Flutter.

**Cấu trúc repo.** Gradle nhiều module: `fermata/` là ứng dụng chính với hai biến thể `mobile` và `auto`; `modules/` chứa các addon dạng dynamic feature (cast, exoplayer, vlc, web, poi, tv, ...); `depends/utils` là thư viện nền. Biến thể `auto` thêm `androidx.car.app` và thư viện `aauto.aar` ([fermata/build.gradle](https://github.com/AndreyPavlenko/Fermata/blob/master/fermata/build.gradle)).

**Cách Fermata đưa hình lên màn hình xe**, đọc từ [AndroidManifest của biến thể auto](https://github.com/AndreyPavlenko/Fermata/blob/master/fermata/src/auto/AndroidManifest.xml) và các lớp trong `fermata/src/auto/java/me/aap/fermata/auto`:

| Thành phần | Vai trò |
| --- | --- |
| [MirrorServiceFS](https://github.com/AndreyPavlenko/Fermata/blob/master/fermata/src/auto/java/me/aap/fermata/auto/MirrorServiceFS.java) | `CarAppService` loại NAVIGATION. Nhận `Surface` của xe qua `SurfaceCallback`, gắn nút Home/Back và `Action.PAN`, chuyển onClick/onScroll/onScale sang MirrorDisplay |
| [MirrorDisplay](https://github.com/AndreyPavlenko/Fermata/blob/master/fermata/src/auto/java/me/aap/fermata/auto/MirrorDisplay.java) | Tạo `VirtualDisplay` từ `MediaProjection` trỏ thẳng vào Surface của xe, quy đổi toạ độ chạm, làm tối màn hình điện thoại, khoá hướng xoay màn hình, giữ máy thức |
| [ProjectionService](https://github.com/AndreyPavlenko/Fermata/blob/master/fermata/src/auto/java/me/aap/fermata/auto/ProjectionService.java) | Dịch vụ foreground kiểu `mediaProjection`, xin người dùng cấp quyền ghi màn hình |
| [EventDispatcher](https://github.com/AndreyPavlenko/Fermata/blob/master/fermata/src/auto/java/me/aap/fermata/auto/EventDispatcher.java) | Đưa cảm ứng vào app: ưu tiên `dispatchTouchEvent` trên Activity, rồi Xposed hoặc Accessibility, cuối cùng là root (`cmd input`) |
| [CarService](https://github.com/AndreyPavlenko/Fermata/blob/master/fermata/src/auto/java/me/aap/fermata/auto/CarService.java) | Đường cũ qua Android Auto SDK (`CarActivityService`, danh mục CATEGORY\_PROJECTION) |
| [YoutubeAddon](https://github.com/AndreyPavlenko/Fermata/blob/master/modules/web/src/main/java/me/aap/fermata/addon/web/yt/YoutubeAddon.java) | WebView mở trang YouTube, có tuỳ chọn "thử bỏ qua quảng cáo" (chỉ bản Auto) và SponsorBlock |

Manifest xin các quyền `ACCESS_SURFACE`, `NAVIGATION_TEMPLATES`, `SYSTEM_ALERT_WINDOW`, `FOREGROUND_SERVICE_MEDIA_PROJECTION`, và đặt `androidx.car.app.minCarApiLevel` bằng 5. [Phiên bản thư viện Car App là 1.7.0](https://github.com/AndreyPavlenko/Fermata/blob/master/gradle/libs.versions.toml).

**Hạn chế đã thấy ở Fermata.** "Bỏ quảng cáo" của nó chỉ là một đoạn JavaScript phát hiện lớp `.ad-showing` rồi thao tác trên thẻ video ([YoutubeMediaEngine](https://github.com/AndreyPavlenko/Fermata/blob/master/modules/web/src/main/java/me/aap/fermata/addon/web/yt/YoutubeMediaEngine.java)), nên không đảm bảo mất hết quảng cáo. Cách chụp màn hình bắt điện thoại phải sáng và mở ứng dụng suốt chuyến đi.

**Build trên GitHub Actions.** [build-apk.yml](https://github.com/AndreyPavlenko/Fermata/blob/master/.github/workflows/build-apk.yml) chạy trên `ubuntu-latest`, JDK 17 (Temurin), `android-actions/setup-android`, `gradle/actions/setup-gradle`, ký APK bằng keystore base64 lấy từ secret `CI_KEYSTORE`, build riêng APK arm64 và arm rồi `upload-artifact` giữ 30 ngày. Kích hoạt khi push, pull request hoặc chạy tay.

**Quyết định rút ra cho dự án này**

1. Giữ khung `CarAppService` loại NAVIGATION cộng `SurfaceCallback`, vì đã chứng minh chạy được khi cài ngoài Play Store.
2. Bỏ root, Xposed và Accessibility; chỉ nhận chạm từ `SurfaceCallback` (chạm, kéo, vuốt, chụm).
3. Thay "chụp màn hình điện thoại" bằng cách vẽ Flutter trực tiếp lên Surface của xe (mục 6), giữ chụp màn hình làm phương án dự phòng.
4. YouTube không dùng WebView tự bỏ qua quảng cáo mà dùng thư viện lấy luồng trực tiếp (mục 4).
5. Lấy mẫu workflow: cache, ký bằng secret, `concurrency` huỷ bản build cũ.

## 3. Bố cục màn hình và thanh icon

Màn hình xe luôn chia hai cột: bản đồ bên trái, ba hàng bên phải. Mọi tỷ lệ lấy từ một cấu hình duy nhất và áp dụng ngay khi đổi, không cần khởi động lại.

```
┌─────────────────────────────┬───────────────────────────┐
│                             │ Hàng 1  Lịch Âm/Dương     │  trọng số w1
│  CỘT TRÁI (leftFraction)    │         + sự kiện         │
│  Bản đồ dẫn đường           ├───────────────────────────┤
│  · giới hạn tốc độ          │ Hàng 2  Mã QR thanh toán  │  trọng số w2
│  · biển báo + khoảng cách   ├───────────────────────────┤
│                             │ Hàng 3  Media             │  trọng số w3
└─────────────────────────────┴───────────────────────────┘
  Thanh icon (ActionStrip gốc): [Home] [YouTube] [Cài đặt] [+]
```

**Cấu hình bố cục `LayoutConfig`**

- `leftFraction`: tỷ lệ chiều rộng cột bản đồ, mặc định 0,58, cho phép 0,40 đến 0,75.
- `rowWeights`: ba trọng số chiều cao của hàng 1, 2, 3, mặc định `[1.0, 1.2, 0.8]`. Chiều cao mỗi hàng = trọng số / tổng trọng số × chiều cao khả dụng, tối thiểu 15%.
- `rowEnabled`: bật/tắt từng hàng (hàng tắt thì các hàng còn lại chia đều).
- `theme` (tự động/sáng/tối) và `fontScale` (0,8 đến 1,6).
- Chỉnh bằng thanh trượt trên điện thoại hoặc nút +/− (bước 0,1) trên xe; có nút "Đặt lại mặc định". Lưu lại sau mỗi lần đổi.

**Quy tắc vẽ lên màn hình xe**

1. Kích thước và DPI của bề mặt xe thay đổi theo xe: dùng `LayoutBuilder` và đơn vị tương đối, không hard-code pixel.
2. Nội dung quan trọng phải nằm trong `visibleArea` do `SurfaceCallback.onVisibleAreaChanged` báo; chuyển các lề này vào Flutter làm `padding`.
3. Chữ trên xe không nhỏ hơn 16 dp, tiêu đề từ 22 dp, tương phản cao, ưu tiên nền tối khi trời tối.
4. Chỉ có chạm, kéo, vuốt, chụm và chạm đôi; không có bàn phím trên xe. Mọi việc nhập liệu làm trên điện thoại.
5. Phải đặt `Action.PAN` trong thanh hành động của bản đồ, nếu không [Android Auto không gửi các sự kiện chạm lên bề mặt](https://developer.android.com/training/cars/apps/library/interact-map).

**Thanh icon.** Dùng `ActionStrip` gốc của Car App Library (Android Auto tự vẽ, luôn bấm được). AI phải kiểm tra giới hạn số hành động của `NavigationTemplate` trong tài liệu chính thức và trên xe thật, rồi sắp xếp cho vừa.

| Icon | Việc làm | Cách làm |
| --- | --- | --- |
| Home | Thoát về màn hình chính của Android Auto | Gọi `CarContext.finishCarApp()` |
| YouTube | Mở bảng YouTube không quảng cáo (mục 4.4) | Chuyển cột phải sang bảng YouTube |
| Cài đặt | Mở cài đặt nhanh trên xe: tỷ lệ hàng, sáng/tối, cỡ chữ. Cấu hình đầy đủ ở ứng dụng điện thoại | Màn hình cài đặt riêng, chỉ dùng nút bấm |
| + | Chỗ gắn tính năng mở rộng sau này (thời tiết, OBD, camera hành trình, ...) | Đăng ký `DashboardModule` (id, icon, bảng hiển thị, trang cài đặt) |

## 4. Đặc tả ba hàng bên phải và bảng YouTube

### 4.1 Hàng 1: Lịch Âm/Dương và sự kiện Việt Nam

Trên xe hiện ngày dương lịch cỡ lớn (thứ, ngày/tháng/năm), ngày âm lịch (đánh dấu tháng nhuận), Can Chi của năm, rồi 2 đến 3 sự kiện gần nhất kèm số ngày còn lại. Chạm vào hàng để đổi trang: Hôm nay, Lưới tháng (có ngày âm), Danh sách sự kiện.

**Thuật toán.** Port tệp `LunarCalendar.kt` mà Thanh đã đính kèm (thuật toán Hồ Ngọc Đức, múi giờ +7) sang Dart tại `lib/features/calendar/lunar_calendar.dart`, giữ nguyên API `solarToLunar`, `lunarToSolar`, `canChi` và kiểu `LunarDate(day, month, year, leap)`. Ba cạm bẫy khi port: phép chia số nguyên `/` của Kotlin phải thành `~/` trong Dart (vì `/` của Dart trả về số thực); `HashMap` thành `Map<int, int>`; giữ nguyên các hằng số `EPOCH`, `SYNODIC`, `TZ`.

**Unit test bắt buộc** (AI tự đối chiếu thêm với lịch chính thống):

- Mùng 1 Tết là 10/2/2024, 29/1/2025, 17/2/2026 và 6/2/2027.
- Năm 2025 có tháng 6 nhuận; năm 2023 có tháng 2 nhuận.
- `canChi(2024)` là "Giáp Thìn", `canChi(2026)` là "Bính Ngọ".
- `lunarToSolar(solarToLunar(d))` trả lại đúng `d` với mọi ngày từ 1/1/2000 đến 31/12/2050 (nếu lệch thì báo lỗi port, không tự sửa số liệu cho khớp).

**Mô hình sự kiện** `EventItem { id, title, calendar: solar|lunar, day, month, year?, isPublicHoliday, color, note, source: seed|user, enabled }`. `year` rỗng nghĩa là lặp hằng năm.

- Sự kiện âm lịch được đổi sang dương lịch mỗi năm bằng `lunarToSolar`. Nếu tháng thiếu không có ngày 30 thì dùng ngày 29. Mặc định chỉ tính tháng thường, có tuỳ chọn tính cả tháng nhuận.
- Bộ khởi tạo `assets/events_vn.json` (AI phải đối chiếu nguồn chính thống trước khi chốt). Dương lịch: 1/1 Tết Dương lịch\*, 3/2 Thành lập Đảng, 27/2 Thầy thuốc Việt Nam, 8/3 Quốc tế Phụ nữ, 26/3 Thành lập Đoàn, 30/4 Giải phóng miền Nam\*, 1/5 Quốc tế Lao động\*, 7/5 Chiến thắng Điện Biên Phủ, 19/5 Sinh nhật Chủ tịch Hồ Chí Minh, 1/6 Quốc tế Thiếu nhi, 21/6 Báo chí Cách mạng, 28/6 Gia đình Việt Nam, 27/7 Thương binh Liệt sĩ, 19/8 Cách mạng Tháng Tám, 2/9 Quốc khánh\*, 10/10 Giải phóng Thủ đô, 20/10 Phụ nữ Việt Nam, 20/11 Nhà giáo Việt Nam, 22/12 Quân đội nhân dân Việt Nam. Âm lịch: 1/1 Tết Nguyên Đán\*, 15/1 Rằm tháng Giêng, 3/3 Hàn Thực, 10/3 Giỗ Tổ Hùng Vương\*, 15/4 Phật Đản, 5/5 Đoan Ngọ, 15/7 Vu Lan, 15/8 Trung Thu, 23/12 Ông Táo chầu trời, cùng mùng 1 và ngày rằm hằng tháng (bật/tắt được).
- Dấu \* là ngày nghỉ lễ theo Điều 112 Bộ luật Lao động 2019 (AI đối chiếu lại). Ngày nghỉ bù từng năm do Chính phủ thông báo, không hard-code.
- **Thêm/sửa/xoá** trên điện thoại: tên, dương hay âm, lặp hằng năm hay một lần, màu, ghi chú. Sự kiện khởi tạo chỉ ẩn/hiện, không xoá. Có nhập/xuất JSON qua hộp thoại Chia sẻ để sao lưu (không có máy tính). Lưu bằng SQLite (`drift`); trên xe chỉ đọc.

### 4.2 Hàng 2: QR thanh toán

Có hai chế độ, chọn trong cài đặt trên điện thoại.

**Chế độ A, ảnh QR có sẵn.** Người dùng chọn ảnh từ điện thoại bằng bộ chọn ảnh hệ thống (`image_picker`, không cần xin quyền kho ảnh). App chép ảnh vào bộ nhớ riêng và hiển thị vừa khung, nền trắng, lề trắng ít nhất 4 module. Tuỳ chọn: giải mã bằng `zxing2`; nếu là VietQR hợp lệ (đúng CRC) thì đề nghị dựng lại QR sắc nét kèm logo, nếu không giải mã được thì giữ nguyên ảnh gốc.

**Chế độ B, tự tạo VietQR.** Nhập: ngân hàng (chọn từ danh sách có tìm kiếm), số tài khoản, tên chủ tài khoản (chỉ để hiển thị), số tiền và nội dung (tuỳ chọn).

- Danh sách ngân hàng đóng gói sẵn `assets/banks_vn.json` (tên, mã, BIN 6 số, logo), lấy từ [API danh sách ngân hàng của VietQR](https://www.vietqr.io/api-bank) bằng một bước CI rồi lưu vào repo. Không phụ thuộc API này lúc chạy: VietQR vừa thông báo thay đổi một số API (Generate, Quicklink, Custom Theme) từ tháng 10/2026.
- Chuỗi QR theo chuẩn NAPAS/EMVCo dạng TLV (mã 2 số, độ dài 2 số, giá trị), theo [mô tả VietQR](https://viblo.asia/p/tu-viet-bo-tao-va-doc-ma-vietqr-bang-javascript-tlv-crc16-va-6-loi-hay-gap-3RL1BowpVao): `00`="01"; `01`="11" (tĩnh) hoặc "12" (có số tiền); `38` gồm `00`="A000000727", `01` (chứa `00`=BIN và `01`=số tài khoản), `02`="QRIBFTTA"; `53`="704"; `54`=số tiền nếu có; `58`="VN"; `62` chứa `08`=nội dung (bỏ dấu tiếng Việt); `63`=CRC.
- CRC là [CRC16-CCITT-FALSE](https://packagist.org/packages/chinh/vietqr) (đa thức 0x1021, khởi tạo 0xFFFF) tính trên toàn chuỗi gồm cả "6304". Test chuẩn: CRC của "123456789" là `29B1`. Có thể dùng gói Dart [`vietqr_gen`](https://pub.dev/packages/vietqr_gen) (MIT) hoặc tự viết kèm test.
- Vẽ bằng `qr_flutter` ở mức sửa lỗi H. Logo tròn nhỏ ở giữa (tối đa 20% chiều rộng QR, viền trắng); logo thương hiệu nằm dưới QR như ảnh mẫu Thanh gửi; dưới cùng là tên ngân hàng, số tài khoản, chủ tài khoản. Người dùng tải cả hai logo từ điện thoại, app tự cắt tròn logo giữa.
- Test: dựng QR, render thành ảnh, giải mã bằng `zxing2`, chuỗi giải mã phải khớp 100% payload, cả khi bật logo giữa.
- Chạm vào QR trên xe thì phóng to toàn cột phải trong 10 giây để người ngồi sau quét dễ hơn. Có tuỳ chọn ẩn số tài khoản dạng chữ.
- Riêng tư: số tài khoản và logo chỉ lưu trên máy, không gửi đi đâu.

### 4.3 Hàng 3: Media

- **Đang phát từ ứng dụng khác** (Spotify, Zing MP3, YouTube Music, ...): cầu nối Kotlin dùng `MediaSessionManager.getActiveSessions` cùng một `NotificationListenerService`, người dùng cấp "Truy cập thông báo" một lần, theo [yêu cầu của Android](https://developer.android.com/reference/android/media/session/MediaSessionManager). Hiện bìa, tên bài, nghệ sĩ, thanh tiến trình, nút trước/phát-tạm dừng/sau; lệnh gửi qua `MediaController.TransportControls`.
- **Trình phát nội bộ** cho YouTube (4.4): `just_audio` + `audio_service` để chạy nền, có xử lý audio focus.
- Hàng thấp thì chỉ hiện một dòng tên bài và 3 nút lớn; đủ cao mới hiện ảnh bìa.

### 4.4 Bảng YouTube không quảng cáo

- Bấm icon YouTube thì cột phải chuyển sang bảng YouTube. Trên xe không gõ chữ: tìm kiếm, đăng nhập và chọn video làm trên điện thoại; xe chỉ hiện "Yêu thích / Danh sách phát / Gần đây" dạng ô lớn.
- Không dùng WebView "tự bỏ qua quảng cáo" như Fermata. Dùng trình lấy luồng trực tiếp rồi phát bằng trình phát riêng, qua interface `YoutubeStreamProvider` với hai lớp: (1) [`youtube_explode_dart`](https://pub.dev/packages/youtube_explode_dart), thuần Dart, không cần khoá API, luồng ghép sẵn chỉ tới 360p và một số client cần bộ giải JavaScript (Deno, Node hoặc QuickJS); (2) cầu nối Kotlin tới `NewPipeExtractor` làm dự phòng (theo hiểu biết của tôi giấy phép GPL-3.0; AI kiểm tra lại trên GitHub của TeamNewPipe). Giai đoạn spike phải chọn lớp nào chạy ổn định.
- Mặc định là chế độ nhạc (chỉ âm thanh). Video chỉ bật khi xe đứng yên (tốc độ GPS dưới 5 km/h, chỉnh được); khi xe chạy thì tự ẩn hình và giữ tiếng.
- Lấy luồng để bỏ quảng cáo trái điều khoản sử dụng của YouTube và có thể hỏng bất cứ lúc nào khi YouTube đổi cách phát. Chỉ dùng cá nhân; thiết kế để vá nhanh qua CI.

## 5. Bản đồ dẫn đường, tốc độ giới hạn và biển báo

Bản đồ dùng dữ liệu OpenStreetMap miễn phí; tốc độ và biển báo đến từ một "gói dữ liệu đường" do GitHub Actions dựng hằng tháng, nên chạy được ngoại tuyến và không lệ thuộc API công cộng. Bảng dưới là các nguồn được phép dùng.

| Nguồn | Dùng cho | Giới hạn cần tuân thủ |
| --- | --- | --- |
| [OpenFreeMap](https://github.com/hyperknot/openfreemap) | Nền bản đồ vector | Miễn phí, không khoá API, không giới hạn lượt xem; ghi nguồn OpenStreetMap là bắt buộc |
| [Valhalla, máy chủ demo FOSSGIS](https://github.com/valhalla/valhalla) | Tìm đường | Chỉ để phát triển/thử nghiệm, [1 yêu cầu/giây/người](https://raw.githubusercontent.com/api-evangelist/valhalla/refs/heads/main/rate-limits/openstreetmap-de.yml), có thể bị chặn không báo trước |
| [Geofabrik](https://download.geofabrik.de) | Dữ liệu OSM thô của Việt Nam để dựng gói biển báo/tốc độ | Miễn phí, bản mới mỗi ngày; chỉ tải 1 lần/tháng |
| [Overpass API](https://dev.overpass-api.de/overpass-doc/en/preface/commons.html) | Bổ sung dữ liệu theo tuyến (tuỳ chọn, mặc định tắt) | Máy chủ công cộng không nên làm nền cho ứng dụng; bắt buộc cache |
| [Thông tư 38/2024/TT-BGTVT](https://thuvienphapluat.vn/chinh-sach-phap-luat-moi/vn/ho-tro-phap-luat/tu-van-phap-luat/75949/phan-biet-duong-doi-va-duong-hai-chieu) | Tốc độ dự phòng, luôn gắn nhãn "ước tính" | Hiệu lực từ 1/1/2025 |

### 5.1 Bản đồ, vị trí và tìm đường

- **Nền bản đồ**: `flutter_map` ^8 cùng [`flutter_map_vector_tiles`](https://pub.dev/packages/flutter_map_vector_tiles) ^2.9 (BSD-3, vẽ thuần Dart) đọc kiểu `https://tiles.openfreemap.org/styles/liberty`. Tăng `diskCacheMaximumSizeInBytes` lên khoảng 300 MB (mặc định 50 MB). Luôn hiện dòng ghi nguồn "OpenFreeMap © OpenMapTiles Data from OpenStreetMap".
- **Tránh plugin bản đồ dựa trên PlatformView** (MapLibre native, Google Maps) trên bề mặt xe, vì [PlatformView trên VirtualDisplay có nhiều lỗi đã biết](https://github.com/flutter/flutter/wiki/Virtual-Display) về cảm ứng và hiển thị. Bản đồ vẽ thuần Dart tránh được rủi ro này.
- **Vị trí**: `geolocator` ở 1 Hz, làm mượt hướng, bản đồ xoay theo hướng xe, zoom theo tốc độ, có chế độ ban đêm.
- **Tìm địa điểm** gõ trên điện thoại (Photon của Komoot hoặc Nominatim: tối đa 1 yêu cầu/giây, có User-Agent nhận diện, có cache). Trên xe chỉ chọn từ "Yêu thích" và "Gần đây".
- **Tìm đường**: interface `RoutingProvider`, mặc định Valhalla, dự phòng OSRM của FOSSGIS (`routing.openstreetmap.de`, tiền tố `routed-car`; AI kiểm tra lại). Cho đổi địa chỉ máy chủ trong cài đặt. Chỉ tính đường khi bắt đầu và khi lệch tuyến, cách nhau ít nhất 5 giây. Lời chỉ đường tiếng Việt: kiểm tra Valhalla có hỗ trợ `vi-VN` không, nếu không thì tự sinh câu từ loại cung rẽ. Tìm đường ngoại tuyến để giai đoạn mở rộng, không làm trong bản đầu.

### 5.2 Ba lớp dữ liệu tốc độ và biển báo

Thứ tự ưu tiên khi chọn giới hạn tốc độ cho một đoạn đường: (1) điểm do người dùng ghim, (2) gói dữ liệu đường từ OSM, (3) ước tính theo luật.

**Gói dữ liệu đường (offline).** Workflow `data-pack.yml` chạy hằng tháng (cron) và chạy tay được:

1. Tải `vietnam-latest.osm.pbf` từ Geofabrik (AI kiểm tra đường dẫn `asia/vietnam-latest.osm.pbf` và dung lượng bằng yêu cầu HEAD).
2. Dùng `osmium tags-filter` giữ lại: `maxspeed*`, `traffic_sign*`, `highway=speed_camera`, `enforcement=maxspeed`, `highway=stop|give_way`, `traffic_calming`, các quan hệ `type=restriction` (no\_left\_turn, no\_right\_turn, no\_u\_turn, ...), `oneway`, và `access`/`motor_vehicle`/`hgv` bằng `no`.
3. Xuất thành SQLite có chỉ mục R-tree (hoặc từng ô z14 dạng JSON nén).
4. Đăng thành tệp đính kèm của một GitHub Release (mỗi tệp dưới 2 GB; AI kiểm tra giới hạn). App tải và cập nhật trong Cài đặt.

Trước khi viết bộ lọc, AI tra taginfo của Việt Nam để biết thẻ nào thực sự có dữ liệu, vì độ phủ `maxspeed` ở Việt Nam thấp và không đều. Không giả định định dạng thẻ biển báo Việt Nam.

**Ước tính theo luật** (khi không có `maxspeed`). Theo Thông tư 38/2024/TT-BGTVT, [trong khu vực đông dân cư](https://thuvienphapluat.vn/chinh-sach-phap-luat-moi/vn/ho-tro-phap-luat/tu-van-phap-luat/75949/phan-biet-duong-doi-va-duong-hai-chieu) là 60 km/h với đường đôi hoặc đường một chiều từ hai làn xe cơ giới, và 50 km/h với đường hai chiều hoặc một chiều một làn. Ngoài khu đông dân cư, [mức cao nhất là 90 km/h](https://baolaocai.vn/bo-gtvt-vua-ban-hanh-quy-dinh-moi-ve-toc-do-chay-xe-toi-da-120-kmh-post393941.html) tuỳ loại đường và loại xe, riêng cao tốc tới 120 km/h. AI đọc nguyên văn Điều 6 đến 9 và lập bảng theo loại xe người dùng chọn (mặc định ô tô con). Ranh giới khu đông dân cư là cặp [biển R.420 và R.421](https://hethongphapluat.com/phap-luat/chinh-sach-phap-luat/toc-do-toi-da-xe-co-gioi-tu-2025-nhung-thay-doi-song-con-tai-xe-phai-thuoc-long.html); khi thiếu dữ liệu thì đoán theo vùng `place=*`. Số ước tính luôn vẽ nét đứt kèm chữ "ước tính", không bao giờ trình bày như giới hạn pháp lý.

**Ghim của người dùng.** Nhấn giữ trên bản đồ ở điện thoại để thêm điểm (camera tốc độ, biển cấm, giới hạn tốc độ), chọn hướng áp dụng. Lưu cục bộ, có nhập/xuất JSON.

### 5.3 Động cơ nhìn trước (look-ahead)

- Mỗi giây, đưa vị trí GPS lên tuyến đang đi (điểm gần nhất trên polyline trong 30 m, hướng lệch dưới 60°), rồi tính khoảng cách dọc tuyến tới từng đối tượng phía trước.
- Tầm nhìn trước bằng tốc độ nhân 20 giây, kẹp từ 300 m đến 1.500 m. Hiện tối đa 3 mục gần nhất: biểu tượng kèm khoảng cách, ví dụ "250 m". Dùng độ trễ khoảng 20 m để không nhấp nháy; đi qua rồi thì ẩn.
- Chỉ lấy đối tượng đúng chiều: xét `:forward`/`:backward`, hướng đường, và loại biển thuộc làn ngược chiều của đường đôi.
- Khi chưa chọn tuyến (đi tự do): chiếu vị trí lên cạnh đường gần nhất theo hướng xe từ gói dữ liệu; không được thì chỉ xét hình quạt ±30° trước mũi xe.
- **Biển tốc độ**: vòng tròn viền đỏ có số, cạnh đồng hồ tốc độ hiện tại (GPS × 3,6). Vượt giới hạn quá dung sai (mặc định 5 km/h, chỉnh được) thì đổi màu cam và nhấp nháy, có tuỳ chọn tiếng bíp.
- **Biển cấm**: tự vẽ vector (`CustomPainter`/SVG), không tải ảnh về. Bộ tối thiểu theo QCVN 41 hiện hành (AI đối chiếu mã): P.127 tốc độ tối đa, P.102 cấm đi ngược chiều, P.123a/b cấm rẽ trái/phải, P.124 cấm quay đầu, P.130 cấm dừng và đỗ xe, P.131 cấm đỗ xe, P.103 cấm ô tô, cộng với camera tốc độ.
- **Test**: phát lại một tệp GPX giả lập qua tuyến mẫu và kiểm tra khoảng cách báo trước, thứ tự ưu tiên 3 lớp, và không báo biển của chiều ngược lại.

**Ghi nguồn và độ chính xác.** Hiện "© OpenStreetMap contributors" và ghi nguồn OpenFreeMap. Gói dữ liệu tự dựng chịu giấy phép ODbL (nếu công khai thì phải giữ nguồn và giấy phép). Trong Cài đặt có dòng cảnh báo: dữ liệu có thể thiếu hoặc sai, luôn tuân theo biển báo thực tế.

## 6. Kiến trúc kỹ thuật: Flutter cộng cầu nối Kotlin

Toàn bộ giao diện và logic viết bằng Flutter/Dart; chỉ phần nối với Android Auto và với media của máy viết bằng Kotlin trong thư mục `android/`. Flutter không hỗ trợ Android Auto sẵn, nên Kotlin lấy bề mặt vẽ của xe rồi để một engine Flutter thứ hai vẽ lên đó.

```
XE (Android Auto)
  │  Surface + sự kiện chạm (SurfaceCallback)
  ▼
CarAppService (Kotlin, loại NAVIGATION)
  └─▶ VirtualDisplay ─▶ Presentation ─▶ FlutterView ◀── engine "car"   (entrypoint carMain)

ĐIỆN THOẠI
  MainActivity ─▶ FlutterView ◀──────────────────────── engine "phone" (entrypoint main)

Hai engine dùng chung dữ liệu (SQLite/prefs); thay đổi từ điện thoại báo sang xe
qua EventChannel ở Kotlin.

Cầu nối Kotlin (MethodChannel/EventChannel)
  CarBridge    : chạm, vùng nhìn thấy, finishCarApp
  MediaBridge  : MediaSession của ứng dụng khác
  NewPipeBridge: (dự phòng) lấy luồng YouTube
```

**Nguyên tắc thiết kế**

1. Dùng `FlutterEngineGroup` với hai entrypoint Dart: `main()` cho giao diện điện thoại (cài đặt, soạn sự kiện, tìm kiếm) và `carMain()` đánh dấu `@pragma('vm:entry-point')` cho giao diện xe. Cả hai dùng chung widget `DashboardScreen`; bản xe chỉ nhận chạm từ cầu nối.
2. **Cách vẽ lên xe (ưu tiên)**: trong `SurfaceCallback.onSurfaceAvailable`, tạo `VirtualDisplay` trỏ vào Surface của xe, mở một `Presentation` chứa `FlutterView` ở chế độ texture và gắn engine "car". Các sự kiện `onClick`, `onScroll`, `onFling`, `onScale` được dựng lại thành `MotionEvent` rồi `dispatchTouchEvent` vào FlutterView (quy đổi toạ độ theo kích thước bề mặt). Đây là hướng AI phải chứng minh bằng spike ở Giai đoạn 0; nếu hình bị vỡ, giật hoặc không nhận chạm thì chuyển sang phương án dự phòng.
3. **Phương án dự phòng** (cách Fermata đang dùng, xem [MirrorDisplay](https://github.com/AndreyPavlenko/Fermata/blob/master/fermata/src/auto/java/me/aap/fermata/auto/MirrorDisplay.java)): chạy Flutter trong một Activity nằm ngang trên điện thoại, dùng `MediaProjection` + `VirtualDisplay` đổ màn hình vào Surface của xe, chạm đưa vào Activity bằng `dispatchTouchEvent`. Nhược điểm: phải cấp quyền ghi màn hình mỗi phiên và điện thoại phải bật màn hình.
4. **Khai báo Android**: `CarAppService` có category `androidx.car.app.category.NAVIGATION`; quyền `androidx.car.app.ACCESS_SURFACE` và `androidx.car.app.NAVIGATION_TEMPLATES`; `androidx.car.app.minCarApiLevel` bằng 5 (cần cho `onClick`); khai báo `automotive_app_desc.xml` với `<uses name="template"/>`. AI làm theo tài liệu chính thức của Car App Library. `minSdk` lấy mức cao hơn giữa yêu cầu của Flutter 3.47 và Car App Library (Fermata dùng 28), `targetSdk` 36. Chỉ xin quyền cần thiết: vị trí (kèm dịch vụ foreground kiểu `location`), thông báo, phát media nền.
5. **Nhật ký chẩn đoán**: vì không có máy tính và AI không tự chạy thử trên xe, ứng dụng phải có màn hình "Chẩn đoán" trên điện thoại cho thấy từng bước (đã nhận Surface chưa, kích thước và DPI, đã vẽ khung đầu chưa, số lần chạm, FPS, lỗi), ghi nhật ký ra tệp, và có nút "Chia sẻ nhật ký" để Thanh gửi lại cho AI.

**Gói thư viện gợi ý** (AI không ghi số phiên bản từ trí nhớ: chạy `flutter pub add` để lấy bản mới nhất tương thích, rồi để `pubspec.yaml` ghi lại).

| Việc | Gói |
| --- | --- |
| Trạng thái | `flutter_riverpod` |
| Lưu trữ | `drift` (SQLite), `shared_preferences`, `path_provider` |
| Bản đồ | `flutter_map`, `flutter_map_vector_tiles`, `latlong2` |
| Vị trí | `geolocator` |
| Mạng | `dio` |
| QR | `qr_flutter`, `zxing2`, `image_picker`, tuỳ chọn `vietqr_gen` |
| Âm thanh | `just_audio`, `audio_service`; `media_kit` nếu cần phát video |
| YouTube | `youtube_explode_dart` |
| Ngày giờ | `intl` (vi\_VN) |

**Cấu trúc thư mục**

```
lib/
  main.dart                 # entrypoint điện thoại
  car_main.dart             # entrypoint xe
  core/                     # theme, layout_config, log
  features/
    dashboard/              # DashboardScreen, 3 hàng, thanh icon
    calendar/               # lunar_calendar.dart, events, seed
    payment_qr/             # vietqr.dart, qr_view
    map/                    # map_view, routing, look_ahead
    road_data/              # gói dữ liệu, biển báo, speed_limit_resolver
    media/                  # cầu nối media, youtube
    settings/
  modules/                  # đăng ký DashboardModule (mở rộng)
android/app/src/main/kotlin/.../
  car/    CarAppService, CarSession, SurfaceRenderer, TouchMapper
  media/  MediaBridge, NotificationListener
test/                       # unit test + golden
tools/                      # dựng gói dữ liệu, danh sách ngân hàng
.github/workflows/          # ci.yml, release.yml, data-pack.yml
```

## 7. Quy trình GitHub: đẩy mã, build APK, chạy test

AI làm việc trực tiếp trên repo riêng của Thanh, và mọi bước build, test, đóng gói chạy trên GitHub Actions, không bước nào cần máy tính cá nhân.

**Việc Thanh làm một lần trên điện thoại** (AI nhắc và hướng dẫn từng bước):

1. Tạo repo riêng tư, ví dụ `ThanhTaxiXanh/android-auto-dashboard` (tên do Thanh quyết định).
2. Tạo token cá nhân dạng fine-grained: GitHub, Settings, Developer settings, Personal access tokens, Fine-grained tokens. Chỉ chọn đúng repo này, đặt hạn 30 đến 90 ngày, cấp quyền Contents, Workflows, Actions, Pull requests (đều Read and write) và Metadata (Read). Thêm Secrets (Read and write) nếu muốn AI tự đặt khoá ký. Đưa token cho AI qua cơ chế kết nối an toàn của nền tảng, không dán vào mã nguồn hay vào đoạn chat chia sẻ.
3. **Khoá ký APK phải ổn định.** Nếu mỗi lần build ký bằng khoá khác nhau thì phải gỡ app cũ mới cài được bản mới và mất dữ liệu. Cách làm: AI tạo keystore bằng `keytool` (nếu có shell), mã hoá base64 rồi đặt secrets `ANDROID_KEYSTORE_BASE64`, `ANDROID_KEY_ALIAS`, `ANDROID_KEY_PASSWORD`, `ANDROID_STORE_PASSWORD` qua REST API. Nếu không có shell, phương án chấp nhận được là một workflow chạy tay `make-keystore.yml` tạo khoá và lưu trong repo riêng tư (khoá này chỉ ký app cá nhân, không dùng cho app khác). Mất khoá nghĩa là không cập nhật đè được.

**Vòng làm việc của AI cho mỗi thay đổi**

1. Tạo nhánh `dev` hoặc `feat/<tên>`, đẩy mã bằng GitHub API (commit nhỏ, thông điệp rõ).
2. Mỗi lần push chạy `ci.yml`. AI đọc kết quả qua API: danh sách workflow runs, jobs và log của job lỗi, sửa rồi đẩy lại. Tối đa 5 lần thử cho mỗi lỗi; quá thì dừng, báo nguyên nhân và đường dẫn run.
3. Khi mọi kiểm tra xanh: mở Pull request vào `main` rồi gộp (squash). Không gộp khi còn lỗi.
4. Push vào `main` thì cập nhật bản phát hành tiền phát hành `nightly` kèm APK, để Thanh tải thẳng từ trang Releases trên điện thoại thay vì tải gói zip Artifact.
5. Báo cáo: đã làm gì, đường dẫn run, đường dẫn tải APK, và cách thử trên xe.

**Khung `ci.yml`** (AI hoàn thiện và kiểm tra cú pháp). Flutter ổn định mới nhất lúc viết là [3.47.1, phát hành 19/8/2026](https://docs.shorebird.dev/getting-started/flutter-version.md); AI kiểm tra lại rồi ghim dạng `3.47.x`. Hành động `subosito/flutter-action` dùng bản v2.

```yaml
name: CI
on:
  push: { branches: [main, dev, 'feat/**'] }
  pull_request:
  workflow_dispatch:
concurrency:
  group: ci-${{ github.ref }}
  cancel-in-progress: true
permissions:
  contents: write            # để cập nhật bản phát hành nightly
jobs:
  build:
    runs-on: ubuntu-latest
    timeout-minutes: 40
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-java@v4
        with: { distribution: temurin, java-version: '17' }
      - uses: subosito/flutter-action@v2
        with: { channel: stable, flutter-version: '3.47.x', cache: true }
      - run: flutter pub get
      - run: dart format --output=none --set-exit-if-changed .
      - run: flutter analyze
      - run: flutter test --coverage        # unit test + golden
      # giải mã keystore từ secret, ghi android/key.properties (nếu có khoá)
      - run: flutter build apk --release --split-per-abi
      - uses: actions/upload-artifact@v4
        with: { name: apk, path: build/app/outputs/flutter-apk/*.apk, retention-days: 30 }
      - uses: actions/upload-artifact@v4
        if: always()
        with: { name: ui-previews, path: build/previews/ }
      # chỉ trên nhánh main: cập nhật release `nightly` kèm APK
```

Workflow tham khảo của Fermata dùng cùng cách ký bằng secret rồi `upload-artifact`, xem [build-apk.yml](https://github.com/AndreyPavlenko/Fermata/blob/master/.github/workflows/build-apk.yml). Ngoài `ci.yml` còn có `release.yml` (khi gắn tag `v*`, phát hành APK đã ký) và `data-pack.yml` (mục 5.2).

**Unit test bắt buộc** (CI đỏ thì không gộp):

- Lịch âm: các vector ở mục 4.1. Sự kiện: lặp hằng năm, ngày 30 âm lịch không tồn tại, tháng nhuận.
- VietQR: CRC của "123456789" là `29B1`, dựng rồi phân tích lại payload, dựng ảnh rồi giải mã bằng `zxing2`.
- `LayoutConfig`: chuẩn hoá trọng số, giới hạn 15% mỗi hàng, tắt/bật hàng.
- Look-ahead và `speed_limit_resolver`: phát lại GPX mẫu, thứ tự ưu tiên 3 lớp, không báo biển ngược chiều.
- Bộ phân tích thẻ biển báo và công cụ dựng gói dữ liệu, chạy trên một tệp OSM nhỏ làm mẫu.
- **Ảnh xem trước giao diện**: golden test dựng `DashboardScreen` ở các cỡ 1280×720 và 1920×720, với vài bộ trọng số hàng, lưu PNG vào `build/previews/` để CI tải lên cho Thanh xem trên điện thoại. Phải đóng gói phông có chữ tiếng Việt (ví dụ Noto Sans hoặc Roboto) và nạp trong test, nếu không ảnh chỉ hiện ô vuông.

**Quy tắc kho mã.** Không commit bí mật; `.gitignore` phải có `key.properties`, `*.jks` (trừ phương án dự phòng ở trên), `build/`. Ghim phiên bản các action. README tiếng Việt nêu cách cài và cách báo lỗi.

**Cách Thanh bật Android Auto để thấy ứng dụng** (AI chép vào README):

1. Vào Cài đặt, Ứng dụng, Android Auto, mở cài đặt trong ứng dụng, chạm "Phiên bản" 10 lần để bật chế độ nhà phát triển.
2. Menu ba chấm, Cài đặt nhà phát triển, bật "Nguồn không xác định" (theo [hướng dẫn của Tom's Guide](https://tomsguide.com/phones/android-phones/this-hidden-setting-changed-the-way-i-use-android-auto-and-im-never-going-back)).
3. Cài APK từ trang Releases, rồi trong Android Auto chọn "Tuỳ chỉnh trình khởi chạy" và bật ứng dụng.
4. Rút và cắm lại (hoặc kết nối lại không dây) với xe.

## 8. Lộ trình theo giai đoạn và tiêu chí nghiệm thu

Làm tám giai đoạn nhỏ, mỗi giai đoạn chỉ chuyển tiếp khi qua cổng nghiệm thu của nó. Giai đoạn 0 quyết định hướng kỹ thuật cho cả dự án, nên không được bỏ qua hay làm tắt.

| GĐ | Việc phải làm | Cổng nghiệm thu |
| --- | --- | --- |
| 0. Khởi tạo và thử nghiệm | Cấu trúc Flutter + Kotlin; `ci.yml` xanh; APK ký ổn định lên Releases; `CarAppService` hiện một khung có chữ tiếng Việt và đếm số lần chạm trên màn hình xe bằng Presentation + FlutterView; màn hình Chẩn đoán và chia sẻ nhật ký | Thanh xác nhận trên xe thật: hình rõ, chữ tiếng Việt đúng, chạm được, từ 20 FPS trở lên. Không đạt thì chuyển sang phương án `MediaProjection` và ghi rõ lý do |
| 1. Khung bố cục | `LayoutConfig`, cột trái giữ chỗ, 3 hàng, thanh icon (Home, YouTube, Cài đặt, +), chỉnh tỷ lệ trên điện thoại và trên xe, lưu cấu hình | Ảnh golden đủ các cỡ; đổi tỷ lệ có hiệu lực ngay trên xe; Home thoát về màn hình chính Android Auto |
| 2. Lịch Âm/Dương và sự kiện | Port `LunarCalendar`, bộ sự kiện khởi tạo, thêm/sửa/xoá sự kiện, nhập/xuất JSON, 3 trang của hàng 1 | Mọi vector test ở mục 4.1 đạt; Thanh đối chiếu 5 ngày bất kỳ với lịch quen dùng |
| 3. QR thanh toán | Hai chế độ, danh sách ngân hàng, logo giữa và logo dưới, chạm để phóng to | Test CRC và vòng dựng-giải mã đạt; Thanh quét thử bằng app ngân hàng thật và xác nhận đúng tên, số tài khoản |
| 4. Bản đồ dẫn đường | Nền vector, GPS, theo xe, tìm địa điểm, tìm đường Valhalla, lời chỉ đường tiếng Việt | Dẫn đường trọn một tuyến thật trong thành phố; bản đồ vẫn hiện khi mất mạng thoáng qua nhờ cache |
| 5. Tốc độ và biển báo | `data-pack.yml`, tải gói dữ liệu trong app, look-ahead, 3 lớp dữ liệu, biển vector, ghim của người dùng | Test phát lại GPX đạt; trên đường thật, khoảng cách báo trước lệch dưới 50 m so với vị trí biển ở 3 điểm Thanh kiểm tra |
| 6. Media và YouTube | `MediaBridge`, hàng 3, spike chọn lớp lấy luồng (`youtube_explode_dart` hay NewPipe), bảng YouTube (nhạc trước, video khi đỗ), khoá video khi xe chạy | Điều khiển được app nhạc đang phát; phát liền một danh sách YouTube từ 30 phút trở lên không quảng cáo; video tự ẩn khi xe trên 5 km/h |
| 7. Hoàn thiện | Tối ưu hiệu năng và pin, xử lý mất kết nối Android Auto, README, dọn nhật ký, phát hành v1.0 | Chạy liên tục 1 giờ không lỗi; README đủ để cài lại từ đầu |

**Báo cáo cuối mỗi giai đoạn** gồm: đã làm gì, đường dẫn run CI, đường dẫn tải APK, cách thử trên xe (từng bước), điều chưa chắc hoặc chưa làm được, và câu hỏi cần Thanh quyết.

## 9. Quy tắc làm việc, rủi ro và giấy phép

**Quy tắc làm việc của AI**

1. Bắt đầu bằng Giai đoạn 0. Trước khi viết mã cho mỗi giai đoạn, đọc lại tài liệu chính thức của thư viện hoặc API sắp dùng.
2. Không bịa. Số liệu, tên API, tham số nào chưa chắc thì kiểm tra bằng tài liệu chính thức hoặc chạy thử trong CI; chưa làm được thì ghi rõ "chưa kiểm chứng".
3. Mỗi thay đổi nhỏ và có test; không viết lại phần đã chạy trừ khi có lý do và đã báo trước.
4. Không sao chép mã Fermata (GPL-3.0): chỉ học ý tưởng và tự viết. Nếu dùng `NewPipeExtractor` thì kiểm tra giấy phép; chỉ đưa APK cho người khác khi đã mở mã nguồn theo giấy phép đòi hỏi.
5. Gom câu hỏi và hỏi tối đa một lần mỗi giai đoạn. Chỗ nào chưa rõ thì chọn phương án hợp lý nhất và nêu rõ trong báo cáo.
6. Trả lời bằng tiếng Việt, ngắn gọn.

**Việc cần hỏi Thanh một lần trước khi bắt đầu**

- Tên repo sẽ dùng.
- Loại xe (để chọn bảng tốc độ ước tính, mặc định ô tô con), hãng xe hoặc màn hình, và Android Auto kết nối có dây hay không dây.
- Hãng điện thoại và phiên bản Android.

**Điều không được làm**

- Không dùng root, Xposed hay Accessibility để điều khiển (khác với Fermata).
- Không dùng dịch vụ trả phí hay khoá API bắt buộc đăng ký thẻ.
- Không tải ảnh biển báo hay logo có bản quyền về dùng; tự vẽ vector.
- Không gửi số tài khoản, vị trí hay nhật ký chứa số tài khoản ra ngoài máy; che mờ số tài khoản trong nhật ký.
- Không ghi token hay khoá ký vào mã nguồn, log hay tin nhắn.

**Rủi ro và cách giảm**

| Rủi ro | Hậu quả | Cách giảm |
| --- | --- | --- |
| Android Auto đổi hoặc chặn app cài ngoài Play Store | Ứng dụng không hiện trên xe | Giữ phương án dự phòng `MediaProjection`; ghi lại phiên bản Android Auto đã thử; không nhắm tới Google Play |
| Chạm hạn chế, không có bàn phím | Không nhập liệu được trên xe | Mọi cấu hình làm trên điện thoại; xe chỉ có nút lớn |
| Vẽ qua VirtualDisplay bị giật | Trải nghiệm kém | Giới hạn 30 FPS, bản đồ vẽ nhẹ, cache tile, đo FPS ở màn hình Chẩn đoán |
| YouTube đổi cách phát | Mất tính năng phát | Hai lớp `YoutubeStreamProvider`, cập nhật gói nhanh bằng CI; Thanh chấp nhận rủi ro về điều khoản sử dụng |
| Dữ liệu OSM Việt Nam thiếu hoặc sai | Thiếu biển, sai tốc độ | Ba lớp dữ liệu, nhãn "ước tính", ghim của người dùng, cảnh báo trong Cài đặt |
| Dịch vụ miễn phí giới hạn hoặc chặn (Valhalla demo, Overpass) | Không tìm được đường | Đổi được địa chỉ máy chủ, cache, giới hạn tần suất, Overpass mặc định tắt |
| Mất khoá ký APK | Không cập nhật đè được | Sao lưu keystore, ghi rõ trong README |
| Mất tập trung khi lái | Nguy hiểm | Video khoá khi xe chạy, chữ lớn, không nhập liệu trên xe |

**Giấy phép và ghi nguồn.** Dữ liệu OpenStreetMap theo ODbL, luôn hiện "© OpenStreetMap contributors"; ghi nguồn OpenFreeMap; các thư viện Dart chính là BSD hoặc MIT (AI kiểm tra từng gói trước khi thêm); mã Fermata và có thể cả `NewPipeExtractor` là GPL-3.0. Việc lấy luồng YouTube để bỏ quảng cáo trái điều khoản sử dụng của YouTube, chỉ dành cho dùng cá nhân.

Nguồn chính cho phần phân tích: [repo Fermata](https://github.com/AndreyPavlenko/Fermata), [tài liệu SurfaceCallback](https://developer.android.com/reference/androidx/car/app/SurfaceCallback) và [hướng dẫn tương tác với bản đồ](https://developer.android.com/training/cars/apps/library/interact-map) của Android for Cars.
