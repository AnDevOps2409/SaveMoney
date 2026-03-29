import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:savemoney/features/auth/data/auth_service.dart';

// ===== Auth State Provider =====
final authStateProvider = StreamProvider<User?>((ref) {
  return AuthService.userStream;
});

// ===== Convenience: current user provider =====
final currentUserProvider = Provider<User?>((ref) {
  return ref.watch(authStateProvider).valueOrNull;
});

final isLoggedInProvider = Provider<bool>((ref) {
  return ref.watch(currentUserProvider) != null;
});
