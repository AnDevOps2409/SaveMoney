import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:savemoney/shared/models/models.dart';
import 'package:flutter/material.dart';
import 'package:savemoney/core/constants/app_constants.dart';
import 'package:savemoney/features/auth/domain/auth_provider.dart';
import 'package:savemoney/features/family/data/family_repository.dart';
import 'package:savemoney/core/utils/format_utils.dart';

class WalletRepository {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  static const _uuid = Uuid();

  Future<CollectionReference> _getCollection() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('User not logged in');
    final uid = user.uid;
    final userDoc = await _db.collection('users').doc(uid).get();
    final data = userDoc.data() as Map<String, dynamic>?;
    final familyId = data?['familyId'] as String?;

    if (familyId != null && familyId.isNotEmpty) {
      return _db.collection('families').doc(familyId).collection('wallets');
    }
    return _db.collection('users').doc(uid).collection('wallets');
  }

  Future<void> createDefaultWallets() async {
    final col = await _getCollection();
    final batch = _db.batch();

    final cashRef = col.doc();
    batch.set(cashRef, {
      'id': cashRef.id,
      'name': 'Tiền mặt',
      'type': AppConstants.walletCash,
      'balance': 0.0,
      'currency': 'VND',
      'color': 0xFF43A047,
      'iconCodePoint': Icons.account_balance_wallet.codePoint,
      'iconFontFamily': 'MaterialIcons',
      'userId': FirebaseAuth.instance.currentUser?.uid ?? '',
      'createdAt': FieldValue.serverTimestamp(),
    });

    final bankRef = col.doc();
    batch.set(bankRef, {
      'id': bankRef.id,
      'name': 'Tài khoản ngân hàng',
      'type': AppConstants.walletBank,
      'balance': 0.0,
      'currency': 'VND',
      'color': 0xFF1976D2,
      'iconCodePoint': Icons.account_balance.codePoint,
      'iconFontFamily': 'MaterialIcons',
      'userId': FirebaseAuth.instance.currentUser?.uid ?? '',
      'createdAt': FieldValue.serverTimestamp(),
    });

    final momoRef = col.doc();
    batch.set(momoRef, {
      'id': momoRef.id,
      'name': 'Ví điện tử (Momo...)',
      'type': AppConstants.walletEwallet,
      'balance': 0.0,
      'currency': 'VND',
      'color': 0xFFE91E63,
      'iconCodePoint': Icons.qr_code_scanner.codePoint,
      'iconFontFamily': 'MaterialIcons',
      'userId': FirebaseAuth.instance.currentUser?.uid ?? '',
      'createdAt': FieldValue.serverTimestamp(),
    });

    await batch.commit();
  }

  Future<String> addWallet({
    required String name,
    required String type,
    required double initialBalance,
    required Color color,
    required IconData icon,
  }) async {
    final col = await _getCollection();
    final id = _uuid.v4();

    await col.doc(id).set({
      'id': id,
      'name': name,
      'type': type,
      'balance': initialBalance,
      'currency': 'VND',
      'color': color.value,
      'iconCodePoint': icon.codePoint,
      'iconFontFamily': icon.fontFamily,
      'userId': FirebaseAuth.instance.currentUser?.uid ?? '',
      'createdAt': FieldValue.serverTimestamp(),
    });

    return id;
  }

  Future<void> updateWallet({
    required String walletId,
    required String name,
    required double balance,
  }) async {
    final col = await _getCollection();
    await col.doc(walletId).update({
      'name': name,
      'balance': balance,
    });
  }

  Future<void> deleteWallet(String walletId) async {
    final col = await _getCollection();
    await col.doc(walletId).delete();
  }

  Stream<List<WalletModel>> watchWallets() async* {
    final col = await _getCollection();
    yield* col.snapshots().map((snap) {
      return snap.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return WalletModel(
          id: doc.id,
          userId: data['userId'] ?? '',
          name: data['name'] ?? '',
          type: data['type'] ?? 'cash',
          balance: (data['balance'] as num?)?.toDouble() ?? 0.0,
          currency: data['currency'] ?? 'VND',
          color: Color(FormatUtils.parseInt(data['color'], 0xFF1976D2)),
          icon: IconData(
            FormatUtils.parseInt(data['iconCodePoint'], Icons.account_balance_wallet.codePoint),
            fontFamily: data['iconFontFamily']?.toString() ?? 'MaterialIcons',
          ),
        );
      }).toList();
    });
  }
}

final walletRepositoryProvider = Provider((ref) => WalletRepository());

final familyWalletsProvider = StreamProvider<List<WalletModel>>((ref) async* {
  final user = ref.watch(authStateProvider).valueOrNull;
  if (user == null) {
    yield [];
    return;
  }
  
  final familyId = ref.watch(userFamilyIdProvider).valueOrNull;
  final db = FirebaseFirestore.instance;
  
  CollectionReference col;
  if (familyId != null && familyId.isNotEmpty) {
    col = db.collection('families').doc(familyId).collection('wallets');
  } else {
    col = db.collection('users').doc(user.uid).collection('wallets');
  }

  yield* col.snapshots().map((snap) {
    return snap.docs.map((doc) {
      final data = doc.data() as Map<String, dynamic>;
      return WalletModel(
        id: doc.id,
        userId: data['userId'] ?? '',
        name: data['name'] ?? '',
        type: data['type'] ?? 'cash',
        balance: (data['balance'] as num?)?.toDouble() ?? 0.0,
        currency: data['currency'] ?? 'VND',
        color: Color(FormatUtils.parseInt(data['color'], 0xFF1976D2)),
        icon: IconData(
          FormatUtils.parseInt(data['iconCodePoint'], Icons.account_balance_wallet.codePoint),
          fontFamily: data['iconFontFamily']?.toString() ?? 'MaterialIcons',
        ),
      );
    }).where((w) => w.userId.isNotEmpty).toList();
  });
});

final walletsProvider = Provider<AsyncValue<List<WalletModel>>>((ref) {
  final allWallets = ref.watch(familyWalletsProvider);
  final user = ref.watch(authStateProvider).valueOrNull;
  
  return allWallets.whenData((wallets) {
    if (user == null) return [];
    return wallets.where((w) => w.userId == user.uid).toList();
  });
});

