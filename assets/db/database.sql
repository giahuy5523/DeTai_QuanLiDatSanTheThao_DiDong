PRAGMA foreign_keys = ON;

CREATE TABLE Users (
  user_id INTEGER PRIMARY KEY AUTOINCREMENT,
  full_name TEXT NOT NULL,
  email TEXT NOT NULL UNIQUE,
  phone TEXT UNIQUE,
  password_hash TEXT NOT NULL,
  role TEXT NOT NULL DEFAULT 'customer' CHECK (role IN ('customer','owner','admin')),
  avatar_url TEXT,
  is_active INTEGER NOT NULL DEFAULT 1,
  created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
);
CREATE TABLE SportTypes (
  sport_type_id INTEGER PRIMARY KEY AUTOINCREMENT,
  name TEXT NOT NULL UNIQUE,
  description TEXT,
  icon TEXT
);
CREATE TABLE Venues (
  venue_id INTEGER PRIMARY KEY AUTOINCREMENT,
  owner_id INTEGER NOT NULL REFERENCES Users(user_id),
  sport_type_id INTEGER NOT NULL REFERENCES SportTypes(sport_type_id),
  name TEXT NOT NULL,
  address TEXT NOT NULL,
  district TEXT,
  city TEXT,
  description TEXT,
  price_per_hour REAL NOT NULL CHECK (price_per_hour >= 0),
  open_time TEXT NOT NULL,
  close_time TEXT NOT NULL,
  image_url TEXT,
  status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending','approved','rejected')),
  reject_reason TEXT,
  reviewed_by INTEGER REFERENCES Users(user_id),
  reviewed_at TEXT,
  created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
);
CREATE TABLE TimeSlots (
  slot_id INTEGER PRIMARY KEY AUTOINCREMENT,
  venue_id INTEGER NOT NULL REFERENCES Venues(venue_id) ON DELETE CASCADE,
  slot_date TEXT NOT NULL,
  start_time TEXT NOT NULL,
  end_time TEXT NOT NULL,
  price REAL NOT NULL,
  status TEXT NOT NULL DEFAULT 'available' CHECK (status IN ('available','booked','blocked')),
  UNIQUE (venue_id, slot_date, start_time)
);
CREATE TABLE Promotions (
  promo_id INTEGER PRIMARY KEY AUTOINCREMENT,
  code TEXT NOT NULL UNIQUE,
  description TEXT,
  discount_percent INTEGER NOT NULL CHECK (discount_percent BETWEEN 1 AND 100),
  max_discount_amount REAL,
  min_order_amount REAL NOT NULL DEFAULT 0,
  start_date TEXT NOT NULL,
  end_date TEXT NOT NULL,
  usage_limit INTEGER,
  used_count INTEGER NOT NULL DEFAULT 0,
  status TEXT NOT NULL DEFAULT 'active' CHECK (status IN ('active','inactive')),
  created_by INTEGER REFERENCES Users(user_id)
);
CREATE TABLE Bookings (
  booking_id INTEGER PRIMARY KEY AUTOINCREMENT,
  user_id INTEGER NOT NULL REFERENCES Users(user_id),
  slot_id INTEGER NOT NULL REFERENCES TimeSlots(slot_id),
  promo_id INTEGER REFERENCES Promotions(promo_id),
  original_amount REAL NOT NULL,
  discount_amount REAL NOT NULL DEFAULT 0,
  total_amount REAL NOT NULL,
  status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending','confirmed','cancelled','completed')),
  payment_status TEXT NOT NULL DEFAULT 'unpaid' CHECK (payment_status IN ('unpaid','paid','refunded')),
  note TEXT,
  cancel_reason TEXT,
  created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
  cancelled_at TEXT
);
CREATE TABLE Payments (
  payment_id INTEGER PRIMARY KEY AUTOINCREMENT,
  booking_id INTEGER NOT NULL REFERENCES Bookings(booking_id),
  method TEXT NOT NULL CHECK (method IN ('cash','momo','vnpay','bank_transfer')),
  amount REAL NOT NULL,
  status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending','success','failed','refunded')),
  transaction_code TEXT UNIQUE,
  paid_at TEXT,
  created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
);
CREATE INDEX idx_slots_venue_date ON TimeSlots(venue_id, slot_date);
CREATE INDEX idx_bookings_user ON Bookings(user_id);
CREATE INDEX idx_payments_booking ON Payments(booking_id);

INSERT INTO Users(user_id,full_name,email,phone,password_hash,role,avatar_url,is_active,created_at) VALUES(1,'Quản trị viên','admin@sanvn.com','0900000001','e86f78a8a3caf0b60d8e74e5942aa6d86dc150cd3c03338aef25b7d2d7e3acc7','admin',NULL,1,'2026-09-01 08:00:00');
INSERT INTO Users(user_id,full_name,email,phone,password_hash,role,avatar_url,is_active,created_at) VALUES(2,'Lê Văn Chủ Sân','owner1@sanvn.com','0900000002','553feacf899a72916b2b50e4c95f587a06d6d1b8b4e6b433beb5fea315d0acb0','owner',NULL,1,'2026-09-02 09:00:00');
INSERT INTO Users(user_id,full_name,email,phone,password_hash,role,avatar_url,is_active,created_at) VALUES(3,'Phạm Thị Hoa','owner2@sanvn.com','0900000003','553feacf899a72916b2b50e4c95f587a06d6d1b8b4e6b433beb5fea315d0acb0','owner',NULL,1,'2026-09-02 09:30:00');
INSERT INTO Users(user_id,full_name,email,phone,password_hash,role,avatar_url,is_active,created_at) VALUES(4,'Nguyễn Hoàng Gia Huy','huy@gmail.com','0911000001','3e7c19576488862816f13b512cacf3e4ba97dd97243ea0bd6a2ad1642d86ba72','customer',NULL,1,'2026-09-10 10:00:00');
INSERT INTO Users(user_id,full_name,email,phone,password_hash,role,avatar_url,is_active,created_at) VALUES(5,'Nguyễn Quốc Đạt','dat@gmail.com','0911000002','3e7c19576488862816f13b512cacf3e4ba97dd97243ea0bd6a2ad1642d86ba72','customer',NULL,1,'2026-09-10 10:05:00');
INSERT INTO Users(user_id,full_name,email,phone,password_hash,role,avatar_url,is_active,created_at) VALUES(6,'Nguyễn Đình Bảo Huy','baohuy@gmail.com','0911000003','3e7c19576488862816f13b512cacf3e4ba97dd97243ea0bd6a2ad1642d86ba72','customer',NULL,1,'2026-09-11 11:00:00');
INSERT INTO Users(user_id,full_name,email,phone,password_hash,role,avatar_url,is_active,created_at) VALUES(7,'Trần Thanh Sơn','son@gmail.com','0911000004','3e7c19576488862816f13b512cacf3e4ba97dd97243ea0bd6a2ad1642d86ba72','customer',NULL,1,'2026-09-11 11:10:00');
INSERT INTO Users(user_id,full_name,email,phone,password_hash,role,avatar_url,is_active,created_at) VALUES(8,'Võ Minh Anh','minhanh@gmail.com','0911000005','3e7c19576488862816f13b512cacf3e4ba97dd97243ea0bd6a2ad1642d86ba72','customer',NULL,1,'2026-09-15 14:00:00');
INSERT INTO Users(user_id,full_name,email,phone,password_hash,role,avatar_url,is_active,created_at) VALUES(9,'Đặng Quốc Bình (bị khóa)','binh@gmail.com','0911000006','3e7c19576488862816f13b512cacf3e4ba97dd97243ea0bd6a2ad1642d86ba72','customer',NULL,0,'2026-09-16 15:00:00');
INSERT INTO SportTypes(sport_type_id,name,description,icon) VALUES(1,'Bóng đá mini','Sân cỏ nhân tạo 5-7 người','soccer');
INSERT INTO SportTypes(sport_type_id,name,description,icon) VALUES(2,'Cầu lông','Sân cầu lông trong nhà','badminton');
INSERT INTO SportTypes(sport_type_id,name,description,icon) VALUES(3,'Tennis','Sân tennis ngoài trời','tennis');
INSERT INTO SportTypes(sport_type_id,name,description,icon) VALUES(4,'Bóng rổ','Sân bóng rổ','basketball');
INSERT INTO SportTypes(sport_type_id,name,description,icon) VALUES(5,'Pickleball','Sân pickleball','pickleball');
INSERT INTO Venues(venue_id,owner_id,sport_type_id,name,address,district,city,description,price_per_hour,open_time,close_time,image_url,status,reject_reason,reviewed_by,reviewed_at,created_at) VALUES(1,2,1,'Sân bóng Thống Nhất','12 Lê Văn Việt','Quận 9','TP.HCM','Sân bóng Thống Nhất - mặt sân chất lượng, có bãi giữ xe',300000.0,'06:00','22:00','https://picsum.photos/seed/venueNhất/600/400','approved',NULL,1,'2026-09-20 09:00:00','2026-09-18 09:00:00');
INSERT INTO Venues(venue_id,owner_id,sport_type_id,name,address,district,city,description,price_per_hour,open_time,close_time,image_url,status,reject_reason,reviewed_by,reviewed_at,created_at) VALUES(2,2,1,'Sân bóng Phú Nhuận','45 Nguyễn Kiệm','Phú Nhuận','TP.HCM','Sân bóng Phú Nhuận - mặt sân chất lượng, có bãi giữ xe',350000.0,'06:00','22:00','https://picsum.photos/seed/venuehuận/600/400','approved',NULL,1,'2026-09-20 09:00:00','2026-09-18 09:00:00');
INSERT INTO Venues(venue_id,owner_id,sport_type_id,name,address,district,city,description,price_per_hour,open_time,close_time,image_url,status,reject_reason,reviewed_by,reviewed_at,created_at) VALUES(3,3,2,'Cầu lông Tân Bình','88 Cộng Hòa','Tân Bình','TP.HCM','Cầu lông Tân Bình - mặt sân chất lượng, có bãi giữ xe',120000.0,'06:00','22:00','https://picsum.photos/seed/venueBình/600/400','approved',NULL,1,'2026-09-20 09:00:00','2026-09-18 09:00:00');
INSERT INTO Venues(venue_id,owner_id,sport_type_id,name,address,district,city,description,price_per_hour,open_time,close_time,image_url,status,reject_reason,reviewed_by,reviewed_at,created_at) VALUES(4,3,3,'Tennis Thảo Điền','7 Xuân Thủy','Thủ Đức','TP.HCM','Tennis Thảo Điền - mặt sân chất lượng, có bãi giữ xe',250000.0,'06:00','21:00','https://picsum.photos/seed/venueĐiền/600/400','approved',NULL,1,'2026-09-20 09:00:00','2026-09-18 09:00:00');
INSERT INTO Venues(venue_id,owner_id,sport_type_id,name,address,district,city,description,price_per_hour,open_time,close_time,image_url,status,reject_reason,reviewed_by,reviewed_at,created_at) VALUES(5,2,4,'Bóng rổ Quận 7','21 Nguyễn Thị Thập','Quận 7','TP.HCM','Bóng rổ Quận 7 - mặt sân chất lượng, có bãi giữ xe',200000.0,'07:00','21:00','https://picsum.photos/seed/venueận 7/600/400','approved',NULL,1,'2026-09-20 09:00:00','2026-09-18 09:00:00');
INSERT INTO Venues(venue_id,owner_id,sport_type_id,name,address,district,city,description,price_per_hour,open_time,close_time,image_url,status,reject_reason,reviewed_by,reviewed_at,created_at) VALUES(6,3,5,'Pickleball Gò Vấp','190 Quang Trung','Gò Vấp','TP.HCM','Pickleball Gò Vấp - mặt sân chất lượng, có bãi giữ xe',150000.0,'06:00','22:00','https://picsum.photos/seed/venueVấp/600/400','pending',NULL,NULL,NULL,'2026-09-18 09:00:00');
INSERT INTO Venues(venue_id,owner_id,sport_type_id,name,address,district,city,description,price_per_hour,open_time,close_time,image_url,status,reject_reason,reviewed_by,reviewed_at,created_at) VALUES(7,2,2,'Cầu lông Bình Thạnh','33 Bạch Đằng','Bình Thạnh','TP.HCM','Cầu lông Bình Thạnh - mặt sân chất lượng, có bãi giữ xe',100000.0,'06:00','22:00','https://picsum.photos/seed/venuehạnh/600/400','rejected','Thiếu giấy phép kinh doanh và hình ảnh sân',1,'2026-09-20 09:00:00','2026-09-18 09:00:00');
INSERT INTO TimeSlots(slot_id,venue_id,slot_date,start_time,end_time,price,status) VALUES(1,1,'2026-09-28','18:00','19:00',360000.0,'booked');
INSERT INTO TimeSlots(slot_id,venue_id,slot_date,start_time,end_time,price,status) VALUES(2,3,'2026-09-29','19:00','20:00',144000.0,'booked');
INSERT INTO TimeSlots(slot_id,venue_id,slot_date,start_time,end_time,price,status) VALUES(3,4,'2026-09-30','17:00','18:00',300000.0,'booked');
INSERT INTO TimeSlots(slot_id,venue_id,slot_date,start_time,end_time,price,status) VALUES(4,2,'2026-10-02','18:00','19:00',420000.0,'available');
INSERT INTO TimeSlots(slot_id,venue_id,slot_date,start_time,end_time,price,status) VALUES(5,5,'2026-10-03','19:00','20:00',240000.0,'booked');
INSERT INTO TimeSlots(slot_id,venue_id,slot_date,start_time,end_time,price,status) VALUES(6,1,'2026-10-06','18:00','19:00',360000.0,'booked');
INSERT INTO TimeSlots(slot_id,venue_id,slot_date,start_time,end_time,price,status) VALUES(7,1,'2026-10-06','19:00','20:00',360000.0,'booked');
INSERT INTO TimeSlots(slot_id,venue_id,slot_date,start_time,end_time,price,status) VALUES(8,3,'2026-10-07','20:00','21:00',144000.0,'booked');
INSERT INTO TimeSlots(slot_id,venue_id,slot_date,start_time,end_time,price,status) VALUES(9,4,'2026-10-08','17:00','18:00',300000.0,'booked');
INSERT INTO TimeSlots(slot_id,venue_id,slot_date,start_time,end_time,price,status) VALUES(10,2,'2026-10-09','19:00','20:00',420000.0,'booked');
INSERT INTO TimeSlots(slot_id,venue_id,slot_date,start_time,end_time,price,status) VALUES(11,5,'2026-10-10','18:00','19:00',240000.0,'booked');
INSERT INTO TimeSlots(slot_id,venue_id,slot_date,start_time,end_time,price,status) VALUES(12,2,'2026-10-11','17:00','18:00',420000.0,'available');
INSERT INTO TimeSlots(slot_id,venue_id,slot_date,start_time,end_time,price,status) VALUES(13,1,'2026-10-06','17:00','18:00',360000.0,'available');
INSERT INTO TimeSlots(slot_id,venue_id,slot_date,start_time,end_time,price,status) VALUES(14,1,'2026-10-06','20:00','21:00',360000.0,'available');
INSERT INTO TimeSlots(slot_id,venue_id,slot_date,start_time,end_time,price,status) VALUES(15,3,'2026-10-07','19:00','20:00',144000.0,'available');
INSERT INTO TimeSlots(slot_id,venue_id,slot_date,start_time,end_time,price,status) VALUES(16,3,'2026-10-07','18:00','19:00',144000.0,'available');
INSERT INTO TimeSlots(slot_id,venue_id,slot_date,start_time,end_time,price,status) VALUES(17,4,'2026-10-08','18:00','19:00',300000.0,'available');
INSERT INTO TimeSlots(slot_id,venue_id,slot_date,start_time,end_time,price,status) VALUES(18,2,'2026-10-09','18:00','19:00',420000.0,'available');
INSERT INTO TimeSlots(slot_id,venue_id,slot_date,start_time,end_time,price,status) VALUES(19,5,'2026-10-10','19:00','20:00',240000.0,'available');
INSERT INTO TimeSlots(slot_id,venue_id,slot_date,start_time,end_time,price,status) VALUES(20,1,'2026-10-07','06:00','07:00',300000.0,'blocked');
INSERT INTO Promotions(promo_id,code,description,discount_percent,max_discount_amount,min_order_amount,start_date,end_date,usage_limit,used_count,status,created_by) VALUES(1,'WELCOME10','Giảm 10% cho đơn đầu tiên',10,50000.0,100000.0,'2026-09-15','2026-12-31',100,3,'active',1);
INSERT INTO Promotions(promo_id,code,description,discount_percent,max_discount_amount,min_order_amount,start_date,end_date,usage_limit,used_count,status,created_by) VALUES(2,'WEEKEND20','Giảm 20% cuối tuần',20,80000.0,200000.0,'2026-10-01','2026-11-30',50,2,'active',1);
INSERT INTO Promotions(promo_id,code,description,discount_percent,max_discount_amount,min_order_amount,start_date,end_date,usage_limit,used_count,status,created_by) VALUES(3,'HETHAN5','Mã đã hết hạn (dùng để test)',5,20000.0,0.0,'2026-08-01','2026-09-14',10,3,'active',1);
INSERT INTO Promotions(promo_id,code,description,discount_percent,max_discount_amount,min_order_amount,start_date,end_date,usage_limit,used_count,status,created_by) VALUES(4,'TAMNGUNG','Mã đang bị tắt (dùng để test)',15,60000.0,0.0,'2026-09-01','2026-12-31',20,0,'inactive',1);
INSERT INTO Bookings(booking_id,user_id,slot_id,promo_id,original_amount,discount_amount,total_amount,status,payment_status,note,cancel_reason,created_at,cancelled_at) VALUES(1,4,1,NULL,360000.0,0.0,360000.0,'completed','paid',NULL,NULL,'2026-09-28 08:00:00',NULL);
INSERT INTO Bookings(booking_id,user_id,slot_id,promo_id,original_amount,discount_amount,total_amount,status,payment_status,note,cancel_reason,created_at,cancelled_at) VALUES(2,5,2,1,144000.0,14400.0,129600.0,'completed','paid',NULL,NULL,'2026-09-29 08:00:00',NULL);
INSERT INTO Bookings(booking_id,user_id,slot_id,promo_id,original_amount,discount_amount,total_amount,status,payment_status,note,cancel_reason,created_at,cancelled_at) VALUES(3,6,3,NULL,300000.0,0.0,300000.0,'completed','paid',NULL,NULL,'2026-09-30 08:00:00',NULL);
INSERT INTO Bookings(booking_id,user_id,slot_id,promo_id,original_amount,discount_amount,total_amount,status,payment_status,note,cancel_reason,created_at,cancelled_at) VALUES(4,7,4,NULL,420000.0,0.0,420000.0,'cancelled','refunded',NULL,'Khách bận việc đột xuất','2026-10-03 21:00:00','2026-10-01 20:00:00');
INSERT INTO Bookings(booking_id,user_id,slot_id,promo_id,original_amount,discount_amount,total_amount,status,payment_status,note,cancel_reason,created_at,cancelled_at) VALUES(5,8,5,1,240000.0,24000.0,216000.0,'completed','paid',NULL,NULL,'2026-10-03 08:00:00',NULL);
INSERT INTO Bookings(booking_id,user_id,slot_id,promo_id,original_amount,discount_amount,total_amount,status,payment_status,note,cancel_reason,created_at,cancelled_at) VALUES(6,4,6,2,360000.0,72000.0,288000.0,'confirmed','paid',NULL,NULL,'2026-10-03 21:00:00',NULL);
INSERT INTO Bookings(booking_id,user_id,slot_id,promo_id,original_amount,discount_amount,total_amount,status,payment_status,note,cancel_reason,created_at,cancelled_at) VALUES(7,5,7,NULL,360000.0,0.0,360000.0,'confirmed','paid',NULL,NULL,'2026-10-03 21:00:00',NULL);
INSERT INTO Bookings(booking_id,user_id,slot_id,promo_id,original_amount,discount_amount,total_amount,status,payment_status,note,cancel_reason,created_at,cancelled_at) VALUES(8,6,8,NULL,144000.0,0.0,144000.0,'confirmed','paid',NULL,NULL,'2026-10-03 21:00:00',NULL);
INSERT INTO Bookings(booking_id,user_id,slot_id,promo_id,original_amount,discount_amount,total_amount,status,payment_status,note,cancel_reason,created_at,cancelled_at) VALUES(9,7,9,NULL,300000.0,0.0,300000.0,'pending','unpaid',NULL,NULL,'2026-10-03 21:00:00',NULL);
INSERT INTO Bookings(booking_id,user_id,slot_id,promo_id,original_amount,discount_amount,total_amount,status,payment_status,note,cancel_reason,created_at,cancelled_at) VALUES(10,8,10,1,420000.0,42000.0,378000.0,'pending','unpaid',NULL,NULL,'2026-10-03 21:00:00',NULL);
INSERT INTO Bookings(booking_id,user_id,slot_id,promo_id,original_amount,discount_amount,total_amount,status,payment_status,note,cancel_reason,created_at,cancelled_at) VALUES(11,4,11,2,240000.0,48000.0,192000.0,'confirmed','paid',NULL,NULL,'2026-10-03 21:00:00',NULL);
INSERT INTO Bookings(booking_id,user_id,slot_id,promo_id,original_amount,discount_amount,total_amount,status,payment_status,note,cancel_reason,created_at,cancelled_at) VALUES(12,5,12,NULL,420000.0,0.0,420000.0,'cancelled','unpaid',NULL,'Khách bận việc đột xuất','2026-10-03 21:00:00','2026-10-01 20:00:00');
INSERT INTO Payments(payment_id,booking_id,method,amount,status,transaction_code,paid_at,created_at) VALUES(1,1,'momo',360000.0,'success','TXN1001','2026-10-03 21:05:00','2026-10-03 21:01:00');
INSERT INTO Payments(payment_id,booking_id,method,amount,status,transaction_code,paid_at,created_at) VALUES(2,2,'vnpay',129600.0,'success','TXN1002','2026-10-03 21:05:00','2026-10-03 21:01:00');
INSERT INTO Payments(payment_id,booking_id,method,amount,status,transaction_code,paid_at,created_at) VALUES(3,3,'cash',300000.0,'success',NULL,'2026-10-03 21:05:00','2026-10-03 21:01:00');
INSERT INTO Payments(payment_id,booking_id,method,amount,status,transaction_code,paid_at,created_at) VALUES(4,4,'momo',420000.0,'refunded','TXN1004','2026-10-03 21:05:00','2026-10-03 21:01:00');
INSERT INTO Payments(payment_id,booking_id,method,amount,status,transaction_code,paid_at,created_at) VALUES(5,5,'bank_transfer',216000.0,'success','TXN1005','2026-10-03 21:05:00','2026-10-03 21:01:00');
INSERT INTO Payments(payment_id,booking_id,method,amount,status,transaction_code,paid_at,created_at) VALUES(6,6,'vnpay',288000.0,'success','TXN1006','2026-10-03 21:05:00','2026-10-03 21:01:00');
INSERT INTO Payments(payment_id,booking_id,method,amount,status,transaction_code,paid_at,created_at) VALUES(7,7,'momo',360000.0,'success','TXN1007','2026-10-03 21:05:00','2026-10-03 21:01:00');
INSERT INTO Payments(payment_id,booking_id,method,amount,status,transaction_code,paid_at,created_at) VALUES(8,8,'cash',144000.0,'success',NULL,'2026-10-03 21:05:00','2026-10-03 21:01:00');
INSERT INTO Payments(payment_id,booking_id,method,amount,status,transaction_code,paid_at,created_at) VALUES(9,10,'vnpay',378000.0,'failed','TXN1009',NULL,'2026-10-03 21:01:00');
INSERT INTO Payments(payment_id,booking_id,method,amount,status,transaction_code,paid_at,created_at) VALUES(10,11,'bank_transfer',192000.0,'success','TXN1010','2026-10-03 21:05:00','2026-10-03 21:01:00');
