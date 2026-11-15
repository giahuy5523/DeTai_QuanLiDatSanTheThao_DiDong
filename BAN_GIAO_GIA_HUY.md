# Bàn giao SportField 1.0.0 — Gia Huy

SportField là ứng dụng Android đặt và quản lý sân thể thao. Bản nghiệm thu dùng Flutter 3.47.4, Dart 3.13.3 và SQLite schema v3. Tài khoản, phiên, sân, dịch vụ, booking, thanh toán, khuyến mãi và thông báo dùng chung database cục bộ `sport_venue_database.db`. Thanh toán MoMo và hoàn tiền đều là mô phỏng.

## Phạm vi nghiệm thu

| Vai trò | Kết quả trên Pixel 8 với APK release |
| --- | --- |
| Customer | Đăng ký, đăng nhập, lưu thay đổi hồ sơ, xem sân, đặt hai khung giờ, thanh toán MoMo mô phỏng, hủy hai booking và xem yêu cầu hoàn tiền. |
| Owner | Xem cả hai booking đã hủy trong lịch sân. Thêm, sửa giá rồi xóa dịch vụ thử nghiệm. |
| Admin | Xác nhận hoàn tiền cho một booking và đánh dấu hoàn tiền thất bại cho booking còn lại. Customer nhận cả hai thông báo và xem đúng trạng thái trong chi tiết. Booking hoàn tiền thất bại vẫn hiển thị đã thanh toán. |
| Khôi phục dữ liệu | Sau `adb shell am force-stop`, Android báo khởi động lạnh với PID mới. Phiên Customer, thông báo và trạng thái thanh toán của cả hai booking vẫn đọc được từ dữ liệu cục bộ. |

Customer và Owner được hủy booking hợp lệ khi còn **ít nhất 2 giờ**. Test dùng đồng hồ cố định xác nhận còn `2:00:01` và đúng `2:00:00` thì được hủy, còn `1:59:59` thì bị chặn. Trên APK release đã thao tác hủy khi đủ thời gian. Mốc đúng 2 giờ được xác minh bằng test tự động.

`flutter pub get`, `flutter analyze`, `flutter test`, `git diff --check` và build APK release đều đạt trong lượt nghiệm thu. Flutter Test đạt **163/163**. Flutter CI trên integration cuối cũng đạt Analyze, Migration Test v3 và toàn bộ Flutter Test. [Lượt CI integration](https://github.com/giahuy5523/DeTai_QuanLiDatSanTheThao_DiDong/actions/runs/43711408202)

## APK và nguồn build

| Mục | Giá trị |
| --- | --- |
| Tên ứng dụng | SportField |
| Package ID | `com.sportfield.booking` |
| Version | `1.0.0+1` — versionName `1.0.0`, versionCode `1` |
| Chữ ký | `apksigner` xác minh APK Signature Scheme v2, chứng chỉ release `CN=SportField` |
| SHA-256 của file APK | `3DCC888332B5F391D3CA8969C5DC0ED75C03B262E29D6567CD47664C8FAC7D3C` |
| Commit mã nguồn dùng để build | `69a210b8b3f17d063100b05b991c7355e2a4bb5a`, build cùng cấu hình release khi đó còn ở local |
| Commit ghi cấu hình release và README | `0f14096dd6c2fc320e48a0dbed6776e95302ff45` |
| Snapshot integration cuối của 1.0.0 | `d242ebf1b3550cf95c2004052a519734b8291d36`, merge PR #13 |

Xem [README](README.md) để cài môi trường, cấu hình ký trên máy build và xác minh APK. Keystore và thông tin ký được lưu riêng.

## Mốc lịch sử và giới hạn xác minh

Kết quả **140/140** ở giai đoạn tích hợp `457b331` và QA các PR #6–#8 là mốc lịch sử. Kết quả bàn giao của 1.0.0 là **163/163** cùng nghiệm thu APK trên Pixel 8 như trên. Tài liệu này chưa ghi nhận bằng chứng xác minh giao diện theo Figma.
