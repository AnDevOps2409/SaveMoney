# Phase 02: Auth & Navigation Shell
Status: ⬜ Pending
Dependencies: Phase 01

## Objective
Xây dựng màn hình đăng nhập Google và navigation shell (bottom nav bar) chính.

## Implementation Steps
1. [ ] Tạo AuthRepository (Riverpod) - wrap Firebase Auth
2. [ ] Màn hình Splash (kiểm tra user đã đăng nhập chưa)
3. [ ] Màn hình Login (nút "Đăng nhập bằng Google")
4. [ ] Cấu hình Go Router với auth guard
5. [ ] Tạo MainShell với Bottom Navigation Bar (4 tab)
6. [ ] Placeholder screens cho: Home, Transactions, Reports, Settings

## Màn hình & Navigation
```
SplashScreen
  ├── (chưa login) → LoginScreen
  └── (đã login) → MainShell
        ├── Tab 1: HomeScreen (Dashboard)
        ├── Tab 2: TransactionsScreen
        ├── Tab 3: ReportsScreen
        └── Tab 4: SettingsScreen
```

## Files to Create
- `lib/features/auth/` - Auth feature
- `lib/features/home/` - Dashboard placeholder
- `lib/core/router/app_router.dart` - Go Router config

## Test Criteria
- [ ] Đăng nhập Google thành công (Android + iOS)
- [ ] Sau login → vào MainShell
- [ ] Logout → về LoginScreen
- [ ] Bottom nav chuyển tab mượt

---
Next Phase: [phase-03-wallet.md](./phase-03-wallet.md)
