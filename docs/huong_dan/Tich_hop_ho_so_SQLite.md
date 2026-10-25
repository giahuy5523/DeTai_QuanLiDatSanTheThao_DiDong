# Hồ sơ Customer — bàn giao tích hợp SQLite

## Luồng hiện tại

- `ProfileScreen` đọc người dùng hiện tại từ `MockStore`; email chỉ đọc.
- Chọn ảnh bằng `image_picker`, đọc và giải mã ảnh, chuyển thành PNG để xem trước. Chưa bấm Lưu thì chưa cập nhật model hoặc tạo file avatar.
- Khi Lưu: validation tên/số điện thoại → `AvatarStorage.save` chép PNG vào `getApplicationDocumentsDirectory()/avatars/` → `MockStore.updateCurrentProfile` cập nhật cả danh sách users và currentUser → cập nhật UI, snackbar thành công.
- Update giữ nguyên id, email, password và role. Kiểm tra userId tránh ghi nhầm tài khoản nếu phiên đã đổi trong lúc lưu.
- Chọn Xóa ảnh chỉ thay đổi bản xem trước; bấm Lưu mới xóa đường dẫn model và dọn file cũ thuộc thư mục avatar của app. Không xóa ảnh gốc trong thư viện.
- Hủy picker, ảnh không giải mã được, lỗi ghi file không thay đổi dữ liệu hồ sơ đã lưu. Mất file avatar hiển thị icon người dự phòng.
- Đăng xuất cần xác nhận; xóa currentUser và dọn Navigator stack.

## Phần Đạt cần nối khi làm SQLite

1. Đối chiếu schema Users cuối cùng và bổ sung cột nullable `avatar_path` nếu chưa có; viết migration cho database đã tồn tại, không chỉ sửa seed.
2. Ánh xạ `AppUser.avatarPath` ↔ `avatar_path` trong repository chung; lưu cùng tên và số điện thoại theo id người dùng.
3. Thay điểm cập nhật `MockStore.updateCurrentProfile` bằng repository. Chỉ báo thành công khi transaction hoàn tất. Cập nhật session/UI bằng người dùng mới sau khi commit.
4. Khi đăng nhập/khôi phục phiên, đọc hồ sơ từ SQLite; kiểm tra avatar path có còn tồn tại. Đường dẫn file không phải URL cloud và không tự di chuyển sang máy khác.
5. Nếu database ghi thất bại sau khi tạo ảnh mới, dọn file mới; chỉ xóa ảnh cũ sau khi cập nhật database thành công.

## Giới hạn phải nói đúng

Hiện metadata vẫn chỉ nằm trong bộ nhớ MockStore: có thể đăng xuất/đăng nhập lại trong cùng lần chạy và thấy thông tin đã sửa; khởi động lại toàn bộ app sẽ trở về seed. File PNG được lưu trong thư mục ứng dụng nhưng liên kết tới tài khoản chưa được lưu bền vững. Chưa tích hợp SQLite, đồng bộ server hoặc cloud avatar. Mật khẩu vẫn là dữ liệu mock của dự án.

## Kiểm thử

`test/profile_test.dart`: lưu tên/số điện thoại và giữ identity; validation trên màn 360px; xem trước/lưu/xóa avatar; hủy/quyền truy cập/ảnh lỗi; lỗi lưu file; xác nhận/hủy đăng xuất; ghi và xóa file giới hạn trong thư mục avatar của app.
