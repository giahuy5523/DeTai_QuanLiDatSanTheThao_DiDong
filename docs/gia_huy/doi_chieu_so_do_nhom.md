# Đối chiếu sơ đồ nhóm với ứng dụng hiện tại

Ngày đối chiếu: 07/10/2026. Nội dung dưới đây dùng để ghép báo cáo và giúp Gia Huy phân biệt thiết kế dữ liệu với phần đã triển khai trong bản demo. Đây là kết quả đọc tài liệu và mã nguồn, không phải cam kết rằng SQLite hoặc thanh toán thật đã được tích hợp.

## Tài liệu đã nhận

| Tài liệu | Nội dung đã kiểm tra | Vai trò trong báo cáo |
|---|---|---|
| ERD_và_SeQ.docx | Mô tả 10 bảng, quan hệ, nghiệp vụ; ảnh ERD, Sequence Login, Sequence Booking | Thiết kế CSDL và luồng dự kiến khi triển khai tầng dữ liệu |
| deployment.jpg | Android, Flutter Runtime, app-release.apk, SQLite, sqflite, Google Maps API qua HTTPS | Kiến trúc triển khai dự kiến |
| Code Flutter trong repository | AppUser, Venue, Booking, Payment, Promotion, MockStore và các screens/routes | Bằng chứng phần demo hiện tại |

Ảnh nhóm đã được sao chép nguyên bản, không chỉnh sửa, vào thư mục `nguon_nhom`. Chưa nhận Class Diagram hoặc screenshot giao diện của nhóm. Chưa có bằng chứng đã build app-release.apk trong lượt này.

## Đối chiếu ERD

ERD gồm Users, SportTypes, Venues, VenueImages, TimeSlots, Services, Promotions, Bookings, BookingServices, Payments. Thiết kế có Payments, Promotions, Venues.status và các bảng phục vụ nhiều ảnh/dịch vụ, phù hợp với nhóm tính năng mới được phân công.

| Nội dung ERD | Hiện trạng trong project | Cách trình bày chính xác |
|---|---|---|
| 10 bảng trong SQLite | `assets/db/database.sql` hiện có 7 CREATE TABLE; thiếu VenueImages, Services, BookingServices | ERD là bản thiết kế đầy đủ hơn script SQL hiện có; cần đồng bộ trước khi tích hợp DB |
| VenueImages nhiều ảnh, 1 ảnh primary | Venue Dart giữ List<String> imageUrls; Upload có preview và tối thiểu 3 ảnh, chưa có lựa chọn primary | Demo kiểm tra ảnh ở UI, chưa ghi bảng VenueImages hoặc is_primary |
| Booking.slot_id và số tiền tách riêng | Booking Dart giữ venueId, date, startTime/endTime, totalPrice và selectedServiceIds | Model mock được giản lược; chưa đại diện đầy đủ bản ghi SQL |
| Booking.service_amount | SQL chưa có service_amount, cũng chưa có BookingServices | Khi cập nhật SQL phải bổ sung tổng dịch vụ và giá tại thời điểm đặt |
| Payments 1–N Bookings, pending/success/failed/refunded | Payment Dart dùng unpaid/paid/failed và 1 bookingId; MockStore chưa có list Payments; UI thanh toán tạo Booking | Chưa lưu lịch sử giao dịch riêng hoặc đồng bộ status giữa model và ERD |
| Users.password_hash, is_active | AppUser mock có password thô, chưa có isActive | Hash password và khóa tài khoản thuộc tầng dữ liệu dự kiến; không tuyên bố đã triển khai |
| Promotions hạn đầu/cuối, số lượt, đơn tối thiểu, mức trần | Promotion Dart chỉ có code, discountPercent, expiryDate, isActive | Demo kiểm tra active/hạn hết và phần trăm; các ràng buộc mở rộng chưa có |
| Venue pending/approved/rejected | Đã có đúng các status và lọc approved phía Customer | Phần quy tắc hiển thị/duyệt đã mô phỏng trong bộ nhớ |
| Services/BookingServices có quantity và unit_price snapshot | UI dùng checkbox và cộng mỗi dịch vụ một lần; VenueService có id/venueId/name/price/unit | Chưa chọn số lượng hoặc lưu giá snapshot cho lịch sử đơn |

ERD nêu TimeSlots–Bookings là 1–N để lưu lịch sử đặt lại sau khi hủy. Ràng buộc chỉ một đơn còn hiệu lực cho mỗi slot cần được thực thi bằng transaction/quy tắc tầng dữ liệu; riêng UNIQUE trên TimeSlots không tự chặn nhiều Booking đang hiệu lực cùng slot.

Các mock Venue approved hiện có thể không có ảnh, do dữ liệu mẫu cũ. Quy tắc 3 ảnh đang áp dụng khi chủ sân gửi sân mới; cần thêm ảnh hợp lệ cho seed khi chuyển sang CSDL đầy đủ.

## Đối chiếu Sequence Login

Ảnh gốc: [Sequence Login](nguon_nhom/sequence_login.png).

| Bước trong sơ đồ | Demo hiện tại |
|---|---|
| UI validate → AuthController → UserRepository → SQLite | UI validate → MockStore.login → findUserByEmail trong list |
| Kiểm tra is_active và password_hash | Chưa có is_active; so sánh password thô trong mock |
| Lưu currentUser | Đã triển khai trong MockStore |
| Admin → AdminDashboard | Admin → StatisticsScreen, cùng mục đích màn quản trị |
| Customer/Owner → Home | Customer → Home; Owner → ManageVenueScreen |

Để sơ đồ mô tả đúng hành vi điều hướng, tách nhánh Owner → Quản lý sân. Giữ các lớp AuthController/UserRepository/SQLite nếu chương này ghi rõ là thiết kế dự kiến; nếu muốn sơ đồ phản ánh bản chạy hiện tại, dùng MockStore thay các lớp chưa có. Không cần tạo các lớp hình thức chỉ để khớp tên sơ đồ.

## Đối chiếu Sequence Booking

Ảnh gốc: [Sequence Booking](nguon_nhom/sequence_booking.png).

Sơ đồ mô tả một luồng thiết kế có transaction, kiểm tra slot, ghi BookingServices, dùng PromotionService và ghi Payments. Demo đang chuyển Venue giữa các màn, dùng list giờ cố định, cộng tiền dịch vụ và phần trăm giảm, rồi tạo Booking confirmed khi xác nhận thanh toán. Chưa khóa slot, chưa có transaction, chưa có danh sách giao dịch thanh toán.

Một điểm cần sửa trong chính sơ đồ: các lời gọi `applyPromo(code, originalAmount)` và `validate(code, originalAmount, today)` đang truyền tiền sân, trong khi phần mô tả ở Word quy định cơ sở tính giảm là **originalAmount + serviceAmount**. Nên đổi tham số thành `orderAmount` hoặc `subtotal` và ghi rõ cách tính, để ảnh và văn bản không mâu thuẫn.

Quy tắc lượt dùng mã đang tăng khi tạo đơn, trước khi biết thanh toán thành công. Nhóm cần xác định đây là giữ lượt khi tạo đơn hay tiêu thụ lượt khi thanh toán; nếu hủy/thanh toán thất bại thì lượt có được hoàn lại không. Đây là quyết định nghiệp vụ cần mô tả ở luồng hủy riêng, chưa thể khẳng định đã xử lý trong app.

Thành viên phụ trách thanh toán/đặt sân cần đồng bộ model và persistence khi nhóm chuyển sang dữ liệu thật. Phần Gia Huy hiện hoàn thành việc nối Navigator, truyền arguments và kiểm tra luồng giao diện.

## Đối chiếu Deployment

Ảnh gốc: [Deployment](nguon_nhom/deployment.jpg).

Sơ đồ có Android device chạy Flutter Runtime/app-release.apk, SQLite Database truy cập qua sqflite và Google Maps API qua HTTPS. Đó là hướng triển khai hợp lý để lưu dữ liệu cục bộ và cung cấp bản đồ, nhưng pubspec/code hiện chưa có sqflite, google_maps_flutter hoặc lời gọi Google Maps.

Trong báo cáo lần 1 nên dùng chú thích: “Kiến trúc triển khai dự kiến. Bản demo hiện chạy Flutter với MockStore trong bộ nhớ; SQLite và Google Maps chưa tích hợp.” Hình này không chứng minh APK đã được build hoặc bản đồ đã gọi API.

Một mô tả triển khai hiện tại để vấn đáp là: Android/Windows/Web → Flutter Runtime → giao diện và Model Dart → MockStore. image_picker mở bộ chọn ảnh của nền tảng; ảnh được đọc và preview trong phiên. Chưa cần tạo DB hoặc khóa Maps API chỉ để làm cho hình dự kiến giống demo.

## Việc còn lại của báo cáo

1. Đối chiếu Class Diagram của Bảo Huy với model hiện tại khi nhận file.
2. Bổ sung screenshot giao diện từ buổi test thủ công, kèm thiết bị và kết quả thực tế.
3. Tổng hợp phân tích/Use Case của Gia Huy cùng các hình nhóm; phân biệt chương thiết kế và chương hiện thực demo.
4. Chốt sơ đồ Login nhánh Owner và cơ sở tính khuyến mãi trong Booking.
5. Đồng bộ SQL/JSON/model ở giai đoạn tích hợp dữ liệu. Không tự sửa file gốc của thành viên khác trong lượt nhận tài liệu này.

## Câu trả lời khi thầy hỏi sơ đồ khác code

“Đây là thiết kế dữ liệu và luồng cho phiên bản có SQLite. Báo cáo lần 1 tập trung giao diện nên nhóm dùng MockStore để chạy demo. Em đã nối luồng và kiểm tra vai trò; tầng repository, transaction, hash mật khẩu và Google Maps chưa tích hợp. Chủ sân trong bản chạy vào Quản lý sân, vì vậy nhánh điều hướng trong Sequence cần cập nhật cho thống nhất.”

Nên hiểu được sự khác nhau này và trả lời đúng phạm vi, không trình bày các lớp hoặc dịch vụ dự kiến như thể đã có trong mã nguồn.
