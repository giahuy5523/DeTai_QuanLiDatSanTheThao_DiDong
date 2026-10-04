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
Hiện tại sử dụng `MockStore` để mô phỏng dữ liệu và trạng thái trong phiên chạy ứng dụng. Firebase/SQLite chưa được tích hợp trong skeleton này vì giai đoạn đầu của môn học ưu tiên Flutter/Dart và giao diện.

## Chạy project
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
