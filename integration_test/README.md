# Kiểm thử trên Android

Bật emulator hoặc kết nối điện thoại USB debugging, rồi lấy ID bằng `flutter devices`.

```powershell
flutter test integration_test/android_auth_test.dart -d emulator-5554
flutter test integration_test/android_flows_test.dart -d emulator-5554 --exclude-tags viewport
```

Auth tái dùng 14 ca đăng nhập/đăng ký. Flows tái dùng 15 ca model, đặt sân,
thanh toán, khuyến mãi, dịch vụ, tìm kiếm và điều hướng admin. Hai ca gắn tag
`viewport` thay đổi kích thước view để kiểm tra 360 px; chạy chúng trong bộ
widget test trên máy tính, không thay đổi kích thước view của thiết bị đang chạy:

```powershell
flutter test test
flutter analyze
```

## Hộp chọn ảnh thật (cần thao tác trên thiết bị)

Chuẩn bị ít nhất ba ảnh PNG/JPG khác nhau trong thư viện. Chạy:

```powershell
flutter test integration_test/android_picker_test.dart -d emulator-5554 --dart-define=NATIVE_PICKER_TEST=true
```

Test tự đăng nhập owner và điền form đăng ký sân. Khi picker đầu tiên mở,
bấm Back/hủy. Khi picker thứ hai mở, chọn đúng ba ảnh rồi xác nhận.
Mỗi lần có tối đa hai phút để thao tác. Test kiểm tra hủy không mất dữ liệu,
ba ảnh preview đọc được, gửi duyệt tạo sân `pending` đúng chủ sân và quay
lại danh sách. Test này mặc định bỏ qua nếu không có dart-define, để tránh
chờ thao tác thủ công trong lượt test tự động.

Test khôi phục dữ liệu mock sau khi chạy. Mọi thanh toán vẫn là mô phỏng.
Xem kết quả thiết bị trong `docs/gia_huy/kiem_thu_android_20261007.md`.
