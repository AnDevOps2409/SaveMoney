# Phase 04: Transactions (Thu / Chi / Chuyển khoản)
Status: ⬜ Pending
Dependencies: Phase 03

## Objective
Tính năng cốt lõi: thêm/sửa/xóa giao dịch thu, chi, chuyển khoản.

## Implementation Steps
1. [ ] Transaction model + Firestore CRUD
2. [ ] FAB "+ Thêm giao dịch" trên màn hình chính
3. [ ] Form thêm giao dịch:
   - Loại: Thu / Chi / Chuyển khoản
   - Số tiền (keypad số tiền đẹp)
   - Danh mục (picker với icon)
   - Ví (chọn ví nguồn)
   - Ngày giờ (date picker)
   - Ghi chú
4. [ ] Tự động cộng/trừ số dư ví sau khi thêm giao dịch
5. [ ] Màn hình lịch sử giao dịch (group by ngày)
6. [ ] Sửa / xóa giao dịch
7. [ ] Filter: theo ví, theo category, theo khoảng thời gian

## Test Criteria
- [ ] Thêm giao dịch chi → số dư ví giảm
- [ ] Thêm giao dịch thu → số dư ví tăng
- [ ] Chuyển khoản → ví A giảm, ví B tăng
- [ ] Offline: thêm giao dịch rồi bật mạng → tự sync

---
Next Phase: [phase-05-dashboard.md](./phase-05-dashboard.md)
