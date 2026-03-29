import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:savemoney/core/constants/app_colors.dart';
import 'package:savemoney/features/transaction/presentation/screens/add_transaction_screen.dart';

class MainShell extends StatelessWidget {
  final Widget child;
  const MainShell({super.key, required this.child});

  int _getCurrentIndex(BuildContext context) {
    final location = GoRouterState.of(context).uri.path;
    if (location.startsWith('/home')) return 0;
    if (location.startsWith('/transactions')) return 1;
    if (location.startsWith('/savings')) return 2;
    if (location.startsWith('/budget')) return 3;
    if (location.startsWith('/wallet')) return 4;
    return 0;
  }

  void _openAddTransaction(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.92,
        maxChildSize: 0.98,
        minChildSize: 0.5,
        builder: (_, controller) => ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          child: const AddTransactionScreen(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentIndex = _getCurrentIndex(context);

    return Scaffold(
      backgroundColor: AppColors.background,
      extendBody: true,
      body: child,
      bottomNavigationBar: _BottomNavBar(
        currentIndex: currentIndex,
        onAddTap: () => _openAddTransaction(context),
      ),
    );
  }
}

// ===== NavBar Widget =====
class _BottomNavBar extends StatelessWidget {
  final int currentIndex;
  final VoidCallback onAddTap;

  const _BottomNavBar({required this.currentIndex, required this.onAddTap});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.surface.withAlpha(220),
            border: Border(
              top: BorderSide(color: AppColors.divider.withAlpha(40), width: 0.5),
            ),
          ),
          child: SafeArea(
            top: false,
            child: SizedBox(
              height: 64,
              child: Row(
                children: [
                  // Tab trái 1: Tổng quan
                  _NavItem(
                    icon: Icons.home_outlined,
                    activeIcon: Icons.home_filled,
                    label: 'Tổng quan',
                    isActive: currentIndex == 0,
                    onTap: () => context.go('/home'),
                  ),
                  // Tab trái 2: Giao dịch
                  _NavItem(
                    icon: Icons.receipt_long_outlined,
                    activeIcon: Icons.receipt_long,
                    label: 'Giao dịch',
                    isActive: currentIndex == 1,
                    onTap: () => context.go('/transactions'),
                  ),
                  // Nút Thêm ở giữa — rộng hơn, chứa FAB nhô lên
                  _AddButton(onTap: onAddTap),
                  // Tab phải 1: Tiết kiệm
                  _NavItem(
                    imagePath: 'assets/images/pig_0.png',
                    label: 'Tiết kiệm',
                    isActive: currentIndex == 2,
                    onTap: () => context.go('/savings'),
                  ),
                  // Tab phải 2: Ngân sách
                  _NavItem(
                    icon: Icons.pie_chart_outline,
                    activeIcon: Icons.pie_chart,
                    label: 'Ngân sách',
                    isActive: currentIndex == 3,
                    onTap: () => context.go('/budget'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ===== Nút + ở giữa nhô lên =====
class _AddButton extends StatelessWidget {
  final VoidCallback onTap;
  const _AddButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 72,
      child: Center(
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppColors.primary, Color(0xFF00A846)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withAlpha(100),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: const Icon(Icons.add_rounded, color: Colors.white, size: 32),
          ),
        ),
      ),
    );
  }
}

// ===== Tab item =====
class _NavItem extends StatelessWidget {
  final IconData? icon;
  final IconData? activeIcon;
  final String? imagePath;
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  const _NavItem({
    this.icon,
    this.activeIcon,
    this.imagePath,
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    const activeColor = AppColors.primary;
    const inactiveColor = AppColors.textMuted;

    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedScale(
              scale: isActive ? 1.15 : 1.0,
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeOutBack,
              child: imagePath != null
                  ? Image.asset(
                      imagePath!,
                      width: 26,
                      height: 26,
                      color: isActive ? const Color(0xFFFFD700) : inactiveColor,
                    )
                  : Icon(
                      isActive ? activeIcon : icon,
                      size: 26,
                      color: isActive ? activeColor : inactiveColor,
                    ),
            ),
            const SizedBox(height: 3),
            AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 200),
              style: TextStyle(
                color: isActive ? activeColor : inactiveColor,
                fontSize: 10,
                letterSpacing: 0.2,
                fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
              ),
              child: Text(label),
            ),
          ],
        ),
      ),
    );
  }
}
