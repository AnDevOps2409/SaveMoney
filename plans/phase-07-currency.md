# Phase 07: Multi-currency
Status: ⬜ Pending
Dependencies: Phase 03

## Objective
Hỗ trợ nhiều tiền tệ và quy đổi tỷ giá tự động.

## Implementation Steps
1. [ ] Thêm trường `currency` vào Wallet model
2. [ ] Tích hợp API tỷ giá (exchangerate-api.com - free tier)
3. [ ] Cache tỷ giá vào Firestore (refresh hàng ngày)
4. [ ] Hiển thị số dư ví theo đúng tiền tệ
5. [ ] Dashboard tổng hợp: quy đổi tất cả về VND
6. [ ] Settings: chọn tiền tệ mặc định

## Test Criteria
- [ ] Ví USD hiển thị $ đúng định dạng
- [ ] dashboard quy đổi ra VND chính xác

---
Next Phase: [phase-08-premium.md](./phase-08-premium.md)
