# Phase 03: Wallet & Category Management
Status: ⬜ Pending
Dependencies: Phase 02

## Objective
CRUD ví (wallet) và danh mục (category) - bộ xương của toàn bộ app.

## Implementation Steps
### Wallet
1. [ ] Wallet model + Firestore CRUD
2. [ ] Màn hình danh sách ví (số dư mỗi ví)
3. [ ] Form tạo/sửa ví (tên, loại ví, icon, số dư ban đầu, tiền tệ)
4. [ ] Màn hình chi tiết ví

### Category
5. [ ] Category model + Firestore CRUD
6. [ ] Seed dữ liệu mặc định (Ăn uống, Di chuyển, Mua sắm...)
7. [ ] Màn hình danh sách category (Thu/Chi riêng)
8. [ ] Form tạo/sửa category (tên, icon từ Iconsax, màu sắc)

## Loại ví
- 💵 Tiền mặt
- 🏦 Tài khoản ngân hàng
- 💳 Thẻ tín dụng
- 📱 Ví điện tử (Momo, ZaloPay...)

## Files to Create
- `lib/features/wallet/` - Wallet feature (model, repo, provider, screens)
- `lib/features/category/` - Category feature

## Test Criteria
- [ ] Tạo ví mới → lưu lên Firestore
- [ ] Sửa/xóa ví
- [ ] Tạo category tùy chỉnh với icon & màu
- [ ] Dữ liệu sync real-time giữa các thiết bị

---
Next Phase: [phase-04-transaction.md](./phase-04-transaction.md)
