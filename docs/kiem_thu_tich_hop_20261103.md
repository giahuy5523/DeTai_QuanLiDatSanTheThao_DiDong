# Kiểm thử tích hợp giao diện nhóm ngày 03/11/2026

## Phạm vi

Tích hợp `feature/baohuy-booking-ui` tại `573d776` và `thanh-son` tại
`bd2d682` trên nền `main` tại `ee07243`. Giữ phần Auth/Profile của Gia Huy,
Home/Search của Quốc Đạt, nghiệp vụ đặt sân/thanh toán của Bảo Huy và giao
diện Owner/Admin của Thanh Sơn. Nhánh Thanh Sơn đã chứa nhánh ảnh sân cũ
`feature/baohuy-assigned-features` và nhánh dọn tài liệu.

Xung đột `manage_venue_screen.dart` được giải quyết bằng giao diện Owner mới
của Thanh Sơn; giữ màn cập nhật sân và lịch đặt riêng. `pubspec.yaml` giữ đủ
ảnh sân, ảnh dịch vụ và ảnh phương thức thanh toán từ các nhánh.

## Lỗi đã sửa

| File và vị trí | Code cũ hoặc hành vi cũ | Cách thay thế |
|---|---|---|
| `lib/screens/owner/venue_bookings_screen.dart`, `_updateBookingStatus` | Tạo `Booking(...)` mới chỉ chép một phần thuộc tính, làm mất trạng thái thanh toán, dịch vụ, ghi chú và chi tiết khuyến mãi; hủy không hoàn tiền mô phỏng | Kiểm tra chủ sân và chuyển trạng thái hợp lệ, cập nhật `current.status` trên đơn hiện có; gọi `MockStore.cancelBooking(current.id)` khi hủy để hoàn tiền và lượt khuyến mãi đúng một lần |
| Cùng file, `_confirmAndUpdate` | Cập nhật giao diện sau `await` dù màn hình có thể đã đóng | Kiểm tra `mounted` trước cập nhật |
| `lib/screens/owner/manage_venue_screen.dart`, nhóm bộ lọc | `Row` không đủ chỗ trên màn 360px | Dùng `Wrap` với khoảng cách 8px |
| Cùng file, danh sách sân | Khoảng đệm cuối 16px khiến nút nổi che nút Dịch vụ ở thẻ cuối | Tăng khoảng đệm cuối lên 100px |
| Cùng file, nút cập nhật | `setState` sau khi trở về có thể chạy trên màn đã đóng | Kiểm tra `mounted && result == true` |
| `lib/screens/admin/manage_promotion_screen.dart`, `_openPromotionSheet` | Giải phóng controller ngay sau khi sheet trả kết quả, trong khi hiệu ứng đóng vẫn dùng ô nhập | Chờ `sheetRoute.completed` rồi mới giải phóng |
| `lib/screens/owner/manage_service_screen.dart`, `_editService` | Lỗi vòng đời controller tương tự khi đóng dialog | Chờ `dialogRoute.completed` rồi mới giải phóng |

Các test cũ được cập nhật theo nhãn nút mới, danh sách cuộn, ảnh có nội dung
khác nhau, lựa chọn môn thể thao và hộp thoại xác nhận. Thêm key ổn định cho
thẻ sân, mã khuyến mãi và chỉ số thống kê để định vị đúng phần tử.

## Kết quả kiểm tra

- Flutter 3.47.4, Dart 3.13.3 trên Windows.
- `flutter analyze --no-pub`: không có vấn đề.
- `flutter test --no-pub --reporter expanded`: 71 test đạt.
- `flutter build apk --debug --no-pub`: build thành công, tạo `app-debug.apk`.
  Có cảnh báo công cụ Android SDK đọc XML phiên bản mới hơn; cảnh báo không
  ngăn bản debug biên dịch thành công.
- Bổ sung 3 test Owner xác nhận, hoàn thành và hủy đơn; kiểm tra giữ nguyên
  dữ liệu thanh toán/dịch vụ/ghi chú và không hoàn tiền/lượt khuyến mãi hai lần.
- Các test hiện có kiểm tra đăng nhập/đăng ký, phân quyền, hồ sơ/avatar,
  đăng sân/ảnh, tìm kiếm, khuyến mãi, đặt sân, thanh toán mô phỏng và bố cục
  màn hình nhỏ.

## Giới hạn còn lại

- Dữ liệu nghiệp vụ vẫn dùng MockStore trong bộ nhớ, chưa tích hợp SQLite.
  Có `database.sql` không đồng nghĩa ứng dụng đang sử dụng cơ sở dữ liệu đó.
- SĐT, Google, Apple, sinh trắc học và quên mật khẩu vẫn hiển thị thông báo
  chưa có backend; đăng nhập Email dùng dữ liệu mô phỏng.
- Thanh toán và hoàn tiền là mô phỏng; không xác nhận giao dịch ngân hàng thật.
- Chưa chạy integration test trên thiết bị Android trong lần tích hợp này.
- Kết quả test tự động không thay thế nghiệm thu hình thức giao diện và demo
  thủ công trên thiết bị của nhóm.
