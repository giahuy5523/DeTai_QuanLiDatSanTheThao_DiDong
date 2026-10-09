# Học code phần Gia Huy và luyện vấn đáp

Bạn chịu trách nhiệm phần phân tích yêu cầu/Use Case, khung project/theme/routes, Login/Register, Home/Danh sách sân, Upload ảnh và nối Navigator. Các màn Chi tiết/Đặt sân/Khuyến mãi, Tìm kiếm/Thanh toán, Admin duyệt sân có phân công cho thành viên khác; bạn cần hiểu dữ liệu và đường nối, không trình bày rằng bạn viết toàn bộ nghiệp vụ của họ.

## Đọc code theo thứ tự

1. `lib/main.dart`: main gọi runApp; SportFieldBookingApp tạo MaterialApp, dùng AppTheme, màn đầu Login, bảng AppRoutes.
2. `lib/models/user.dart`, `venue.dart`, `booking.dart`: hình dạng dữ liệu. AppUser giữ role; Venue giữ ownerId/status; Booking giữ userId/venueId và dữ liệu ngày giờ.
3. `lib/data/mock_store.dart`: static lists là dữ liệu dùng chung trong phiên. currentUser là phiên. findUserByEmail chuẩn hóa email; login kiểm tra mật khẩu nguyên chuỗi; addUser chặn email trùng; logout đặt phiên về null.
4. `lib/utils/auth_validation.dart`: các validator trả String khi sai, null khi đúng. FormState.validate gọi tất cả validator; chỉ xử lý tiếp khi true.
5. `lib/screens/auth/register_screen.dart`: đọc controller, validate, tạo AppUser theo role đã chọn, thêm vào MockStore, Navigator.pop trả email cho Login. Controller cần dispose để giải phóng tài nguyên.
6. `lib/screens/auth/login_screen.dart`: gọi login, lỗi thì SnackBar; đúng thì switch user.role. pushReplacementNamed thay Login bằng màn nghiệp vụ để Back không quay vào Login. Link Register dùng await nhận email, kiểm tra mounted rồi điền email/clear password.
7. `lib/utils/app_theme.dart`: ThemeData dùng Material 3, màu nền, form field và nút chung. Thay màu ở đây ảnh hưởng các màn dùng theme, tránh sửa từng màn.
8. `lib/screens/customer/home_screen.dart`: StatefulWidget lọc approved và môn đang chọn rồi dựng VenueCard. `customer_shell.dart` dùng IndexedStack giữ 5 tab Home/Search/Ưu đãi/Lịch sử/Tài khoản; chọn lại Lịch sử dựng lại màn để cập nhật đơn.
9. `lib/screens/customer/venue_list_screen.dart`: StatefulWidget do bộ lọc _sport thay đổi. setState làm build chạy lại; where lọc dữ liệu, map tạo các chip; ListView.separated dựng danh sách và khoảng cách; có thông báo khi rỗng.
10. `lib/screens/owner/upload_venue_screen.dart`: đọc ảnh và validate sân, giải thích dưới đây.
11. `lib/screens/owner/manage_venue_screen.dart`: await route Upload; quay về thì setState cập nhật danh sách. Truyền đúng venue.id khi mở ManageService.
12. `lib/utils/app_routes.dart`: map route name → WidgetBuilder, kiểm tra role và kiểu arguments trước khi dựng màn. Đây là kiểm tra giao diện, không phải bảo mật backend.
13. `test/widget_test.dart` và `test/gia_huy_flow_test.dart`: các hành vi đã kiểm tra. FakePicker trả XFile có bytes để kiểm tra preview thật trong widget mà không mở hộp chọn native.

## Luồng dữ liệu nên vẽ bằng tay

Đăng ký: Controller → validator → AppUser → MockStore.users → pop(email) → Login.

Đăng nhập: Email/password → MockStore.login → currentUser → switch role → Navigator thay màn.

Danh sách: MockStore.venues → approved → lọc sport → VenueCard → pushNamed(arguments: Venue) → Detail → Booking (giờ đầu/cuối, dịch vụ, promo) → Confirmation → Payment → confirmBooking kiểm tra lại lịch và ghi Booking/Payment mock → dialog → popUntil(CustomerShell/Home).

Upload: pickMultiImage → List<XFile> → readAsBytes → kiểm tra decode → Uint8List preview bằng Image.memory → đủ 3 ảnh → tạo Venue pending, ownerId=currentUser.id → MockStore.addVenue khởi tạo cả danh sách dịch vụ → pop(true) → Owner setState.

## Upload ảnh cần hiểu kỹ

- XFile chứa dữ liệu file/đường dẫn do picker trả. Không dùng File từ dart:io để preview nên màn Upload dùng được trên web.
- _images giữ XFile, _previews giữ bytes cùng thứ tự. Khi xóa ảnh, xóa cùng index ở cả hai list để không lệch.
- Set đường dẫn giúp không thêm lại cùng file path. Nó không so sánh nội dung hoặc hash ảnh, nên hai file khác path có thể trùng hình.
- instantiateImageCodec kiểm tra ảnh có decode được trước khi tính vào số lượng. Codec được dispose sau kiểm tra.
- _picking khóa nút chọn/gửi khi đang đọc ảnh, tránh thao tác đồng thời. try/catch/finally đảm bảo lỗi được báo và trạng thái chọn ảnh được mở lại.
- mounted cho biết State còn nằm trong widget tree; sau await phải kiểm tra vì người dùng có thể đã rời màn. Nếu không kiểm tra có thể gọi setState sau dispose.
- Preview nằm trong bộ nhớ; Venue.imageUrls giữ path picker, không phải link Firebase. VenueImage ở Chi tiết/Admin đọc URL bằng Image.network, đường dẫn picker bằng XFile.readAsBytes rồi Image.memory; có placeholder khi đọc lỗi. Card dùng biểu tượng môn.
- default status của Venue là pending; sau gửi, Customer không thấy sân cho đến khi được Admin duyệt.

## Navigator cần trả lời được

| API | Dùng ở đâu | Tác dụng |
|---|---|---|
| pushNamed | Home → Danh sách/Detail, Owner → Upload | Thêm màn trên stack, có thể Back |
| pop(context, result) | Register/Upload hoàn tất | Đóng màn và trả kết quả cho await |
| pushReplacementNamed | Login đúng tài khoản | Thay Login, không giữ Login bên dưới màn nghiệp vụ |
| pushNamedAndRemoveUntil(... false) | Logout | Mở Login và bỏ stack cũ |
| popUntil | Dialog thành công → Home | Bỏ dialog/payment/booking/detail/list trên Home |
| ModalRoute.settings.arguments | Detail, Booking, Payment, ManageService | Nhận dữ liệu từ màn trước |

Admin trước đây dùng replacement để mở Duyệt/Khuyến mãi làm mất Thống kê. Nay đóng Drawer rồi push, nên Back trở lại Thống kê.

## Câu hỏi vấn đáp mẫu

**Tại sao không lấy role từ dropdown ở Login?** Role gắn với tài khoản đã xác thực. Nếu người dùng tự chọn role thì Customer có thể chọn Admin và mở màn sai quyền.

**Tại sao email không phân biệt hoa thường?** Khi so sánh dùng trim/toLowerCase để không tạo tài khoản khác chỉ vì chữ hoa hoặc khoảng trắng ở đầu/cuối. Password không chuyển lowercase hoặc trim khi đối chiếu.

**StatelessWidget và StatefulWidget khác gì trong bài này?** Home/Danh sách có lựa chọn môn, Upload có ảnh và trạng thái chọn, nên dùng State và setState. Confirmation hiển thị arguments, không giữ lựa chọn thay đổi, nên là StatelessWidget. Thống kê có State để làm mới sau khi Back từ Duyệt sân.

**final list có thêm phần tử được không?** Có. final không cho gán list mới vào biến, nhưng không làm nội dung List bất biến.

**Vì sao có currentUser?** Để lấy đúng ID khi xem lịch sử, tạo Booking, lọc sân Owner và hiển thị hồ sơ. Trước đây cố định customer1/owner1 khiến tài khoản mới dùng dữ liệu demo của người khác.

**Tại sao pending bị ẩn?** Sân mới phải được Admin duyệt trước khi khách hàng xem/đặt. Bộ lọc approved thực hiện quy tắc này trên UI mock.

**Use Case include và extend là gì?** include là bước bắt buộc dùng lại: đăng ký sân cần chọn đủ ảnh và preview. extend là hành vi tùy chọn: chọn dịch vụ hoặc áp dụng mã mở rộng đặt sân. Đăng nhập là tiền điều kiện của luồng nghiệp vụ, không cần vẽ mọi use case include Login như thể luôn đăng nhập lại.

**47 test có nghĩa là không còn lỗi nào không?** Không. Nó xác nhận những tình huống trong test. Đã bổ sung 30 ca chạy thành công trên emulator Android 17, gồm picker thật hủy, chọn ba ảnh và gửi sân pending. Widget test vẫn dùng FakePicker. Picker hệ thống từng ANR trong phiên thử và chạy lại sau khi khởi động emulator đã qua; điện thoại thật, quyền ảnh trên Android cũ và build iOS/macOS vẫn cần thiết bị phù hợp để kiểm tra.

**Có lưu dữ liệu thật không?** Không. MockStore là bộ nhớ trong process. Restart mất user, sân và đơn mới; assets JSON/SQL chưa được app load. Đây là phạm vi báo cáo lần 1.

**Đã tích hợp thanh toán thật chưa?** Chưa. confirmBooking kiểm tra lại lịch và tạo Booking confirmed cùng bản ghi trong MockStore.payments có method/amount/status success. Radio MoMo/VNPay chỉ lựa chọn mô phỏng, không gọi cổng thanh toán hay trừ tiền. Đây là luồng tích hợp của nhóm, không có transaction SQLite/server.

**Vì sao kiểm tra lịch hai lần?** Booking kiểm tra để người dùng chọn giờ hợp lệ. Payment kiểm tra lại vì dữ liệu có thể đổi trước khi xác nhận. Hai khoảng giao nhau khi start < booking.end và end > booking.start; khoảng liền kề không trùng. Demo xử lý đồng bộ trong một process; app nhiều thiết bị cần kiểm tra/transaction ở server.

**Mã giảm giá tính trên tiền nào?** subtotal = giá sân/giờ × số giờ + tổng dịch vụ; total = subtotal × (1 − phần trăm/100). Chỉ truyền mã đã áp dụng hợp lệ; sửa text phải áp dụng lại. Ngày hết hạn có hiệu lực đến trước 00:00 ngày kế tiếp.

**Có thể dùng phiên mock để bảo mật app thật không?** Không. Role check trên client không thay thế backend. App thật cần xác thực server, phân quyền ở dữ liệu và xử lý mật khẩu an toàn.

## Bài tập tự làm để chứng minh bạn hiểu

1. Đổi màu chủ đạo trong AppTheme và chỉ ra vì sao nhiều màn cùng đổi.
2. Thêm 1 Venue pending trong mock và giải thích tại sao Home không hiện.
3. Đổi validate từ tối thiểu 3 sang 4 ảnh, sửa test tương ứng rồi chạy.
4. Đổi yêu cầu mật khẩu thành 8 ký tự và cập nhật test dữ liệu demo để hiểu ảnh hưởng.
5. Theo dõi bằng debugger _login, _submit và _pickImages; đọc giá trị currentUser, _images, _previews.
6. Tự viết test đăng ký chủ sân và xác nhận ownerId của sân mới là ID tài khoản đó.

## Những điều không nên nói quá khi vấn đáp

Đọc thêm [đối chiếu sơ đồ nhóm](doi_chieu_so_do_nhom.md). Sequence Login của nhóm đang gộp Customer/Owner về Home, nhưng Owner trong code vào Quản lý sân. Trong Sequence Booking, tham số tính giảm đang là originalAmount; phần mô tả quy định tiền sân cộng dịch vụ. Đây là hai điểm cần đồng bộ giữa hình, văn bản và hành vi chạy.

Không nói app đã dùng Firebase/SQLite runtime, đã thanh toán tiền thật, đã build iOS/macOS hoặc đã test máy thật khi chưa thực hiện. Không nói mật khẩu hiện đã hash: AppUser dùng password thô cho mock. Không nói hồ sơ đã lưu bền vững: _save hiện chỉ SnackBar. Giải thích trung thực phần bạn hiểu, phần đã kiểm thử và giới hạn; khai báo hỗ trợ công cụ theo quy định môn học.
