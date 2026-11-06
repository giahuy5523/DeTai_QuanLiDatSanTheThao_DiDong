# Bàn giao phần Gia Huy ngày 03/11/2026

## Đã triển khai và kiểm tra

- Nhánh `codex/gia-huy-account-completion`, nền main `4c5d94d`.
- Tài khoản/hồ sơ/phiên dùng SQLite `accounts.db`; giữ ID chuỗi để không lệch sân/booking MockStore.
- Đăng ký Customer/Owner; email/SĐT duy nhất; mật khẩu băm PBKDF2-HMAC-SHA256, salt riêng, không lưu thô vào database.
- Phiên tối đa 30 ngày, khôi phục khi khởi động; logout cả ba vai trò xóa phiên.
- Hồ sơ cập nhật tên/SĐT/avatar; database thành công mới dọn ảnh cũ. Startup có trạng thái chuẩn bị dữ liệu và Thử lại khi lỗi.
- Chuẩn hóa icon Material ở Auth, nút FilledButton, màu Admin và bo nút theo quy chuẩn nhóm.
- Analyzer sạch; 72/72 unit/widget test đạt. Một Android integration test SQLite đạt; log `All tests passed`.
- APK debug build được. Android kiểm tra theo cấu hình cục bộ có trước `edu.huit.phanminhduc2001240091`; thay đổi package không thuộc phần commit này.
- Thử bằng entrypoint thật: đăng nhập, mở hồ sơ, force-stop/mở lại khôi phục đúng tài khoản; chọn ảnh từ Photo Picker, lưu và mở lại vẫn có avatar. Ảnh avatar kiểm thử là ảnh chụp màn hình, không phải ảnh cá nhân.
- Ảnh `minh_chung/01..05` và hai đoạn video MP4 ghi trạng thái thực. Video không thay thế demo toàn bộ nghiệp vụ nhóm.
- `Slide_bao_cao_Nhom_1_Gia_Huy.pptx`: 11 slide chỉnh sửa được, có ghi chú người thuyết trình; đã xem từng slide và qua kiểm tra cấu trúc/font/geometry/import.

## Thiết kế Figma

File: https://www.figma.com/design/1Bv6rxBVlVbYDWECrhMZAj

Ba frame `1:2`, `1:43`, `1:84` có hero ảnh thật, tiêu đề trắng, slogan và 6 chấm. Căn giữa tiêu đề ở 7 frame Profile. Tool trả ID xác nhận đã ghi cấu trúc. Chụp kiểm tra cuối bị giới hạn Figma Starter; không khẳng định khớp hình thức tuyệt đối. Ảnh thiết kế đối chiếu cần xuất bổ sung khi có quyền truy cập.

## Báo cáo Word chưa chốt

Hai file Word trong thư mục này là bản soạn chưa nghiệm thu dàn trang. Word đã nhiều lần mở được file nhưng kẹt khi xuất PDF; thử tối ưu ảnh và bỏ bảng chứa ảnh vẫn chưa xuất được. Chưa có ảnh từng trang để kiểm tra. Không coi đây là báo cáo cuối đã kiểm tra hình thức. Cần mở Word kiểm tra hoặc chạy lại renderer khi môi trường xuất hoạt động. Nội dung có phân công, kiến trúc, schema thực thi, kết quả test, giới hạn và kịch bản demo; chưa có đủ minh chứng từng thành viên để chốt báo cáo toàn nhóm.

## Phần phối hợp còn lại

- Quốc Đạt thống nhất database chung và migration: file SQL thiết kế dùng ID số/avatar_url, runtime tài khoản dùng ID chuỗi/avatar_path. Không trộn trực tiếp; xem `../huong_dan/Tich_hop_ho_so_SQLite.md`.
- Sân, booking, dịch vụ, khuyến mãi và thanh toán chưa chuyển sang SQLite; không thuộc phần tự thay đổi của Gia Huy.
- Theo quyết định người dùng: SĐT, Google/Apple, sinh trắc học và quên mật khẩu giữ rõ chưa hỗ trợ, không tích hợp dịch vụ ngoài trong đợt này.
- Quyền sử dụng ảnh, link thiết kế, minh chứng demo và nghiệm thu từng thành viên cần nhóm bổ sung.
- Không có căn cứ xác nhận mọi chức năng của cả nhóm đã hoàn thành. Cần tổng duyệt theo hạn phân công.

## Lệnh kiểm tra

```text
flutter pub get
flutter analyze
flutter test
flutter test integration_test/account_sqlite_test.dart -d emulator-5554
flutter build apk --debug
```

Test Android dùng database kiểm thử riêng rồi dọn; không xóa `accounts.db`. Widget test nghiệp vụ cũ dùng adapter MockStore; SQLite có test FFI riêng. Không ghi đè hoặc commit các file Android và tài liệu đã bị sửa/xóa cục bộ trước tác vụ.
