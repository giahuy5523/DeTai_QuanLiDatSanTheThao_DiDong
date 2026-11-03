# Tài khoản và hồ sơ SQLite

Cập nhật 03/11/2026. Phần Gia Huy trên nhánh `codex/gia-huy-account-completion`.

## Luồng thực thi

- `main()` khởi tạo SQLite qua `AccountService.initialize()` trước khi mở app. Lỗi mở dữ liệu hiển thị màn Thử lại, không âm thầm chuyển sang dữ liệu mock.
- `AccountRepository.open()` tạo `accounts.db` phiên bản 1; chỉ seed khi tạo database lần đầu. Dữ liệu đăng ký mới không bị ghi đè khi mở app lại.
- `Users`: `user_id TEXT PRIMARY KEY`, `full_name`, `email COLLATE NOCASE UNIQUE`, `phone UNIQUE`, `password_hash`, `role`, `avatar_path` nullable, `is_active`.
- `Session`: một dòng id=1, user_id khóa ngoại tới Users, expires_at theo milliseconds. Phiên tối đa 30 ngày; khôi phục chỉ khi tài khoản đang active và phiên còn hạn. Đăng xuất xóa dòng phiên.
- Mật khẩu: PBKDF2-HMAC-SHA256, 600.000 vòng, salt ngẫu nhiên 16 byte, khóa 256 bit. Chỉ hash và salt nằm trong database; AppUser đọc từ SQLite có password rỗng.
- Đăng ký chỉ cho customer/owner; email chuẩn hóa lowercase; database chặn trùng email/SĐT. Không tự đăng ký Admin.
- AccountService cập nhật danh sách Users/currentUser trong MockStore để những màn hiện có vẫn tra cứu được ID. Khi chạy test UI độc lập không gọi main(), service chưa được khởi tạo sẽ giữ adapter MockStore; đây không phải đường fallback khi startup lỗi.
- Hồ sơ ghi SQLite thành công rồi mới báo thành công và dọn avatar cũ. Chọn ảnh nhưng chưa Lưu chỉ thay đổi preview. File ảnh nằm trong documents/avatars; không xóa ảnh gốc của picker.
- Tất cả nút đăng xuất Customer/Owner/Admin gọi AccountService, xóa phiên bền vững rồi dọn Navigator stack.

## Hợp đồng tích hợp với Quốc Đạt

Database tài khoản được tách riêng để không tự ý thay schema toàn nhóm. Runtime hiện dùng ID chuỗi (`customer1`, `owner1`, ...), còn file thiết kế `assets/db/database.sql` dùng ID số và cột avatar_url. Không trộn hai schema hay coi file SQL cũ là runtime.

Khi Đạt tích hợp database chung: thống nhất một kiểu ID hoặc bảng ánh xạ; giữ liên kết owner_id/customer_id của sân/booking; migrate Users/avatar_path và phiên theo transaction, không xóa database để nâng phiên bản. Có thể truyền Database chung vào AccountRepository sau khi migrate schema phù hợp. Giữ lại dữ liệu người dùng trước và sau chuyển đổi; không chép password rỗng từ AppUser vào password_hash.

Các bảng sân, booking, dịch vụ, khuyến mãi, thanh toán chưa được chuyển sang SQLite trong phần việc này. Chưa có đồng bộ đa thiết bị, xác minh email/SĐT, Google/Apple, sinh trắc học hoặc reset mật khẩu từ xa. Phiên local không phải token backend. Seed chỉ phục vụ demo đồ án.

## Kiểm tra

- `test/account_repository_test.dart`: SQLite thật, register/login, hash, trùng email, chặn đăng ký Admin, sửa hồ sơ/avatar rồi đóng/mở lại, logout, phiên hết hạn và tài khoản bị khóa.
- `test/profile_test.dart`: picker, preview, lưu/xóa ảnh, lỗi tệp và xác nhận đăng xuất.
- `integration_test/account_sqlite_test.dart`: SQLite trên Android, đăng ký/đăng nhập qua service, sửa hồ sơ qua UI, đóng/mở kết nối để khôi phục và xóa phiên. Không thay thế kiểm tra force-stop toàn tiến trình.
