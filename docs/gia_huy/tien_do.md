# Tiến độ phần Gia Huy

Cập nhật 07/10/2026. Phần code đã được triển khai sớm cho các ngày 05–08/10. Không thay thế việc kiểm tra thủ công trên thiết bị hoặc tài liệu/screenshot của thành viên khác.

| Ngày theo timeline | Công việc | Trạng thái hiện tại |
|---|---|---|
| 04/10 | Phân tích yêu cầu đủ 3 actor và nhóm tính năng mới, Use Case | Đã có phan_tich_yeu_cau.md và use_case.puml; cần đối chiếu đề bài chính thức và sơ đồ nhóm cung cấp trước khi chốt Word |
| 05/10 | Khung Flutter, theme và route | Đã có, bổ sung route Danh sách và kiểm tra role/arguments |
| 06/10 | Login/Register | Hoàn thành xác thực mock, validate, đăng ký, phiên và đăng xuất; 14 test tài khoản |
| 07/10 | Home + Danh sách sân | Hoàn thành danh sách approved, lọc môn, rỗng và mở Chi tiết |
| 08/10 sáng | Upload bằng image_picker, preview tối thiểu 3 ảnh | Hoàn thành chọn/preview/xóa/chống trùng path/validate/gửi pending; đã test picker thật trên emulator Android 17, hủy rồi chọn 3 ảnh và gửi duyệt |
| 08/10 chiều | Nối Navigator toàn bộ luồng | Đã nối và test luồng Customer/Owner/Admin; sửa Back Admin và ID sân cho dịch vụ |
| 09/10 | Tổng hợp Word + tham khảo | Đã viết nội dung phần Gia Huy, tham khảo và đối chiếu ERD/Sequence/Deployment đã nhận; còn Class Diagram và ảnh giao diện. Công cụ render Word hiện chưa có LibreOffice, nên chưa xuất bản Word đã kiểm tra bố cục |

## Kết quả kiểm tra

47 widget/unit test đã qua sau tích hợp nhánh Bảo Huy, analyzer sạch. Đã build/cài/chạy Android debug và chạy thành công 30 ca trên emulator Android 17/API 37: 14 auth, 15 model/booking/admin và 1 picker thật. Bộ widget test vẫn kiểm tra viewport 360 px trên máy tính. Picker hệ thống từng ANR, chạy lại sau khi khởi động emulator đã qua. Xem kiem_thu_android_20261007.md, review_baohuy.md và test_thu_cong.md. Chưa thử điện thoại thật; không ghi mặc định Pass cho thiết bị chưa chạy.

## File để học và nộp

- phan_tich_yeu_cau.md: nội dung phân tích dùng để ghép Word.
- use_case.puml: nguồn sơ đồ UML, mở bằng PlantUML hoặc đưa vào công cụ render tương thích.
- use_case.svg: hình Use Case tổng quan để xem và đưa vào báo cáo.
- test_thu_cong.md: kịch bản chạy bằng tay và kết quả mong đợi.
- hoc_code_va_van_dap.md: thứ tự đọc code, luồng dữ liệu, câu hỏi và bài tập.
- doi_chieu_so_do_nhom.md: khác biệt giữa ERD/Sequence/Deployment và bản demo; hình nguyên bản ở nguon_nhom.

## Phần nhóm cần đối chiếu trước báo cáo

Thanh toán đã ghi Booking cùng Payment mock và phương thức, kiểm tra lại lịch trước khi xác nhận; Booking kiểm tra giờ quá khứ/trùng lịch/giờ mở cửa; Chi tiết và Admin đọc ảnh picker/URL. Hồ sơ vẫn lưu mô phỏng; SQL chỉ có 7 bảng và app chưa load JSON/SQLite, chưa tích hợp Maps/thanh toán thật. Class Diagram và screenshot chưa có trong nhánh Bảo Huy đã gửi. Phần Word ngày 09/10 vẫn cần các tài liệu này và công cụ render để kiểm tra bố cục.
