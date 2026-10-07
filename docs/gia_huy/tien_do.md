# Tiến độ phần Gia Huy

Cập nhật 07/10/2026. Phần code đã được triển khai sớm cho các ngày 05–08/10. Không thay thế việc kiểm tra thủ công trên thiết bị hoặc tài liệu/screenshot của thành viên khác.

| Ngày theo timeline | Công việc | Trạng thái hiện tại |
|---|---|---|
| 04/10 | Phân tích yêu cầu đủ 3 actor và nhóm tính năng mới, Use Case | Đã có phan_tich_yeu_cau.md và use_case.puml; cần đối chiếu đề bài chính thức và sơ đồ nhóm cung cấp trước khi chốt Word |
| 05/10 | Khung Flutter, theme và route | Đã có, bổ sung route Danh sách và kiểm tra role/arguments |
| 06/10 | Login/Register | Hoàn thành xác thực mock, validate, đăng ký, phiên và đăng xuất; 14 test tài khoản |
| 07/10 | Home + Danh sách sân | Hoàn thành danh sách approved, lọc môn, rỗng và mở Chi tiết |
| 08/10 sáng | Upload bằng image_picker, preview tối thiểu 3 ảnh | Hoàn thành chọn/preview/xóa/chống trùng path/validate/gửi pending; chưa test picker native bằng tay |
| 08/10 chiều | Nối Navigator toàn bộ luồng | Đã nối và test luồng Customer/Owner/Admin; sửa Back Admin và ID sân cho dịch vụ |
| 09/10 | Tổng hợp Word + tham khảo | Đã viết nội dung phần Gia Huy, tham khảo và đối chiếu ERD/Sequence/Deployment đã nhận; còn Class Diagram và ảnh giao diện. Công cụ render Word hiện chưa có LibreOffice, nên chưa xuất bản Word đã kiểm tra bố cục |

## Kết quả kiểm tra

30 widget tests đã qua, Dart analyzer sạch và `flutter build web --no-pub` thành công trên máy phát triển Flutter 3.47.4 / Dart 3.13.3. Xem test_thu_cong.md để chạy các ca thực tế. Chưa chạy picker native trên thiết bị; không ghi mặc định Pass cho thiết bị chưa chạy.

## File để học và nộp

- phan_tich_yeu_cau.md: nội dung phân tích dùng để ghép Word.
- use_case.puml: nguồn sơ đồ UML, mở bằng PlantUML hoặc đưa vào công cụ render tương thích.
- use_case.svg: hình Use Case tổng quan để xem và đưa vào báo cáo.
- test_thu_cong.md: kịch bản chạy bằng tay và kết quả mong đợi.
- hoc_code_va_van_dap.md: thứ tự đọc code, luồng dữ liệu, câu hỏi và bài tập.
- doi_chieu_so_do_nhom.md: khác biệt giữa ERD/Sequence/Deployment và bản demo; hình nguyên bản ở nguon_nhom.

## Phần nhóm cần đối chiếu trước báo cáo

Thanh toán hiện chưa ghi Payment/phương thức riêng; hồ sơ chỉ thông báo lưu mô phỏng; JSON/SQL khác model Dart; booking chưa kiểm tra trùng lịch; card/detail chưa hiển thị ảnh upload. Không ghi các phần này đã hoàn chỉnh trong Word. Các thay đổi hiện nằm trong workspace, chưa được commit/push trong lượt này.
