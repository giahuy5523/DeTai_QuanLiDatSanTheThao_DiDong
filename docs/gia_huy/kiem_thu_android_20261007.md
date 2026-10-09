# Kiểm thử Android ngày 07/10/2026

Thiết bị: `emulator-5554`, sdk gphone16k x86 64, Android 17/API 37.
Flutter 3.47.4, Dart 3.13.3. Bản nguồn: main `b43f02b` cùng các file
integration test bổ sung trong lượt kiểm tra này.

## Kết quả đã xác nhận

| Hạng mục | Kết quả | Bằng chứng |
| --- | --- | --- |
| Build/cài/mở Android debug | Đạt | Gradle assembleDebug, APK cài và mở Login |
| Đăng nhập/đăng ký/đăng xuất trên Android | 14/14 đạt | `build/android-auth-tests.log` |
| Model, đặt sân/thanh toán/khuyến mãi/dịch vụ/tìm kiếm/admin trên Android | 15/15 đạt | `build/android-booking-tests.log` |
| Picker Android thật: hủy, ba preview, gửi sân pending đúng owner | 1/1 đạt sau khi khởi động lại emulator | `build/android-picker-retry.log` |
| Widget/unit test trên máy tính | 47/47 đạt, gồm ca viewport 360 px | `build/android-local-regression-tests.log` |
| Dart analyzer | Không có lỗi/cảnh báo | `dart --suppress-analytics analyze` |

29 ca Android tái dùng assertion của test hiện có, chạy trong ứng dụng test
được build và cài lên emulator. Ba ca trong bộ flows là kiểm tra model;
các ca còn lại kiểm tra thao tác giao diện và dữ liệu mock. Số ca chạy lại
không đồng nghĩa với 29 yêu cầu mới. Thanh toán hoàn toàn mô phỏng.

Cộng thêm ca picker thật, tổng cộng 30 ca đạt trên Android. Ca picker có
thao tác ADB trên giao diện hệ thống, không tiêm FakePicker hoặc ảnh trả về
giả. Sau khi hủy lần đầu, test xác nhận còn 0 ảnh và tên sân giữ nguyên.
Lần sau chọn ba ảnh thật trong gallery, xác nhận ba widget Image, không có
placeholder lỗi, tạo sân pending giá 200000 đúng owner1 và ba đường dẫn
ảnh khác nhau, quay lại ManageVenueScreen. Dữ liệu thử được khôi phục
trong tearDown, nên sân thử không nằm trong app khi bạn mở lại.

Đã thao tác trực tiếp bằng ADB: đăng nhập khách, chọn lọc Cầu lông (chỉ còn
hai sân Cầu lông), mở Chi tiết, mở Đặt sân, quay lại và đăng xuất.

## Những lượt không đạt hoặc không hoàn tất

- Tái dùng nguyên bộ widget test Gia Huy trên Android không hoàn tất:
  ca ép view về 360 px gặp lỗi finder lúc gửi duyệt; lượt sau dừng tiến triển
  ở test ảnh không đọc được. Đã dừng các lượt này, không tính là suite đạt.
  Các ca viewport vẫn chạy đầy đủ và đạt trong bộ widget test máy tính.
- Lượt picker đầu tiên lỗi do test gọi API bàn phím giả lập chưa đăng ký.
  Đã sửa test dùng `FocusManager` để bỏ focus.
- Lượt picker thật tiếp theo mở được thư viện nhưng hệ thống báo
  `Photos & videos isn't responding`. Log events ghi ANR của
  `com.google.android.photopicker`: `Application does not have a focused window`.
  Test hết hạn hai phút, không tính là đạt. Đây là bằng chứng picker hệ thống
  gặp lỗi trong phiên thử; chưa đủ để kết luận mọi nguyên nhân nằm ngoài app.
- Sau khi khởi động lại emulator và chỉ định thao tác ADB vào display 0,
  ca picker chạy lại thành công (1/1), exit code 0. Sự cố ANR trong phiên
  trước vẫn được ghi nhận, không bảo đảm sẽ không tái diễn trên emulator.

Hướng dẫn chạy lại nằm ở `integration_test/README.md`. Test picker thật cần
người thao tác: hủy lần đầu, chọn đúng ba ảnh ở lần sau. Ba ảnh thử đã chép
vào `/sdcard/Pictures/GiaHuyTest` trên emulator. Log/ảnh trong `build` bị
Git ignore; báo cáo này và bộ test được giữ trong source.

## Phạm vi thay đổi

Thêm `integration_test` ở dev_dependencies, ba entry point test và tag
`viewport` cho ba ca widget test có ép kích thước view. Không thay đổi
logic trong `lib` hoặc sửa nhánh riêng của các thành viên trong lượt này.
Chưa xác nhận release APK, điện thoại thật, quyền ảnh trên Android cũ,
iOS hoặc luồng phục hồi khi hệ điều hành hủy app lúc picker đang mở.
