import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:savemoney/core/constants/app_constants.dart';

class AuthService {
  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static final GoogleSignIn googleSignIn = GoogleSignIn();
  static final FirebaseFirestore _db = FirebaseFirestore.instance;

  // Lưu Google credential để GoldService dùng cho secondary Firebase
  static OAuthCredential? lastGoogleCredential;

  // Stream user state
  static Stream<User?> get userStream => _auth.authStateChanges();

  // Current user
  static User? get currentUser => _auth.currentUser;

  // ===== Google Sign In =====
  static Future<UserCredential?> signInWithGoogle() async {
    try {
      // Trigger Google auth flow
      final GoogleSignInAccount? googleUser = await googleSignIn.signIn();
      if (googleUser == null) return null; // User cancelled

      // Get auth credentials
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // Lưu credential để GoldService dùng lại
      lastGoogleCredential = credential;

      // Sign in to Firebase
      final userCredential = await _auth.signInWithCredential(credential);

      // Tạo/cập nhật user document trong Firestore
      if (userCredential.user != null) {
        await _createOrUpdateUserDoc(userCredential.user!);
      }

      return userCredential;
    } catch (e) {
      rethrow;
    }
  }

  // ===== Sign Out =====
  static Future<void> signOut() async {
    lastGoogleCredential = null;
    await Future.wait([
      _auth.signOut(),
      googleSignIn.signOut(),
    ]);
  }

  // ===== Tạo user document trong Firestore =====
  static Future<void> _createOrUpdateUserDoc(User user) async {
    final docRef = _db.collection(AppConstants.usersCollection).doc(user.uid);
    final snapshot = await docRef.get();

    if (!snapshot.exists) {
      // User mới - tạo document
      await docRef.set({
        'uid': user.uid,
        'name': user.displayName ?? 'Người dùng',
        'email': user.email ?? '',
        'photoUrl': user.photoURL,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'currency': AppConstants.defaultCurrency,
        'locale': AppConstants.defaultLocale,
      });

      // Tạo ví mặc định
      await _createDefaultWallet(user.uid);
    } else {
      // User cũ - cập nhật
      await docRef.update({
        'updatedAt': FieldValue.serverTimestamp(),
        'lastLoginAt': FieldValue.serverTimestamp(),
      });
    }
  }

  // ===== Tạo ví mặc định =====
  static Future<void> _createDefaultWallet(String uid) async {
    final batch = _db.batch();

    final cashRef = _db
        .collection(AppConstants.usersCollection)
        .doc(uid)
        .collection(AppConstants.walletsCollection)
        .doc();

    batch.set(cashRef, {
      'id': cashRef.id,
      'name': 'Tiền mặt',
      'type': AppConstants.walletCash,
      'balance': 0.0,
      'currency': AppConstants.defaultCurrency,
      'color': 0xFF43A047,
      'iconCodePoint': Icons.account_balance_wallet.codePoint,
      'iconFontFamily': 'MaterialIcons',
      'isDefault': true,
      'createdAt': FieldValue.serverTimestamp(),
    });

    final bankRef = _db
        .collection(AppConstants.usersCollection)
        .doc(uid)
        .collection(AppConstants.walletsCollection)
        .doc();

    batch.set(bankRef, {
      'id': bankRef.id,
      'name': 'Tài khoản ngân hàng',
      'type': AppConstants.walletBank,
      'balance': 0.0,
      'currency': AppConstants.defaultCurrency,
      'color': 0xFF1976D2,
      'iconCodePoint': Icons.account_balance.codePoint,
      'iconFontFamily': 'MaterialIcons',
      'isDefault': false,
      'createdAt': FieldValue.serverTimestamp(),
    });

    final momoRef = _db
        .collection(AppConstants.usersCollection)
        .doc(uid)
        .collection(AppConstants.walletsCollection)
        .doc();

    batch.set(momoRef, {
      'id': momoRef.id,
      'name': 'Ví điện tử (Momo...)',
      'type': AppConstants.walletEwallet,
      'balance': 0.0,
      'currency': AppConstants.defaultCurrency,
      'color': 0xFFE91E63,
      'iconCodePoint': Icons.qr_code_scanner.codePoint,
      'iconFontFamily': 'MaterialIcons',
      'isDefault': false,
      'createdAt': FieldValue.serverTimestamp(),
    });

    await batch.commit();

    // Tạo categories mặc định
    await _createDefaultCategories(uid);
  }

  // ===== Tạo categories mặc định =====
  static Future<void> _createDefaultCategories(String uid) async {
    final catRef = _db
        .collection(AppConstants.usersCollection)
        .doc(uid)
        .collection(AppConstants.categoriesCollection);

    final defaultCategories = [
      {'name': 'Ăn uống', 'type': 'expense', 'color': '#E53935', 'icon': 'restaurant', 'order': 0},
      {'name': 'Di chuyển', 'type': 'expense', 'color': '#1E88E5', 'icon': 'directions_car', 'order': 1},
      {'name': 'Mua sắm', 'type': 'expense', 'color': '#8E24AA', 'icon': 'shopping_bag', 'order': 2},
      {'name': 'Sức khỏe', 'type': 'expense', 'color': '#00897B', 'icon': 'medical_services', 'order': 3},
      {'name': 'Giải trí', 'type': 'expense', 'color': '#FB8C00', 'icon': 'sports_esports', 'order': 4},
      {'name': 'Hóa đơn', 'type': 'expense', 'color': '#00ACC1', 'icon': 'receipt', 'order': 5},
      {'name': 'Giáo dục', 'type': 'expense', 'color': '#6D4C41', 'icon': 'school', 'order': 6},
      {'name': 'Du lịch', 'type': 'expense', 'color': '#E91E63', 'icon': 'flight', 'order': 7},
      {'name': 'Đầu tư', 'type': 'expense', 'color': '#5E35B1', 'icon': 'trending_up', 'order': 8},
      {'name': 'Khác', 'type': 'expense', 'color': '#757575', 'icon': 'more_horiz', 'order': 9},
      {'name': 'Lương', 'type': 'income', 'color': '#43A047', 'icon': 'attach_money', 'order': 0},
      {'name': 'Thưởng', 'type': 'income', 'color': '#FFB300', 'icon': 'card_giftcard', 'order': 1},
      {'name': 'Freelance', 'type': 'income', 'color': '#00BCD4', 'icon': 'laptop', 'order': 2},
      {'name': 'Lãi đầu tư', 'type': 'income', 'color': '#5E35B1', 'icon': 'show_chart', 'order': 3},
      {'name': 'Khác', 'type': 'income', 'color': '#757575', 'icon': 'more_horiz', 'order': 4},
    ];

    final batch = _db.batch();
    for (final cat in defaultCategories) {
      final ref = catRef.doc();
      batch.set(ref, {
        'id': ref.id,
        ...cat,
        'isDefault': true,
        'createdAt': FieldValue.serverTimestamp(),
      });
    }
    await batch.commit();
  }
}
