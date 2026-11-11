# Bàn giao phần Gia Huy — bản tích hợp

Mốc 12/11 hoàn thiện tài liệu, 13/11 tổng duyệt, 14/11 chốt nội bộ, 20/11 nộp APK release và báo cáo. Phần dưới dùng để cập nhật bản Google Docs của nhóm sau khi chốt commit nghiệm thu.

## Nội dung báo cáo

**Phân công.** Gia Huy phụ trách theme, Đăng nhập/Đăng ký/Hồ sơ, phân quyền, avatar, phiên SQLite, review và tích hợp. Quốc Đạt phụ trách Trang chủ/Tìm kiếm/Danh sách sân và nền dữ liệu chung. Bảo Huy phụ trách chi tiết sân, đặt sân, dịch vụ, thanh toán mô phỏng và lịch sử. Thanh Sơn phụ trách quản lý sân, lịch đặt và dịch vụ của Owner, duyệt sân, khuyến mãi và thống kê của Admin.

**3.3.1. Đăng nhập.** LoginScreen kiểm tra email và mật khẩu rồi gọi AccountService. AccountRepository đọc Users và kiểm tra hash PBKDF2-HMAC-SHA256. Khi hợp lệ, repository lưu phiên 30 ngày vào Session. Ứng dụng điều hướng theo vai trò Customer, Owner hoặc Admin. Lần mở kế tiếp chỉ khôi phục phiên còn hạn của tài khoản còn hoạt động. Đăng xuất xóa phiên.

**5.1. Lưu trữ.** Bản tích hợp dùng SQLite sport_venue_database.db, schema v3. Tài khoản dùng ID chuỗi. Hồ sơ lưu đường dẫn avatar trong Users, còn file ảnh nằm trong vùng dữ liệu ứng dụng. Repository tài khoản, sân và booking dùng chung database. Dữ liệu nghiệp vụ và trạng thái thanh toán mô phỏng được ghi bằng repository. Một số màn hình đọc bản sao dữ liệu trong bộ nhớ được nạp lại từ SQLite khi khởi động. Mã nhập dữ liệu cũ đọc accounts.db, bảo toàn hồ sơ đã có ở database đích và đánh dấu hoàn tất trong cùng giao dịch.

**5.3. Thư viện.** sqflite mở SQLite trên Android, cryptography và cryptography_flutter băm mật khẩu, image_picker chọn ảnh, path_provider xác định thư mục ứng dụng. flutter_test và integration_test kiểm tra ứng dụng. sqflite_common_ffi kiểm tra SQLite trên máy phát triển. Các cổng thanh toán trong đồ án chạy mô phỏng.

## Tổng duyệt Android

| Ca | Thao tác | Kết quả mong đợi |
|---|---|---|
| Tài khoản | Đăng nhập từng vai trò, thử mở route sai quyền | Vào đúng trang, chặn route sai quyền |
| Hồ sơ | Sửa tên, số điện thoại, avatar rồi buộc dừng và mở lại | Hồ sơ và avatar mới còn |
| Nâng cấp | Mở từ accounts.db cũ, sửa hồ sơ, đăng xuất rồi mở lại | Không ghi đè hồ sơ mới, không phục hồi phiên đã xóa |
| Liên vai trò | Owner đăng sân, Admin duyệt, Customer tìm và đặt, Owner xem lịch | Cùng mã sân và mã đơn ở các màn |
| Thanh toán | So sánh đơn online đã trả và đơn tiền mặt chưa thu | Doanh thu chỉ tính đơn đủ điều kiện đã thanh toán |
| Dữ liệu bền vững | Tắt hẳn app, mở lại và kiểm tra sân, lịch, trạng thái thanh toán | Dữ liệu vẫn có, khuyến mãi hoặc dịch vụ đã xóa không tự xuất hiện lại |
| Giao diện | Thử Login/Register/Profile trên màn Android nhỏ khi mở bàn phím | Các nút vẫn thao tác được, có ảnh đối chiếu Figma |

Khi ghi biên bản, thêm commit, thiết bị/API Android, kết quả thực tế và ảnh hoặc video cho từng ca. Minh chứng Figma cần link frame Login, Register, Profile đã duyệt. Log chạy thật dùng để điền mục 5.4. Kết quả QA cũ ở PR #6 chỉ dùng làm mốc tham chiếu.

## Kết quả kiểm thử ghi nhận

Bộ kiểm thử Flutter trên bản sao sạch của phần tích hợp đạt 140/140. Nhật ký kiểm thử nằm trong qa-verified.log của thư mục bàn giao cục bộ. Kiểm thử Android qua ứng dụng và minh chứng Figma được ghi riêng sau khi có kết quả.
