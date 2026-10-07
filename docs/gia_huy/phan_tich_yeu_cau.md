# Phân tích yêu cầu ứng dụng quản lý và đặt sân thể thao

Người phụ trách nội dung: Gia Huy. Phạm vi báo cáo lần 1: ứng dụng Flutter/Dart với đủ luồng giao diện và dữ liệu giả trong phiên chạy. Dữ liệu trong MockStore là nguồn mà giao diện hiện tại sử dụng. JSON và SQL trong assets là tài liệu dữ liệu nhóm đã chuẩn bị, chưa được nạp vào ứng dụng.

## Mục tiêu và tác nhân

Ứng dụng giúp khách hàng tìm sân, đặt sân và theo dõi đơn; giúp chủ sân đăng ký và quản lý sân; giúp quản trị viên duyệt sân và quản lý khuyến mãi. Ba actor là Customer (Khách hàng), Field Owner (Chủ sân) và Admin (Quản trị viên).

| Actor | Chức năng |
|---|---|
| Customer | Đăng ký, đăng nhập/đăng xuất, xem Home và danh sách sân, lọc/tìm sân, xem chi tiết, chọn ngày/giờ, dịch vụ, mã khuyến mãi, thanh toán mô phỏng, lịch sử, hủy đơn, thông tin cá nhân |
| Field Owner | Đăng ký, đăng nhập/đăng xuất, quản lý sân và lịch đặt, đăng ký sân mới kèm ảnh, quản lý dịch vụ của từng sân |
| Admin | Đăng nhập/đăng xuất, thống kê, duyệt hoặc từ chối sân, thêm/sửa/xóa mã khuyến mãi |

## Yêu cầu chức năng

F01 Đăng ký: chỉ cho phép Customer và Field Owner. Họ tên không trống; email đúng định dạng và chưa được sử dụng (không phân biệt hoa thường); điện thoại gồm 10 chữ số bắt đầu bằng 0; mật khẩu tối thiểu 6 ký tự sau khi bỏ khoảng trắng hai đầu để kiểm tra độ dài; mật khẩu xác nhận phải trùng. Lưu AppUser trong bộ nhớ rồi quay lại Login. Mật khẩu được đối chiếu nguyên chuỗi khi đăng nhập.

F02 Đăng nhập: đối chiếu email và mật khẩu trong MockStore. Sai thông tin thì giữ màn Login và báo lỗi; đúng thì lưu currentUser và điều hướng theo role trong tài khoản. Không cho người dùng tự chọn quyền Admin. Đăng xuất xóa currentUser và xóa các màn trước khỏi Navigator.

F03 Home và danh sách sân: hiển thị tên, địa chỉ, đánh giá, giá; chỉ đưa sân approved vào danh sách khách hàng. Danh sách có bộ lọc môn thể thao, trạng thái rỗng và đường dẫn đến Chi tiết sân. Search là màn tìm kiếm riêng của Đạt.

F04 Chi tiết và đặt sân: hiển thị sân, dịch vụ, ngày/giờ và tổng tiền. Chưa có khung giờ thì nút tiếp tục bị vô hiệu. Luồng điều hướng mang theo Venue rồi mang theo dữ liệu đặt sân đến Thanh toán. Các màn nghiệp vụ đã có của Bảo Huy/Đạt được dùng để kiểm tra việc nối Navigator.

F05 Thanh toán mô phỏng: chọn cash, MoMo hoặc VNPay, xem tổng tiền, xác nhận, hiện thông báo thành công và tạo Booking confirmed cho currentUser. Không có giao dịch tiền thật. Hiện màn thanh toán chưa tạo bản ghi Payment riêng và chưa lưu phương thức đã chọn vào kho dữ liệu; đây là phần màn nghiệp vụ thanh toán của Đạt cần thống nhất khi nhóm hoàn thiện.

F06 Lịch sử và hủy: chỉ hiển thị Booking của currentUser; đơn pending/confirmed có nút hủy và chuyển cancelled. Chưa kiểm tra trùng khung giờ hoặc chính sách hủy/hoàn tiền thật.

F07 Đăng ký sân: chỉ Field Owner; tên và địa chỉ không trống, giá là số hữu hạn lớn hơn 0; chọn tối thiểu 3 ảnh có thể đọc được từ máy bằng image_picker. Preview ảnh, bỏ ảnh, chọn bổ sung, không tính lại cùng đường dẫn. Gửi tạo Venue pending thuộc owner đang đăng nhập và cập nhật màn quản lý. Không upload Firebase Storage. Vị trí latitude/longitude tạm là 0 vì form chưa có chọn vị trí bản đồ.

F08 Duyệt sân: Admin xem danh sách pending, chọn approve/reject; thao tác trên MockStore. Customer chỉ thấy sân đã approved. Đây là màn của Sơn, được nối vào route và kiểm tra quay lại Thống kê.

F09 Khuyến mãi: Customer nhập mã để giảm tổng tiền; Admin thêm/sửa/xóa mã. Phần UI đã có thuộc Bảo Huy. Mã cần còn hiệu lực và active. Bản mock hiện chỉ có phần trăm và hạn dùng, chưa áp dụng giới hạn lượt hoặc giá trị đơn như SQL.

F10 Dịch vụ: chủ sân mở quản lý dịch vụ theo đúng ID sân đã chọn, thay vì luôn dùng sân v1. Không cho chủ sân mở dịch vụ của sân người khác qua route.

F11 Hồ sơ: hiển thị đúng thông tin tài khoản đang đăng nhập. Nút lưu hồ sơ hiện vẫn chỉ thông báo mô phỏng, chưa thay thế AppUser trong MockStore.

## Ba nhóm tính năng mới theo timeline

Từ các màn được phân công trong timeline, nội dung này nhóm yêu cầu thành: (1) thanh toán mô phỏng, (2) khuyến mãi, (3) đăng ký sân có ảnh và duyệt sân. Nếu đề bài môn học đặt tên hoặc nhóm ba tính năng khác, cần đối chiếu lại bản yêu cầu chính thức trước khi nộp.

## Đặc tả các Use Case chính

| Use Case | Tiền điều kiện | Luồng chính | Ngoại lệ | Kết quả |
|---|---|---|---|---|
| UC01 Đăng ký | Chưa cần đăng nhập | Nhập thông tin, chọn Customer/Owner, xác nhận, validate, thêm AppUser | Thiếu dữ liệu, email trùng, mật khẩu không khớp: không thêm user | Quay Login, email được điền sẵn, password rỗng |
| UC02 Đăng nhập | Có tài khoản mock | Nhập email/password, đối chiếu, lưu currentUser, đi đúng màn theo role | Không tồn tại/sai password: báo lỗi, không mở màn nghiệp vụ | Customer về Home, Owner về Quản lý sân, Admin về Thống kê |
| UC03 Xem và chọn sân | Customer đăng nhập | Home, Danh sách, lọc môn, chọn Venue | Không có sân: thông báo rỗng; route thiếu dữ liệu: thông báo hợp lệ | Chi tiết nhận đúng Venue |
| UC04 Đặt và thanh toán | Customer chọn sân approved | Chọn ngày/giờ, tùy chọn dịch vụ/mã, tiếp tục, chọn cách thanh toán, xác nhận | Chưa chọn giờ: không tiếp tục; chưa tích hợp kiểm tra trùng lịch | Booking confirmed, dialog thành công, quay Home |
| UC05 Đăng ký sân | Owner đăng nhập | Điền sân, chọn ảnh, preview, gửi duyệt | Dưới 3 ảnh, file lỗi, giá sai: không tạo Venue; hủy picker: giữ form | Venue pending lưu trong phiên, Owner thấy sân mới |
| UC06 Duyệt sân | Admin đăng nhập, có pending Venue | Mở danh sách, Duyệt/Từ chối | Không có pending: trạng thái rỗng | Venue đổi approved/rejected trong bộ nhớ |
| UC07 Dùng khuyến mãi | Customer đang đặt sân | Nhập mã, áp dụng, xem tổng tiền | Mã sai/hết hạn: báo lỗi, mức giảm về 0 | Tổng tiền giảm theo phần trăm |
| UC08 Đăng xuất | Có phiên đăng nhập | Chọn Đăng xuất, xóa currentUser, reset Navigator | Không có xử lý đăng xuất server vì chưa có backend | Login; Back không trở lại phiên cũ |

## Yêu cầu phi chức năng và phạm vi

Giao diện dùng ThemeData chung, Material 3, thông báo lỗi tiếng Việt, có thể cuộn trên màn hình nhỏ. Phân quyền route ở client phục vụ demo, không thay thế xác thực và phân quyền server. Các thao tác chọn ảnh bất đồng bộ kiểm tra mounted trước khi sửa giao diện. Controller được dispose khi rời màn.

Không có backend, SQLite runtime, Firebase Auth/Storage, thanh toán thật hoặc lưu bền vững. Mật khẩu thô chỉ là dữ liệu mock phục vụ báo cáo lần 1, không dùng cho hệ thống thật. ID mới dùng thời gian microsecond để phân biệt bản ghi trong demo, không phải cơ chế ID phân tán.

## Tài liệu tham khảo

Tài liệu thiết kế nhóm đã cung cấp: ERD_và_SeQ.docx (ERD 10 bảng, Sequence Login và Booking) cùng ảnh Deployment. Nội dung [đối chiếu sơ đồ](doi_chieu_so_do_nhom.md) ghi rõ các phần SQLite, repository, transaction và Google Maps thuộc thiết kế dự kiến, chưa tích hợp vào demo.

- Flutter documentation: https://docs.flutter.dev/
- Forms và validation: https://docs.flutter.dev/cookbook/forms/validation
- Navigation và truyền dữ liệu: https://docs.flutter.dev/cookbook/navigation/passing-data
- image_picker, API và cấu hình nền tảng: https://pub.dev/packages/image_picker
- image_picker macOS: https://pub.dev/packages/image_picker_macos
- Dart language: https://dart.dev/language

Tài liệu tham khảo là nguồn kỹ thuật. Khi nộp báo cáo, khai báo công cụ hỗ trợ theo yêu cầu của môn học; không đồng nhất việc tham khảo tài liệu với nguồn viết toàn bộ mã.
