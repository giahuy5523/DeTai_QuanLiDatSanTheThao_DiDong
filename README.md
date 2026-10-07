# SportField Booking - Nhóm 01

Ứng dụng quản lý và đặt sân thể thao cho đồ án môn **Phát triển ứng dụng di động (Flutter/Dart)**.

## Thành viên
- Gia Huy
- Nguyễn Quốc Đạt
- Nguyễn Đình Bảo Huy
- Trần Thanh Sơn

## Phạm vi giao diện hiện tại
Project tập trung vào **Flutter/Dart và UI/UX**, dùng dữ liệu mock trong bộ nhớ để trình diễn luồng nghiệp vụ.

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
Đăng ký và đăng nhập dùng tài khoản giả trong `MockStore`. Tài khoản mới chỉ tồn tại trong phiên chạy; khởi động lại ứng dụng sẽ mất tài khoản vừa tạo. Vai trò được lấy từ tài khoản đăng nhập, không tự chọn ở màn Login.

Tài khoản demo (mật khẩu chung `123456`):
- Khách hàng: `customer@gmail.com`
- Chủ sân: `owner@gmail.com`
- Admin: `admin@gmail.com`

Đăng ký hỗ trợ Khách hàng và Chủ sân, kiểm tra email trùng, số điện thoại 10 chữ số bắt đầu bằng 0 và xác nhận mật khẩu. Chạy `flutter test` để kiểm tra các luồng tài khoản.

Hiện tại sử dụng `MockStore` để mô phỏng dữ liệu và trạng thái trong phiên chạy ứng dụng. Firebase/SQLite chưa được tích hợp trong skeleton này vì giai đoạn đầu của môn học ưu tiên Flutter/Dart và giao diện.

## Chạy project
Môi trường tối thiểu: Flutter 3.41, Dart 3.11 (do `image_picker`). Máy phát triển đã kiểm tra với Flutter 3.47.4 / Dart 3.13.3.

Màn đăng ký sân chọn ảnh thật từ máy bằng `image_picker`, xem trước/xóa ảnh và yêu cầu tối thiểu 3 ảnh khác đường dẫn. Sân gửi duyệt được thêm vào dữ liệu giả của phiên chạy; chưa upload Storage. Danh sách khách hàng chỉ hiển thị sân đã duyệt.

Tài liệu phần Gia Huy: [tiến độ và phân tích](docs/gia_huy/README.md), [test thủ công](docs/gia_huy/test_thu_cong.md), [học code và vấn đáp](docs/gia_huy/hoc_code_va_van_dap.md).

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

## Git nhanh
```bash
git init
git add .
git commit -m "Complete Flutter UI skeleton"
git branch -M main
git remote add origin <URL_GITHUB_CUA_NHOM>
git push -u origin main
```

## Lưu ý
Thanh toán, Firebase, upload Storage, đồng bộ dữ liệu thật và backend chưa phải phần trọng tâm của skeleton này.
