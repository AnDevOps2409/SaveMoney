# Phase 06: Budget & Reminder
Status: ⬜ Pending
Dependencies: Phase 05

## Objective
Tính năng ngân sách (budget) và nhắc nhở hóa đơn định kỳ.

## Implementation Steps
### Budget
1. [ ] Budget model + Firestore CRUD
2. [ ] Tạo ngân sách: chọn category, số tiền giới hạn, kỳ (tháng)
3. [ ] Màn hình danh sách budget (progress bar mỗi budget)
4. [ ] Cảnh báo khi chi tiêu > 80% ngân sách
5. [ ] Cảnh báo khi vượt ngân sách

### Reminder (Nhắc nhở hóa đơn)
6. [ ] Reminder model + Firestore CRUD
7. [ ] Tạo nhắc nhở: tên, số tiền, tần suất (hàng tuần/tháng), ngày
8. [ ] Local notification (flutter_local_notifications)
9. [ ] Màn hình danh sách nhắc nhở sắp tới

## Test Criteria
- [ ] Tạo budget 1 triệu cho "Ăn uống" → chi 900k → hiện cảnh báo
- [ ] Nhắc nhở tiền điện ngày 15 hàng tháng → notification đúng giờ

---
Next Phase: [phase-07-currency.md](./phase-07-currency.md)
