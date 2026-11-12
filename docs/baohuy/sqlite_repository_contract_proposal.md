# Đề xuất contract SQLite cho luồng đặt sân

> **Trạng thái: ĐỀ XUẤT, CHƯA ĐƯỢC NHÓM/QUỐC ĐẠT PHÊ DUYỆT.** Tài liệu này mô tả hiện trạng đọc được từ repository và các lựa chọn cần thống nhất. Không nội dung nào dưới đây là contract đang có hiệu lực; chưa có thay đổi ứng dụng, model hay schema được thực hiện theo tài liệu này.

## 1. Hiện trạng và phần còn thiếu

Ứng dụng hiện dùng `MockStore` làm nguồn dữ liệu trong bộ nhớ cho các màn booking; dữ liệu ghi qua `BookingRepository` đã được lưu vào SQLite và được nạp lại vào `MockStore` làm cache. Các màn Venue Detail, Booking, Confirmation, Payment, Booking History và quản lý booking chủ sân đọc/ghi venue, service, slot, booking, payment và promotion qua `MockStore` hoặc các lớp cục bộ quanh nó. `BookingRepository`, `PaymentService`, `PromotionService` và `BookingController` được khai báo trong `booking_history_screen.dart`; chúng chưa phải lớp repository dùng SQLite và vẫn thao tác dữ liệu MockStore. Booking đã persist trong SQLite, nhưng các màn vẫn đọc qua cache `MockStore`, nên cần chuyển từng luồng theo mục 9.

`assets/db/database.sql` định nghĩa schema SQLite cùng seed data; `pubspec.yaml` hiện khai báo `sqflite`, `path` và `sqflite_common_ffi`. Cập nhật: đã có `DatabaseHelper` (`lib/utils/database_helper.dart`) là singleton mở `sport_venue_database.db`, phiên bản 3, bật `PRAGMA foreign_keys`, có `onCreate` và `onUpgrade` (migration v2, v3). `AccountRepository`, `VenueRepository` và `BookingRepository` dùng chung kết nối này. Chưa có `PromotionRepository` riêng; logic khuyến mãi hiện nằm trong `BookingRepository`. `assets/db/database.sql` vẫn chỉ là thiết kế, không phải schema đang chạy.

Luồng chính hiện là Venue Detail → Booking (nhận `Venue`) → Confirmation → Payment (dữ liệu tóm tắt dạng map) → Booking History; màn chủ sân đọc/cập nhật booking riêng. Cần tránh để những màn này chuyển nguồn dữ liệu riêng lẻ làm phát sinh hai nguồn sự thật. Contract được thống nhất trước, sau đó chuyển một luồng nghiệp vụ trọn vẹn qua cùng abstraction.

## 2. Chênh lệch model và schema cần giải quyết

| Chủ đề | Model/runtime hiện tại | `assets/db/database.sql` | Cần thống nhất |
|---|---|---|---|
| ID và khóa ngoại | ID trong `Venue`, `Booking`, `Payment`, `TimeSlot`, `VenueService`, `Promotion` là `String`. | Khóa chính/ngoại là `INTEGER` autoincrement. | Chọn khóa số và ánh xạ nhất quán sang String, hoặc đổi schema sang text/UUID bằng migration. Không ép parse các ID mock như `v1`, `p1`, `s1` thành số. |
| Thời lượng booking | `Booking` giữ ngày, `startTime`, `endTime`; các luồng hỗ trợ khoảng nhiều giờ. | `Bookings` tham chiếu đúng một `slot_id`; `TimeSlots` lưu một khoảng start/end và duy nhất theo venue/ngày/start. | Chốt cách biểu diễn và liên kết tất cả đơn vị thời gian bị chiếm. Một FK slot duy nhất không thể tự diễn đạt nhiều slot nếu đặt nhiều giờ. |
| Slot | Model `TimeSlot` có id và trạng thái; MockStore có thể sinh khung giờ động. | Bảng slot cần row bền vững và có status `available/booked/blocked`. | Chốt slot là các đơn vị cố định được materialize hay khoảng linh hoạt; quy tắc tạo/đọc slot và ý nghĩa status. |
| Promotion | `Promotion` có code, percent, expiry, active, usedCount. | Còn có start date, usage limit, min order, max discount, status. | Bổ sung/mapping đầy đủ trước khi tuyên bố cùng semantics; chốt khoảng ngày áp dụng, ngưỡng đơn và cách tính/tròn tiền. |
| Venue | Model không có trường `description`; ảnh là danh sách URL; `ownerId` dạng String. | Có description, ảnh tách bảng `VenueImages`, owner FK số. | Chốt trường được lưu, ánh xạ owner và thứ tự/ảnh chính. `image_url` không tự đảm bảo xử lý đường dẫn file cục bộ. |
| Service | `VenueService` không thể hiện status/description; ID chuỗi. | `Services` có status, description và FK venue. | Chốt chỉ cho đặt service active; lưu snapshot giá và tên/đơn vị nào vào đơn cũ. |
| Booking service | Model `BookingService` có IDs chuỗi, qty, unit price, subtotal; `BookingServiceItem` nhúng trong booking. | Bảng `BookingServices` có FK service và snapshot số lượng/giá/subtotal. | Chọn một mô hình domain thống nhất; khi đọc booking phải tải items và giữ snapshot giá cũ. |
| Payment | Model `Payment` có ID chuỗi, bookingId, method/status, amount, transactionCode, paidAt. Booking có một `paymentId?`, trong khi MockStore có thể giữ nhiều lần thử. | Bảng `Payments` cho phép nhiều dòng theo booking; method/status bị giới hạn CHECK. | Định nghĩa rõ lịch sử attempts và quan hệ `paymentId` trong Booking: payment hiện tại, payment thành công, hay bỏ khỏi model tổng hợp. |
| Tiền | Model và schema dùng `double`/`REAL`; SQL CHECK tổng tiền dùng so sánh bằng chính xác. | Các cột amount đều REAL. | Đề xuất ưu tiên đơn vị tiền nguyên (VND integer) hoặc thống nhất cách tính/đối chiếu có dung sai. Đây là quyết định schema, chưa được áp dụng. |
| Trạng thái | Runtime cho phép các trạng thái booking/payment tương ứng, gồm: `payments.status` = pending | success | failed | refunded; `bookings.paymentStatus` = unpaid | paid | refunded; `payments.refundStatus` = processing | succeeded | failed (giá trị đang được code dùng; xem mục 5 của tài liệu thống nhất). | Schema có CHECK trạng thái nhưng không định nghĩa mọi chuyển trạng thái/ngữ nghĩa nghiệp vụ. | Chốt state machine và đặc biệt trạng thái slot sau hủy/thất bại/hoàn thành. |

Schema hiện có seed lịch sử với `service_amount = 0`, không có BookingServices cho các dòng cũ; chúng phải được đọc tương thích, không suy ra lỗi dữ liệu chỉ vì thiếu items. `database.sql` đang là asset SQL có seed chứ chưa phải migration/versioning strategy. Nội dung file hiển thị một số chuỗi tiếng Việt bị mojibake; cần kiểm tra encoding/seed với người quản lý schema trước khi dùng làm dữ liệu khởi tạo thực tế.

## 3. Đề xuất khởi tạo database, versioning và test factory

**Đề xuất cần duyệt:** một `DatabaseProvider`/`DatabaseFactory` duy nhất sở hữu mở/đóng database và cung cấp handle cho repositories. Tên chỉ minh họa, không phải API đã tồn tại.

- Trên thiết bị, mở database tại đường dẫn ứng dụng qua `path`; cấu hình foreign keys cho từng connection (`PRAGMA foreign_keys = ON`). Không để widget tự mở DB hoặc chạy SQL.
- Tạo database mới từ DDL đã được nhóm duyệt, không thực thi trực tiếp toàn bộ file seed như migration mặc định. Seed dev/test phải là bước tách biệt, lặp lại an toàn và không chạy ngầm cho dữ liệu người dùng.
- Dùng `PRAGMA user_version` hoặc cơ chế versioning nhất quán với sqflite: version ban đầu và migration từng version tăng tuần tự trong `onUpgrade`, theo transaction. Không xóa/recreate database khi nâng version.
- Tách factory/connection injection để test cấp phát database tạm riêng cho mỗi test. Dùng `sqflite_common_ffi` để test desktop/CI, khởi tạo FFI một lần theo hướng dẫn package, đóng và xóa đúng DB tạm sau test. Không để test dùng DB thật của ứng dụng.
- Chốt xử lý lỗi khởi tạo/migration: báo lỗi lên tầng điều phối/UI, không âm thầm chuyển một phần luồng sang MockStore hoặc báo thành công khi migration rollback.

Chưa xác minh contract đồng đội cho singleton, tên file, version hiện tại, initializer, transaction hay factory. Vì vậy các tên/hướng trên chỉ là đề xuất; cần đối chiếu với Quốc Đạt trước khi tạo lớp tương ứng.

## 4. Đề xuất repository interfaces bất đồng bộ

Các chữ ký dưới đây là phác thảo khái niệm để thống nhất phạm vi, không phải source API đã duyệt. Có thể đổi tên/kiểu theo repository chung sau khi xác minh.

```dart
abstract interface class VenueRepository {
  Future<Venue?> getVenueById(String venueId);
  Future<List<Venue>> getApprovedVenues();
  Future<List<VenueService>> getActiveServices(String venueId);
}

abstract interface class BookingRepository {
  Future<List<TimeSlot>> getSlots(String venueId, DateTime date);
  Future<List<Booking>> getBookingsForCustomer(String userId);
  Future<List<Booking>> getBookingsForOwner(String ownerId);
  Future<Booking?> getBookingById(String bookingId);
  Future<Booking> createBooking(BookingRequest request);
  Future<Booking> cancelBooking(CancelBookingRequest request);
}

abstract interface class PaymentRepository {
  Future<List<Payment>> getAttempts(String bookingId);
  Future<Payment> recordCashCollection(String bookingId, PaymentRequest request);
  Future<Payment> recordOnlineAttempt(String bookingId, PaymentRequest request);
}
```

Các thao tác `createBooking`, thanh toán và hủy không được triển khai thành chuỗi lệnh độc lập qua các repository nếu cần cập nhật nhiều bảng. Đề xuất thêm use-case/coordinator transaction boundary (hoặc method nghiệp vụ trên repository chung) để sở hữu nguyên transaction; các interface đọc có thể tách. Trả về typed result/error phân biệt không còn slot, promotion không hợp lệ, booking không tồn tại/không được phép hủy, xung đột trạng thái và lỗi lưu trữ. Quyết định shape/exception mapping cần nhóm duyệt.

Màn hình chỉ gọi service/repository abstraction bất đồng bộ; xử lý loading/error/refresh ở tầng phù hợp với kiến trúc đã thống nhất. Không chuyển một screen sang SQL trực tiếp hay tạo repository thứ hai song song với abstraction chung.

## 5. ID, nhiều giờ, overlap và transaction tạo booking

### ID

Mỗi entity có ID bền vững; booking/payment/service-item FK phải dùng chính ID được tạo từ DB, không dùng index danh sách hoặc `DateTime.now()` làm ID. Nếu domain tiếp tục expose String, repository cần mapping duy nhất và không làm mất định danh; cần xử lý dữ liệu mock legacy trước khi import. Payment attempt có ID riêng và `booking_id` FK rõ ràng. Chốt UUID/text hay INTEGER tại contract/schema trước migration.

### Khoảng giờ

Quy ước đề xuất là khoảng nửa mở `[start, end)`: khoảng liền kề (ví dụ 18:00–19:00 và 19:00–20:00) không overlap. Hai khoảng cùng sân/ngày overlap khi `newStart < existingEnd && existingStart < newEnd`. Chỉ booking ở trạng thái còn giữ sân (tối thiểu pending/confirmed; danh sách cuối phải thống nhất) và slot blocked mới ngăn đặt; cancelled/completed không chiếm slot tương lai theo cùng một quy tắc ngày giờ.

DDL hiện có một `slot_id` trên booking và unique slot start, chưa có ràng buộc database cho overlap của khoảng tùy ý. Cần chọn một trong các hướng:

1. Chuẩn hóa slot cố định (ví dụ từng giờ) và lưu mọi slot bị chiếm cho booking qua quan hệ booking-slot; hoặc
2. Cho TimeSlots là các khoảng bất kỳ, lưu start/end trực tiếp/quan hệ booking phù hợp và kiểm tra overlap trong transaction với chiến lược chống ghi đồng thời.

Không thể quyết định từ schema hiện tại rằng multi-hour đã được bảo vệ. SQLite không có exclusion constraint theo khoảng như một số DB khác; chỉ truy vấn trước khi insert ngoài transaction không ngăn race. Cần transaction write lock/serialize trên connection phù hợp, kiểm tra lại xung đột bên trong transaction và ràng buộc dữ liệu phù hợp với hướng được chọn.

### Transaction tạo booking

Đề xuất một giao dịch nguyên tử: (1) đọc lại venue đang approved, khách còn hợp lệ, giá và service active; (2) xác minh ngày/giờ trong giờ mở cửa và không ở quá khứ; (3) kiểm tra lại toàn bộ slot/khoảng bị chiếm và blocked; (4) tính lại tiền sân theo duration, services theo `quantity × snapshot unit price`, discount theo promotion hiện tại; (5) xác thực promo và tăng usage có điều kiện nếu đủ limit; (6) insert booking, booking-service snapshots và payment attempt đầu tiên; (7) cập nhật slot/booking-slot nếu thiết kế dùng bảng đó; (8) commit. Bất kỳ lỗi nào rollback toàn bộ, gồm promo counter và slot.

Client gửi lựa chọn/dữ liệu cần thiết, nhưng repository tính lại và tự kiểm tra tổng tiền; không tin tổng tiền do màn hình truyền. Chốt quy tắc duration/đơn giá giờ, làm tròn tiền và discount base (tiền sân hay cả dịch vụ) để domain/UI/DB dùng cùng công thức.

## 6. Payment attempts và thanh toán tiền mặt

`Payments` hiện hỗ trợ nhiều dòng theo booking; mô hình này nên giữ lịch sử từng attempt. Tạo attempt mới với ID riêng cho mỗi lần thử online; transaction code nếu có phải duy nhất. Callback/kết quả phải kiểm tra booking ID, payment ID/attempt, số tiền, trạng thái hiện tại và idempotency key trước khi đổi trạng thái. Một callback lặp không được ghi nhận thanh toán lần hai. Không tạo attempt mới nếu booking đã có payment success/refunded hoặc đã hoàn tất theo policy.

Đề xuất online: attempt thành công thì cập nhật attempt `success`, `paid_at`, booking `payment_status=paid`, booking status theo state machine đã duyệt và payment reference theo định nghĩa; attempt thất bại được giữ `failed` để audit. Chốt liệu booking sau online failure được giữ pending/unpaid để retry trong thời hạn hay bị cancel/release slot. MockStore hiện mô phỏng failure theo hướng lưu payment failed và booking cancelled/unpaid, nhưng không nên mặc nhiên coi đó là policy SQLite cuối cùng.

Đề xuất cash: khi khách đặt, lưu payment attempt `cash/pending`, booking chưa được đánh dấu `paid`; ghi nhận tiền mặt là thao tác riêng (ví dụ chủ sân/nhân viên xác nhận thu) trong transaction cập nhật payment thành success và booking thành paid. Chốt thời điểm booking chuyển pending → confirmed và ai có quyền xác nhận tiền. Không ghi `paidAt` trước lúc thu tiền. Ràng buộc amount phải bằng tổng phải trả đã lưu trên booking.

## 7. Hủy, refund mô phỏng và hoàn promo

Đề xuất hủy nguyên tử trong một transaction: đọc lại booking; xác thực actor/quyền và trạng thái cho phép hủy; chuyển trạng thái booking đúng một lần; lưu reason/time; nếu đã thanh toán thì xác định đúng successful payment (booking/payment ID và amount), đổi payment sang `refunded` theo chính sách mô phỏng và booking `payment_status=refunded`; nếu chưa trả tiền thì không tạo refund giả, giữ `unpaid`; giải phóng mọi slot liên kết; hoàn lượt promo nếu booking thực sự đã tiêu thụ lượt theo policy; rồi commit. Nếu update bất kỳ phần nào thất bại, rollback cả trạng thái, payment, slot và promo.

Hủy lặp phải idempotent hoặc trả lỗi trạng thái đã hủy; không lặp refund/counter decrement. Dùng cập nhật có điều kiện từ trạng thái cho phép và kiểm tra số row ảnh hưởng, cùng một dấu hiệu/ledger duy nhất cho việc hoàn promo/refund. Nếu schema không có cột/ledger thể hiện tiêu thụ lượt cụ thể, `used_count` đơn lẻ không chứng minh booking nào đã tiêu thụ; cần thống nhất cách liên kết (ví dụ reservation/redemption record hoặc quy tắc booking có promo và giao dịch tạo booking đã commit). Không giảm counter dựa riêng vào thao tác hủy do client gọi.

Refund hiện là mô phỏng, không phải tích hợp cổng tiền. Chốt hủy trước bao lâu, booking status `completed` có được hủy không, cash đã thu xử lý hoàn ra sao, failed/pending attempts xử lý thế nào, promo có được hoàn khi hủy và booking cũ có được hủy không.

## 8. Quyết định cần nhóm trưởng/Quốc Đạt xác nhận

**Tất cả mục dưới đây đang chờ xác nhận; chưa có mục nào được tài liệu này coi là phê duyệt.**

1. Có repository/database service chung nào đang được phát triển không? Chủ sở hữu initializer, database filename, connection lifecycle, transaction API và nơi đặt contract là gì? Yêu cầu tránh sửa phần database/API của Đạt cho tới khi contract/schema cuối được chia sẻ.
2. Duyệt khóa `INTEGER` hiện tại hay đổi sang UUID/text để tương thích model String; cách chuyển dữ liệu mock/seed và ID liên kết.
3. Chọn representation cho đặt nhiều giờ (slot cố định + booking-slot relation, hay khoảng thời gian persisted) và chiến lược transaction ngăn overlap đồng thời.
4. Chốt trạng thái booking/payment và slot cho booking mới, cash, online success/failure/retry, hết hạn giữ slot, hoàn thành và hủy.
5. Chốt mô hình payment attempts, reference payment trong Booking, transaction code/idempotency và quyền xác nhận thu cash.
6. Chốt promotion: ngày bắt đầu/kết thúc, min order, max discount, base tính giảm, làm tròn, giới hạn lượt toàn cục hay từng người, thời điểm tiêu thụ lượt và điều kiện hoàn lượt.
7. Chốt đơn vị tiền/làm tròn (`REAL` hiện tại hay integer VND) và sửa CHECK tổng tiền để không dựa vào equality floating-point nếu cần.
8. Chốt chính sách hủy/refund, thời hạn hủy và cách biểu diễn refund mô phỏng; status nào chiếm slot.
9. Chốt chiến lược cutover MockStore: một lần theo toàn booking domain hay adapter/nhóm màn có nguồn sự thật duy nhất; nơi inject async repositories và quy tắc seed development.
10. Xác nhận nguồn/encoding của `database.sql`, seed dùng khởi tạo hay chỉ minh họa; thống nhất version schema hiện tại và nơi lưu migration.

## 9. Kế hoạch chuyển đổi và regression tests đề xuất

### Kế hoạch

1. Nhóm duyệt contract, schema, state machine và data mapping; đối chiếu thay đổi schema với người phụ trách database.
2. Tạo initializer/version/migration và database factory test theo kiến trúc chung; kiểm tra foreign keys và import seed tách biệt.
3. Implement repositories/adapters theo contract, không để UI truy cập SQL. Bắt đầu với đọc venue/services/slots và booking history, sau đó transaction tạo booking/payment, cuối cùng hủy/owner management.
4. Chuyển một workflow đầy đủ sang repository và chỉ dùng một nguồn dữ liệu cho workflow đó. Giữ MockStore/adapter cho phần chưa chuyển đúng chiến lược nhóm, tránh dual writes.
5. Kiểm tra khởi động lại database và nâng version từ fixture cũ; chỉ sau đó mới tuyên bố persistence đã hoàn tất.

### Regression test tối thiểu

- Tạo DB mới đúng schema/version, foreign key bật; migration cũ → mới giữ nguyên booking/payment và đọc được booking legacy không có booking services.
- Venue/service/slot/booking/payment/history đọc lại sau khi đóng và mở DB mới; owner và customer query đúng quyền/tập dữ liệu.
- Tính tiền theo duration, nhiều service quantity, promotion min/max/start/end/limit, làm tròn; repository từ chối tổng tiền client giả mạo.
- Khoảng liền kề được nhận; overlap một phần/bao trùm/cùng giờ bị từ chối; booking cancelled không giữ slot, booking active và blocked có giữ; hai request đồng thời chỉ một giao dịch thành công.
- Lỗi giả lập ở insert booking-service, payment, slot update hoặc promo increment làm rollback toàn bộ, không còn booking/payment dở dang hoặc counter sai.
- Cash bắt đầu pending/unpaid; chỉ thao tác thu tiền hợp lệ mới đổi paid; amount mismatch bị từ chối.
- Online success/failure/retry tạo attempt đúng; callback trùng không nhân đôi; thất bại không tạo trạng thái booking/payment mâu thuẫn.
- Hủy chưa thanh toán không refund; hủy đã trả đổi đúng payment/booking và slot; mọi lỗi giữa chừng rollback; hủy lặp không hoàn tiền/lượt promo lần nữa.
- Factory test cô lập dữ liệu giữa test, đóng được DB và chạy migration lặp theo version không phá dữ liệu.

## Nguồn đã đối chiếu và giới hạn

Đã đọc `assets/db/database.sql`, `pubspec.yaml`, các model `Booking`, `BookingService`, `Payment`, `TimeSlot`, `Promotion`, `Venue`, `VenueService`, các màn hình booking/payment/history và màn chủ sân, `MockStore`, cùng tài liệu `docs/gia_huy/README.md` và `docs/huong_dan/Tich_hop_ho_so_SQLite.md`. Tại thời điểm cập nhật này, source có `DatabaseHelper` và các repository SQLite như mô tả ở mục 1; các phần thiết kế còn lại vẫn cần nhóm duyệt. Diff và thay đổi source hiện hữu là công việc chưa commit trước tài liệu này và phải được giữ nguyên khi tích hợp sau.

Contract repository/SQLite của Quốc Đạt chưa được xác minh từ source hiện có. Vì vậy tài liệu không khẳng định schema cuối, initializer, migration API, transaction coordinator hay hướng tích hợp đã được nhóm duyệt.
