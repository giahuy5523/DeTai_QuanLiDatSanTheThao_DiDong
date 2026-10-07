# Review nhánh Bảo Huy và tích hợp vào main

Ngày 07/10/2026. Nhánh kiểm tra: `feature/baohuy-assigned-features`, commit `5efc730`. Main được đối chiếu tại `843f6c0`, có dữ liệu/model mới và màn Tìm kiếm của Đạt. Công việc Gia Huy đã lưu riêng ở `c3d3f9d` trước khi merge để giữ lịch sử.

## Kết quả review và sửa lỗi

| Vấn đề | Cách xử lý trong bản tích hợp |
|---|---|
| Nhánh feature dùng dữ liệu cũ 3 sân và ít tài khoản, thiếu dữ liệu mới của main | Giữ MockStore mới với 9 sân, 5 tài khoản, 16 Booking, payments/venueImages/openHours/sportTypes và Search mới; thêm các API cần cho UI Bảo Huy |
| Venue.copyWith không giữ sportTypeId/district/city từ model mới | Giữ các trường khi sửa/duyệt; chỉnh loại sân cập nhật cả sportTypeId |
| Chip môn trên Home chỉ đổi màu | Nối lựa chọn chip vào bộ lọc danh sách sân approved |
| Giờ đặt cố định, chưa chặn hôm nay đã qua, không chọn được kết thúc bằng giờ đóng cửa | Sinh giờ từ openHours; kiểm tra quá khứ, thứ tự đầu/cuối, giao nhau và trạng thái approved |
| Payment chỉ thêm Booking, không ghi lựa chọn phương thức hoặc kiểm tra lịch lần cuối | confirmBooking kiểm tra lại rồi ghi Booking và Map Payment method/amount/status; khi giờ đã bị đặt thì không ghi thêm |
| Sửa text mã vẫn giữ giảm giá cũ, mã không hợp lệ có thể đi vào đơn | Chỉ chuyển mã đã áp dụng hợp lệ; đổi text bỏ giảm/mã; tính trên sân theo số giờ cộng dịch vụ |
| Mã hết hạn lúc bắt đầu ngày, chỉnh mã cũ mở DatePicker bị assertion | Hiệu lực hết ngày hạn; DatePicker cho phép mở đúng ngày đã lưu của mã hết hạn |
| NaN/Infinity đi qua kiểm tra giá/phần trăm | Validate isFinite và khoảng hợp lệ khi Upload/sửa sân/dịch vụ/khuyến mãi; route kiểm tra total và các số tiền |
| Ảnh picker đọc bằng File/Image.file ở Web hoặc Image.network cho path cục bộ | Giữ Upload preview bytes của Gia Huy; dùng VenueImage đọc URL hoặc XFile bytes ở Detail/Admin, có placeholder khi lỗi |
| Menu admin thay màn làm mất đường Back; thống kê có thể cũ sau duyệt | Đóng Drawer, push màn mới, có Back; làm mới Thống kê khi quay lại |
| Tràn chữ trên 360 px ở Home/card/Detail/Booking/Confirmation/Promo/Statistics | Dùng Expanded/Wrap/FittedBox tại những hàng có nội dung dài; kiểm tra bằng widget test |

## Bằng chứng kiểm tra

- Analyzer: không có lỗi, warning hoặc info.
- `flutter test`: 47 test đã qua (14 tài khoản, 16 luồng Gia Huy, 17 tích hợp Bảo Huy).
- `flutter build web --no-pub`: thành công, Wasm dry run cũng qua. Chưa build APK/chạy Android trong lượt review này.
- Test bao gồm đặt sân → xác nhận → thanh toán → lịch sử/hủy, promo hợp lệ/sai/sửa text, đến giờ đóng cửa, giao nhau, Payment khi lịch vừa đổi, promo CRUD/NaN/trùng mã/ngày hết hạn, dịch vụ CRUD/Infinity, quyền/arguments, bộ lọc Home/Search, thống kê sau duyệt và các màn 360 px.
- Widget test dùng picker giả lập; ảnh mạng lỗi được kiểm tra bằng placeholder. Chưa xác nhận hộp chọn native trên điện thoại, ảnh từ mạng thật, iOS/macOS hoặc thanh toán thật.

## Việc tiếp tục của Gia Huy

Hướng dẫn test thủ công và học/vấn đáp đã cập nhật theo luồng có CustomerShell và Confirmation. Main vẫn là demo MockStore, chưa đọc SQLite/JSON, chưa tích hợp Google Maps. Nhánh Bảo Huy này chưa có Class Diagram hoặc screenshot giao diện; cần các tài liệu đó cho Word ngày 09/10. Không coi merge code là đã hoàn thành toàn bộ báo cáo nhóm.
