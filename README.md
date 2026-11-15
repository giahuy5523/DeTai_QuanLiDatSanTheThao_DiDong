# SportField Booking — Nhóm 01

SportField là ứng dụng Android quản lý và đặt sân thể thao cho đồ án môn Phát triển ứng dụng di động. Thành viên gồm Gia Huy, Nguyễn Quốc Đạt, Nguyễn Đình Bảo Huy và Trần Thanh Sơn.

Ứng dụng dùng Flutter/Dart, SQLite qua sqflite, Android Gradle và Kotlin. Database cục bộ `sport_venue_database.db` (schema v3) lưu tài khoản, hồ sơ, phiên, sân, dịch vụ, booking, thanh toán, khuyến mãi và thông báo. Mật khẩu tài khoản được băm PBKDF2-HMAC-SHA256. Thanh toán và hoàn tiền là mô phỏng, dữ liệu nằm trên thiết bị.

| Vai trò | Chức năng chính |
| --- | --- |
| Customer | Đăng ký, đăng nhập bằng email, sửa hồ sơ và ảnh đại diện, tìm sân đã duyệt, đặt khung giờ, chọn dịch vụ, áp mã giảm giá, thanh toán, xem lịch sử và thông báo hoàn tiền. |
| Owner | Đăng ký sân, cập nhật thông tin sân, xem và quản lý lịch đặt, thêm/sửa/xóa dịch vụ. |
| Admin | Duyệt hoặc từ chối sân, quản lý khuyến mãi, xem thống kê và xác nhận kết quả hoàn tiền. |

Customer và Owner có thể hủy booking hợp lệ khi còn ít nhất 2 giờ trước giờ bắt đầu, bao gồm đúng mốc 2 giờ.

Tài khoản seed để demo cục bộ gồm `customer@gmail.com`, `owner@gmail.com` và `admin@gmail.com`. Mật khẩu seed công khai cho cả ba là `123456`.

## Chạy và kiểm thử

Cài Flutter **3.47.4** (bản dùng để nghiệm thu), Android SDK Platform 36, Android Build Tools, Platform Tools và JDK 17. Mở emulator hoặc kết nối thiết bị Android đã bật USB debugging.

```sh
flutter doctor
flutter doctor --android-licenses
flutter pub get
flutter devices
flutter run
flutter analyze
flutter test
flutter build apk --debug
```

APK debug nằm ở `build/app/outputs/flutter-apk/app-debug.apk`. Nếu cần chạy integration test SQLite trên Android, dùng emulator thử nghiệm có dữ liệu riêng. `integration_test/sqlite_customer_flow_test.dart` đặt lại database của ứng dụng trước khi chạy.

## Ký và build APK release

Cấu hình Android dùng tên **SportField**, application ID `com.sportfield.booking`, version `1.0.0+1` (versionName `1.0.0`, versionCode `1`).

1. Lưu keystore release của nhóm ngoài repository và lấy alias, mật khẩu qua kênh riêng. Dùng cùng khóa ký để thiết bị chấp nhận cài cập nhật lên bản đã phát hành.
2. Tạo `android/key.properties` trên máy build. Thay các giá trị mẫu bằng thông tin thật trên máy đó. Trên Windows, dùng dấu `/` trong đường dẫn hoặc escape dấu gạch chéo ngược theo cú pháp Java Properties.

```properties
storeFile=C:/private-keys/sportfield-release.jks
storePassword=YOUR_LOCAL_STORE_PASSWORD
keyAlias=sportfield
keyPassword=YOUR_LOCAL_KEY_PASSWORD
```

3. Chạy build và xác minh bằng `apksigner` và `aapt` trong Android SDK Build Tools. Trên Windows, gọi `apksigner.bat` nếu cần.

```sh
flutter pub get
flutter build apk --release
apksigner verify --verbose --print-certs build/app/outputs/flutter-apk/app-release.apk
aapt dump badging build/app/outputs/flutter-apk/app-release.apk
```

Đối chiếu fingerprint SHA-256 của chứng chỉ với chứng chỉ release nhóm đã lưu. Dùng `Get-FileHash build/app/outputs/flutter-apk/app-release.apk -Algorithm SHA256` trong PowerShell để lấy mã băm của file APK. Sao lưu keystore và mật khẩu qua kho lưu trữ riêng của nhóm. Giữ `android/key.properties`, khóa ký và mật khẩu ngoài Git.

Tài liệu bổ sung: [phân tích yêu cầu](docs/gia_huy/README.md) và [kiểm thử thủ công](docs/gia_huy/test_thu_cong.md).
