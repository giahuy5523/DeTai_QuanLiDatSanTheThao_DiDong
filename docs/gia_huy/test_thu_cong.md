# Test thủ công phần Gia Huy

Ngày kiểm tra: 07/10/2026. 47 widget/unit test đã qua; analyzer không có lỗi/cảnh báo. Đã bổ sung 30 ca chạy thành công trên emulator Android 17/API 37, gồm ca picker thật hủy, chọn ba ảnh, đọc preview và gửi sân pending. Picker hệ thống từng ANR, sau khi khởi động lại emulator test đã qua. Chưa kiểm tra điện thoại thật hoặc quyền ảnh trên Android cũ. Xem `kiem_thu_android_20261007.md` và `integration_test/README.md`; các bước dưới đây vẫn dùng để tự kiểm tra và ghi kết quả thực tế.

## Chuẩn bị

1. Flutter tối thiểu 3.41 và Dart tối thiểu 3.11. Máy phát triển đang dùng Flutter 3.47.4, Dart 3.13.3. Chạy `flutter --version` để đối chiếu.
2. Trong terminal tại thư mục project chạy `flutter pub get`, rồi `flutter devices`.
3. Để demo điện thoại: mở Android emulator hoặc cắm Android thật bật USB debugging, chạy `flutter run -d <device-id>`. Để test nhanh trên máy: `flutter run -d chrome` hoặc `flutter run -d windows` nếu có môi trường build Windows.
4. Chuẩn bị 4 ảnh PNG/JPG khác nhau trong máy/album emulator. Android emulator có thể kéo ảnh vào cửa sổ emulator; nếu thư viện chưa hiện, thử mở ảnh bằng Files/Photos.
5. Plugin mới cần dừng ứng dụng và chạy lại đầy đủ; hot reload không nạp plugin native. Nếu gặp MissingPluginException, dừng `flutter run`, chạy `flutter pub get`, rồi chạy lại.
6. Tài khoản demo: `customer@gmail.com`, `owner@gmail.com`, `admin@gmail.com`; mật khẩu đều `123456`.
7. Không khởi động lại app giữa test đổi role nếu muốn giữ sân/user vừa tạo. Hot restart cũng đặt lại MockStore; tài khoản và sân mới không lưu bền vững.

## Các ca bắt buộc

| ID | Thao tác | Kết quả mong đợi |
|---|---|---|
| M01 | Login: nhập `a@`, password `123`, bấm Đăng nhập | Báo email sai và password tối thiểu 6 ký tự; không chuyển màn |
| M02 | Nhập email không tồn tại hoặc mật khẩu sai nhưng đủ dài | Báo Email hoặc mật khẩu không đúng; giữ Login |
| M03 | Đăng nhập lần lượt 3 tài khoản demo | Customer vào Home; Owner vào Quản lý sân; Admin vào Thống kê |
| M04 | Bấm biểu tượng mắt ở password | Đổi hiện/ẩn password; nội dung không đổi |
| M05 | Đăng ký khách hàng với email mới, phone `0912345678`, password `abcdef`, confirm `abcdef` | Quay Login, email mới được điền sẵn, password trống; đăng nhập bằng password mới thành công |
| M06 | Đăng ký Owner mới rồi đăng nhập | Màn Quản lý sân rỗng của Owner mới; không thấy sân Owner demo |
| M07 | Đăng ký email ` CUSTOMER@GMAIL.COM ` | Báo email trùng; không tạo user khác |
| M08 | Đăng ký bỏ trống tên, phone `abc`, password ngắn hoặc confirm khác | Thông báo tại đúng field; không tạo tài khoản; không có lựa chọn đăng ký Admin |
| M09 | Customer: Home, thử các chip môn rồi Xem tất cả sân | Dữ liệu main có 9 sân: 7 approved, 1 pending, 1 rejected; Home/danh sách chỉ hiện approved; chip môn đổi kết quả |
| M10 | Danh sách: chọn Cầu lông rồi chọn Tất cả | Chỉ sân cầu lông rồi trở lại đầy đủ sân approved |
| M11 | Chọn từng thẻ sân | Chi tiết hiển thị đúng tên, giá và địa chỉ sân đã chọn; Back về màn trước |
| M12 | Home → Tìm kiếm sân → nhập từ khóa không có kết quả rồi xóa | Hiện không tìm thấy sân, sau khi xóa có kết quả trở lại |
| M13 | Chi tiết → Đặt sân; chọn ngày mai, giờ bắt đầu và kết thúc | Chỉ bật Tiếp tục khi khoảng giờ hợp lệ; giờ đã qua/trùng lịch/ngoài giờ mở cửa không chọn được; giờ kết thúc có thể bằng giờ đóng cửa |
| M14 | Chọn dịch vụ, nhập SAN10 → Áp dụng → Tiếp tục → Xác nhận & thanh toán | Giảm 10% trên tiền sân theo số giờ cộng dịch vụ; màn xác nhận/thanh toán nhận đúng dữ liệu. Sửa text mã sẽ bỏ giảm giá đến khi áp dụng lại |
| M15 | Xác nhận thanh toán → Về trang chủ → Lịch sử | Chỉ tạo 1 Booking mới; trạng thái Đã xác nhận; lịch sử thuộc user đang đăng nhập |
| M16 | Hủy chính đơn vừa tạo | Trạng thái Đã hủy; nút hủy của đơn biến mất |
| M17 | Hồ sơ → Đăng xuất; dùng nút Back | Về Login; không quay lại phiên cũ; đăng nhập user mới không thấy lịch sử user trước |
| M18 | Owner → Đăng ký sân: để tên/address trống; giá `abc`, `0`, `-1` | Báo field tương ứng; không gửi sân |
| M19 | Điền sân hợp lệ, bấm Chọn ảnh từ máy rồi hủy hộp chọn | Vẫn ở form; số ảnh không đổi; nhập liệu còn nguyên |
| M20 | Chọn 1–2 ảnh rồi Gửi duyệt | Báo cần tối thiểu 3 ảnh; giữ form |
| M21 | Chọn 3 ảnh khác nhau | Hiện 3 preview thật; không chỉ là icon giả |
| M22 | Chọn lại các ảnh đã có trong cùng phiên picker | Không tăng số lượng nếu đường dẫn trùng. Hai file khác đường dẫn nhưng cùng nội dung vẫn được tính là hai file |
| M23 | Xóa 1 trong 3 ảnh, thử gửi; chọn bổ sung | Sau xóa còn 2 và không gửi được; bổ sung đủ 3 thì gửi được |
| M24 | Gửi sân hợp lệ | Quay Quản lý sân, có sân mới Chờ duyệt; không có upload mạng; trường latitude/longitude chưa nhập được |
| M25 | Mở Quản lý dịch vụ trên sân vừa tạo | Danh sách dịch vụ ban đầu rỗng; không bị hiện dịch vụ của sân v1 |
| M26 | Logout Owner, Login Customer không restart | Sân pending mới không xuất hiện Home/danh sách |
| M27 | Logout Customer, Login Admin → menu Duyệt sân → Duyệt sân mới | Sân biến khỏi pending; Back về Thống kê; menu tiếp tục mở được |
| M28 | Logout Admin, Login Customer không restart | Sân vừa được duyệt xuất hiện Home/danh sách; Chi tiết đọc ảnh đầu tiên từ picker hoặc URL. Card dùng biểu tượng môn; ảnh lỗi có placeholder |
| M29 | Admin mở Quản lý khuyến mãi rồi Back | Trở lại Thống kê, không bị mất đường quay lại |
| M30 | Tắt hoàn toàn app và mở lại | User/sân/Booking vừa tạo mất; dữ liệu demo mặc định trở lại (đúng phạm vi mock) |
| M31 | Customer dùng thanh điều hướng Trang chủ/Tìm kiếm/Ưu đãi/Lịch sử/Tài khoản | Mỗi tab mở đúng màn; Lịch sử cập nhật sau khi đặt/hủy; Đăng xuất xóa phiên |
| M32 | Admin: thêm mã mới, thử mã trùng và phần trăm 0/101/NaN, sửa/xóa, mở lịch của mã hết hạn | Chặn dữ liệu không hợp lệ; CRUD cập nhật danh sách; lịch mở không crash; mã dùng được hết ngày hạn |
| M33 | Owner: sửa tên/loại sân/giá, mở dịch vụ, thêm/sửa/xóa dịch vụ | Lưu đúng sân được chọn; giữ district/city/ảnh khi sửa hoặc duyệt; chặn giá NaN/Infinity/không dương |
| M34 | Admin: duyệt sân rồi Back về Thống kê | Số sân pending giảm, approved tăng ngay |
| M35 | Thanh toán: chọn MoMo/VNPay, xác nhận và mở lịch sử | Booking tạo một lần, Payments mock ghi đúng method/amount/bookingId. Chỉ mô phỏng, không trừ tiền thật |
| M36 | Màn hình 360 px: cuộn Chi tiết, Đặt sân, Xác nhận, Ưu đãi, Quản lý khuyến mãi, Thống kê | Không tràn chữ hoặc có sọc vàng đen; nút và nội dung đọc được |

## Các ca nền tảng cần chạy thêm

- Android/iOS: kiểm tra hộp chọn ảnh và trường hợp từ chối quyền nếu hệ điều hành hỏi. Android mới có photo picker nên có thể không hỏi quyền toàn bộ thư viện.
- iOS: đã khai báo NSPhotoLibraryUsageDescription; cần máy Mac/iPhone để kiểm tra build/chọn ảnh. Không khẳng định iOS đã chạy chỉ từ test trên Windows.
- macOS: đã thêm quyền đọc file người dùng chọn; chưa build trên macOS.
- Màn hình hẹp: xoay màn hình, mở bàn phím, cuộn form tới Gửi duyệt, xem card tên/địa chỉ dài; không xuất hiện sọc overflow vàng đen.
- Android: nếu hệ điều hành hủy app khi đang mở picker, form chưa được lưu/phục hồi. Đây là giới hạn phiên mock cần ghi nhận nếu gặp.

## Ghi kết quả và ảnh báo cáo

Tạo bảng ID / thiết bị / Pass hoặc Fail / mô tả thực tế. Đừng điền Pass trước khi chạy. Chụp Login, Register (thông báo lỗi và thành công), Home, Danh sách lọc môn, Chi tiết, Upload có 3 preview, Chủ sân thấy pending, Admin duyệt và Customer thấy sân sau duyệt. Gửi ảnh và sơ đồ của nhóm để tổng hợp Word.

## Chạy test tự động lại

```powershell
flutter test
flutter analyze
```

Nếu chỉnh model hoặc route, chạy lại cả hai lệnh. 47 test xác nhận các tình huống trong mã test; ảnh mạng thật, hộp chọn native và thao tác trên thiết bị cần kiểm tra trực tiếp. Xem review_baohuy.md để biết các lỗi đã sửa khi merge.
