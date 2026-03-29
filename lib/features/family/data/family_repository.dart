import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/material.dart';
import 'package:savemoney/core/constants/app_constants.dart';
import 'package:savemoney/features/auth/domain/auth_provider.dart';
import 'package:savemoney/features/family/domain/family_model.dart';

class FamilyRepository {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // Collection ref
  CollectionReference get _families => _db.collection('families');

  // Tạo Family mới
  Future<FamilyModel> createFamily(String name) async {
    final user = FirebaseAuth.instance.currentUser!;
    final inviteCode = _generateCode();

    final docRef = _families.doc();
    final member = MemberModel(
      userId: user.uid,
      displayName: user.displayName ?? 'Admin',
      photoUrl: user.photoURL,
      role: 'admin',
      joinedAt: DateTime.now(),
    );

    final data = {
      'id': docRef.id,
      'name': name,
      'createdBy': user.uid,
      'inviteCode': inviteCode,
      'members': [member.toMap()],
      'memberIds': [user.uid],
      'createdAt': FieldValue.serverTimestamp(),
    };

    await docRef.set(data);

    // Tạo các ví dùng chung mặc định cho gia đình
    final batch = _db.batch();
    
    final cashRef = docRef.collection(AppConstants.walletsCollection).doc();
    batch.set(cashRef, {
      'id': cashRef.id,
      'name': 'Tiền mặt (Chung)',
      'type': AppConstants.walletCash,
      'balance': 0.0,
      'currency': AppConstants.defaultCurrency,
      'color': 0xFF43A047,
      'iconCodePoint': Icons.account_balance_wallet.codePoint,
      'iconFontFamily': 'MaterialIcons',
      'isDefault': true,
      'createdAt': FieldValue.serverTimestamp(),
    });

    final bankRef = docRef.collection(AppConstants.walletsCollection).doc();
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

    final momoRef = docRef.collection(AppConstants.walletsCollection).doc();
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

    // Lưu familyId vào user doc
    await _db.collection('users').doc(user.uid).set({
      'familyId': docRef.id,
      'familyRole': 'admin',
    }, SetOptions(merge: true));

    return FamilyModel(
      id: docRef.id,
      name: name,
      createdBy: user.uid,
      inviteCode: inviteCode,
      members: [member],
      createdAt: DateTime.now(),
    );
  }

  // Tham gia Family bằng invite code
  Future<FamilyModel?> joinFamily(String inviteCode) async {
    final user = FirebaseAuth.instance.currentUser!;

    // Tìm family có invite code này
    final query = await _families
        .where('inviteCode', isEqualTo: inviteCode.toUpperCase())
        .limit(1)
        .get();

    if (query.docs.isEmpty) return null;

    final doc = query.docs.first;
    final familyId = doc.id;
    final familyData = doc.data() as Map<String, dynamic>;

    // Kiểm tra user đã vào chưa
    final members = familyData['members'] as List<dynamic>? ?? [];
    final alreadyJoined = members.any((m) => (m as Map)['userId'] == user.uid);
    if (alreadyJoined) {
      return FamilyModel.fromMap(familyId, familyData);
    }

    // Thêm thành viên mới
    final newMember = MemberModel(
      userId: user.uid,
      displayName: user.displayName ?? 'Thành viên',
      photoUrl: user.photoURL,
      role: 'member',
      joinedAt: DateTime.now(),
    );

    await doc.reference.update({
      'members': FieldValue.arrayUnion([newMember.toMap()]),
      'memberIds': FieldValue.arrayUnion([user.uid]),
    });

    // Lưu familyId vào user doc
    await _db.collection('users').doc(user.uid).set({
      'familyId': familyId,
      'familyRole': 'member',
    }, SetOptions(merge: true));

    // Reload doc
    final updated = await doc.reference.get();
    return FamilyModel.fromMap(familyId, updated.data() as Map<String, dynamic>);
  }

  // Kiểm tra user đã có family chưa
  Future<String?> getUserFamilyId(String uid) async {
    final doc = await _db.collection('users').doc(uid).get();
    if (!doc.exists) return null;
    return (doc.data() as Map<String, dynamic>?)?['familyId'];
  }

  // Lấy thông tin Family
  Stream<FamilyModel?> watchFamily(String familyId) {
    return _families.doc(familyId).snapshots().map((snap) {
      if (!snap.exists) return null;
      return FamilyModel.fromMap(snap.id, snap.data() as Map<String, dynamic>);
    });
  }

  // Rời khỏi Family
  Future<void> leaveFamily(String familyId) async {
    final user = FirebaseAuth.instance.currentUser!;

    try {
      final doc = await _families.doc(familyId).get();
      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        final members = (data['members'] as List<dynamic>?)?.map((m) => m as Map).toList() ?? [];
        final toRemove = members.firstWhere((m) => m['userId'] == user.uid, orElse: () => {});

        if (toRemove.isNotEmpty) {
          await _families.doc(familyId).update({
            'members': FieldValue.arrayRemove([toRemove]),
            'memberIds': FieldValue.arrayRemove([user.uid]),
          });
        }
      }
    } catch (e) {
      // Ignored: Có thể do family đã xóa hoặc lỗi permissions (vd dữ liệu cũ)
      // Vẫn tiếp tục thực hiện việc xóa familyId khỏi user document.
    }

    await _db.collection('users').doc(user.uid).set({
      'familyId': FieldValue.delete(),
      'familyRole': FieldValue.delete(),
    }, SetOptions(merge: true));
  }

  // Generate 6-char invite code
  String _generateCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final rng = Random.secure();
    return String.fromCharCodes(
      Iterable.generate(6, (_) => chars.codeUnitAt(rng.nextInt(chars.length))),
    );
  }
}

// Provider
final familyRepositoryProvider = Provider<FamilyRepository>((ref) => FamilyRepository());

// Provider lấy familyId của current user liên tục
final userFamilyIdProvider = StreamProvider<String?>((ref) async* {
  final user = ref.watch(authStateProvider).valueOrNull;
  if (user == null) {
    yield null;
    return;
  }
  
  final docStream = FirebaseFirestore.instance.collection('users').doc(user.uid).snapshots();
  await for (final snap in docStream) {
    if (!snap.exists) {
      yield null;
    } else {
      yield (snap.data() as Map<String, dynamic>?)?['familyId'] as String?;
    }
  }
});

// Provider stream thông tin family
final watchFamilyProvider = StreamProvider.family<FamilyModel?, String>((ref, familyId) async* {
  if (familyId.isEmpty) {
    yield null;
    return;
  }
  final repo = ref.read(familyRepositoryProvider);
  yield* repo.watchFamily(familyId);
});
