# SportField Booking - Nhóm 01

Ứng dụng quản lý và đặt sân thể thao cho đồ án môn **Phát triển ứng dụng di động (Flutter/Dart)**.

## Thành viên
- Gia Huy
- Nguyễn Quốc Đạt
- Nguyễn Đình Bảo Huy
- Trần Thanh Sơn

## Phạm vi giao diện hiện tại
Ứng dụng Flutter/Dart có giao diện Customer, Owner và Admin. Tài khoản, hồ sơ và phiên đăng nhập dùng SQLite; sân, booking, thanh toán mô phỏng và khuyến mãi vẫn dùng MockStore trong bộ nhớ.

Các nhóm chức năng:

### Khách hàng
- Đăng ký tài khoản
- Đăng nhập
- Xem danh sách và tìm kiếm sân
- Xem chi tiết sân
- Đặt sân: chọn ngày/khung giờ
- Chọn dịch vụ kèm theo sân
- Áp dụng mã khuyến mãi
- Thanh toán mô phỏng
- Hủy đặt sân
- Xem lịch sử đặt sân
- Quản lý thông tin cá nhân

### Chủ sân
- Đăng ký tài khoản
- Đăng nhập
- Đăng ký sân mới (kiểm tra tối thiểu 3 ảnh ở mức UI mô phỏng)
- Quản lý thông tin & lịch đặt sân
- Quản lý dịch vụ kèm theo sân

### Quản trị viên
- Đăng nhập
- Duyệt sân mới: duyệt/từ chối
- Quản lý khuyến mãi: thêm/sửa/xóa
- Thống kê lượt đặt sân toàn hệ thống

## Dữ liệu
Khi chạy `lib/main.dart` trên Android, ứng dụng khởi tạo `accounts.db`, lưu tài khoản và hồ sơ vào SQLite, khôi phục phiên hợp lệ (tối đa 30 ngày). Đăng xuất xóa phiên khỏi database. Mật khẩu được băm PBKDF2-HMAC-SHA256 với salt riêng; không lưu mật khẩu thô vào database.

Tài khoản demo (mật khẩu chung `123456`):
- Khách hàng: `customer@gmail.com`
- Chủ sân: `owner@gmail.com`
- Admin: `admin@gmail.com`

Đăng ký hỗ trợ Khách hàng và Chủ sân, kiểm tra email trùng, số điện thoại 10 chữ số bắt đầu bằng 0 và xác nhận mật khẩu. Chạy `flutter test` để kiểm tra các luồng tài khoản.

SQLite hiện chỉ áp dụng cho tài khoản. `AccountService` đồng bộ hồ sơ sang MockStore để giữ ID liên kết với dữ liệu sân và booking hiện có. Các nghiệp vụ còn lại chưa lưu bền vững. `assets/db/database.sql` là thiết kế database toàn hệ thống, không phải schema đang chạy cho tài khoản. Chi tiết: [tích hợp tài khoản SQLite](docs/huong_dan/Tich_hop_ho_so_SQLite.md).

SĐT + mật khẩu, Google, Apple, sinh trắc học và quên mật khẩu chưa hỗ trợ trong bản SQLite. Thanh toán và hoàn tiền là mô phỏng.

## Chạy project
Môi trường tối thiểu: Flutter 3.41, Dart 3.11 (do `image_picker`). Máy phát triển đã kiểm tra với Flutter 3.47.4 / Dart 3.13.3.

Màn đăng ký sân chọn ảnh thật từ máy bằng `image_picker`, xem trước/xóa ảnh và yêu cầu tối thiểu 3 ảnh khác đường dẫn. Sân gửi duyệt được thêm vào dữ liệu giả của phiên chạy; chưa upload Storage. Danh sách khách hàng chỉ hiển thị sân đã duyệt.

Tài liệu kỹ thuật: [phân tích yêu cầu và Use Case](docs/gia_huy/README.md), [hướng dẫn kiểm thử thủ công](docs/gia_huy/test_thu_cong.md).

```bash
flutter pub get
flutter run
```

Nếu project được clone về từ GitHub và thiếu thư mục nền tảng (`android`, `ios`, ...), chạy một lần:

```bash
flutter create .
flutter pub get
flutter run
```

## Kiểm tra và bàn giao

```bash
flutter analyze
flutter test
flutter test integration_test/account_sqlite_test.dart -d emulator-5554
flutter build apk --debug
```

Integration test tài khoản tạo database `account_integration_test.db` riêng và dọn sau khi chạy; không xóa `accounts.db`. Unit/widget test cũ giữ MockStore để kiểm tra nghiệp vụ, còn `account_repository_test.dart` dùng SQLite thật qua FFI.

Mỗi thành viên làm branch riêng, tạo Pull Request để nhóm trưởng review. Không push trực tiếp vào main.
