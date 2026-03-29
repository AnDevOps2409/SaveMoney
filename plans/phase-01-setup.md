# Phase 01: Project Setup & Firebase Config
Status: ⬜ Pending
Dependencies: Không có

## Objective
Tạo Flutter project mới, cấu hình Firebase, cài các package cần thiết.

## Implementation Steps
1. [ ] Tạo Flutter project: `flutter create savemoney`
2. [ ] Cấu hình Firebase project trên console.firebase.google.com
3. [ ] Cài FlutterFire CLI và chạy `flutterfire configure`
4. [ ] Thêm các packages vào pubspec.yaml
5. [ ] Bật Firestore offline persistence trong main.dart
6. [ ] Tạo folder structure theo feature-first
7. [ ] Setup theme (màu sắc, font chữ)
8. [ ] Commit lần đầu

## Packages cần cài
```yaml
firebase_core, firebase_auth, cloud_firestore,
firebase_storage, google_sign_in,
flutter_riverpod, go_router,
fl_chart, iconsax_flutter, intl, connectivity_plus
```

## Files to Create
- `lib/main.dart` - Entry point + Firebase init
- `lib/core/theme/app_theme.dart` - Theme toàn app
- `lib/core/constants/app_colors.dart` - Màu sắc
- `pubspec.yaml` - Dependencies

## Test Criteria
- [ ] App chạy được trên Android Emulator
- [ ] App chạy được trên iOS Simulator
- [ ] Firebase kết nối thành công (không có lỗi console)

---
Next Phase: [phase-02-auth.md](./phase-02-auth.md)
