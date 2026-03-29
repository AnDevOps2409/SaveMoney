# Design Specifications - SaveMoney

## 🎨 Color Palette

| Tên | Hex | Dùng cho |
|-----|-----|----------|
| Primary Green | `#2ECC71` | Buttons, active states, highlights |
| Primary Dark | `#27AE60` | Hover, gradient, card background |
| Success | `#2ECC71` | Thu nhập (income), positive amounts |
| Danger | `#E74C3C` | Chi tiêu (expense), negative amounts |
| Background | `#F8F9FA` | Màn hình chính |
| Surface | `#FFFFFF` | Cards, modals, inputs |
| Border | `#E9ECEF` | Dividers, input borders |
| Text Primary | `#1A1A2E` | Tiêu đề, số tiền |
| Text Secondary | `#6C757D` | Labels, mô tả phụ |
| Text Muted | `#ADB5BD` | Placeholder, disabled |

## 📝 Typography
| Element | Size | Weight | Dùng cho |
|---------|------|--------|----------|
| H1 | 28sp | 700 Bold | Số dư tổng |
| H2 | 22sp | 600 SemiBold | Tiêu đề màn hình |
| H3 | 18sp | 600 SemiBold | Section titles |
| Body | 16sp | 400 Regular | Nội dung chính |
| Caption | 13sp | 400 Regular | Ngày tháng, ghi chú |
| Amount | 32sp | 700 Bold | Số tiền lớn |

Font: **Inter** (Google Fonts)

## 📐 Spacing
| Tên | Value | Dùng cho |
|-----|-------|----------|
| xs | 4dp | Icon gap |
| sm | 8dp | Tight |
| md | 16dp | Default padding |
| lg | 24dp | Section gap |
| xl | 32dp | Large sections |

## 🔲 Border Radius
| Element | Radius |
|---------|--------|
| Cards | 16dp |
| Buttons lớn | 12dp |
| Buttons nhỏ/pills | 24dp (full) |
| Input fields | 10dp |
| Category icons | 50% (circle) |
| Wallet cards | 16dp |

## 🌫️ Shadows (Flutter BoxShadow)
```dart
// Card shadow
BoxShadow(
  color: Colors.black.withOpacity(0.06),
  blurRadius: 12,
  offset: Offset(0, 4),
)

// Bottom nav shadow
BoxShadow(
  color: Colors.black.withOpacity(0.08),
  blurRadius: 20,
  offset: Offset(0, -2),
)
```

## 📱 Màn hình chính (Screens)

### 1. Dashboard (Home)
- Green gradient header card: `#27AE60 → #2ECC71`
- 4 quick-action circle buttons
- Recent transactions list (group by date)
- Bottom nav: Home | Giao dịch | Báo cáo | Cài đặt

### 2. Add Transaction
- 3 tab: Chi tiêu | Thu nhập | Chuyển khoản
- Custom numeric keypad
- Category grid (3 cột)
- Form fields: Ngày, Ví, Ghi chú, Ảnh

### 3. Reports
- Period tabs: Ngày | Tuần | Tháng | Năm
- Bar chart (fl_chart)
- Donut pie chart (fl_chart)
- Category breakdown list

### 4. Wallet
- Danh sách ví với màu accent border
- Total balance header
- Add wallet button

## ✨ Animations (Flutter)
| Action | Duration | Curve |
|--------|----------|-------|
| Tab switch | 200ms | easeInOut |
| Page transition | 300ms | easeInOut |
| FAB tap | 150ms | easeOut |
| Number keypad | 100ms | easeOut |
| Skeleton shimmer | 1200ms | linear loop |

## 🦴 Skeleton Loading
Dùng `shimmer` package, màu:
- Base: `#E9ECEF`
- Highlight: `#F8F9FA`
