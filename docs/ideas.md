# 💡 Ideas & Vision - SaveMoney

## Mục tiêu
Xây dựng app quản lý chi tiêu cá nhân tương tự **Money Lover**, hỗ trợ Android & iOS.

## Core Features (Phase 1)
- [ ] Đăng nhập bằng Google
- [ ] Quản lý nhiều ví (tiền mặt, ngân hàng, ví điện tử...)
- [ ] Thêm giao dịch: Thu / Chi / Chuyển khoản
- [ ] Danh mục tùy chỉnh (icon, màu sắc)
- [ ] Lịch sử giao dịch theo ngày/tháng

## Advanced Features (Phase 2)
- [ ] Ngân sách (Budget) theo danh mục
- [ ] Báo cáo biểu đồ (ngày/tuần/tháng/năm)
- [ ] Nhắc nhở hóa đơn định kỳ
- [ ] Đa tiền tệ + quy đổi tỷ giá

## Premium Features (Phase 3)
- [ ] Xuất báo cáo PDF / Excel
- [ ] Ảnh chứng từ (Firebase Storage)
- [ ] Quản lý vay nợ

## Tech Decisions
- **Framework:** Flutter (Dart) - 1 code chạy Android + iOS
- **Backend:** Firebase (Auth + Firestore + Storage)
- **Offline:** Firestore Persistence (built-in)
- **State:** Riverpod
- **Charts:** fl_chart
- **Navigation:** Go Router
