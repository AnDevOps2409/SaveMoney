import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:savemoney/core/constants/app_colors.dart';
import 'package:savemoney/features/auth/domain/auth_provider.dart';

class SplashScreen extends ConsumerWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen<AsyncValue<dynamic>>(authStateProvider, (_, next) {
      if (!next.isLoading) {
        final isLoggedIn = next.valueOrNull != null;
        context.go(isLoggedIn ? '/home' : '/login');
      }
    });

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Logo / Icon
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: AppColors.primary.withAlpha(25),
                borderRadius: BorderRadius.circular(30),
                border: Border.all(color: AppColors.primary.withAlpha(60), width: 1.5),
              ),
              child: const Center(
                child: Text('💰', style: TextStyle(fontSize: 52)),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'SaveMoney',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Quản lý tài chính thông minh',
              style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 60),
            SizedBox(
              width: 32,
              height: 32,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                color: AppColors.primary.withAlpha(200),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
