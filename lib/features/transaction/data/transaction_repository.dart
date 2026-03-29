import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:savemoney/shared/models/models.dart';
import 'package:savemoney/features/auth/domain/auth_provider.dart';
import 'package:savemoney/features/family/data/family_repository.dart';

class TransactionRepository {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  static const _uuid = Uuid();

  // Lấy collection path: ưu tiên family nếu có, fallback về user
  Future<CollectionReference> _getTxCollection() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('User not logged in');
    final uid = user.uid;
    
    final userDoc = await _db.collection('users').doc(uid).get();
    final data = userDoc.data() as Map<String, dynamic>?;
    final familyId = data?['familyId'] as String?;

    if (familyId != null && familyId.isNotEmpty) {
      return _db.collection('families').doc(familyId).collection('transactions');
    }
    return _db.collection('users').doc(uid).collection('transactions');
  }

  // Lấy cả 2 collections chỉ với 1 Firestore read
  Future<({CollectionReference txCol, CollectionReference walletCol})> _getCollections() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('User not logged in');
    final uid = user.uid;

    final userDoc = await _db.collection('users').doc(uid).get();
    final data = userDoc.data() as Map<String, dynamic>?;
    final familyId = data?['familyId'] as String?;

    if (familyId != null && familyId.isNotEmpty) {
      final base = _db.collection('families').doc(familyId);
      return (
        txCol: base.collection('transactions'),
        walletCol: base.collection('wallets'),
      );
    }
    return (
      txCol: _db.collection('users').doc(uid).collection('transactions'),
      walletCol: _db.collection('users').doc(uid).collection('wallets'),
    );
  }

  // Lấy wallet collection path
  Future<CollectionReference> _getWalletCollection() async {
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

  // ===== Thêm giao dịch + tự động cập nhật số dư ví =====
  Future<String> addTransaction({
    required String walletId,
    required String categoryId,
    required String type,
    required double amount,
    String note = '',
    required DateTime date,
    String? toWalletId, // Dùng khi chuyển khoản
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('User not logged in');
    final txId = _uuid.v4();
    // Chỉ 1 Firestore read duy nhất thay vì 2
    final cols = await _getCollections();
    final txCol = cols.txCol;
    final walletCol = cols.walletCol;

    final batch = _db.batch();

    // Lưu giao dịch
    batch.set(txCol.doc(txId), {
      'id': txId,
      'walletId': walletId,
      'toWalletId': toWalletId,
      'categoryId': categoryId,
      'type': type,
      'amount': amount,
      'note': note,
      'date': Timestamp.fromDate(date),
      'createdBy': {
        'userId': user.uid,
        'displayName': user.displayName ?? 'Người dùng',
        'photoUrl': user.photoURL,
      },
      'createdAt': FieldValue.serverTimestamp(),
    });

    // Cập nhật số dư ví nguồn
    final walletRef = walletCol.doc(walletId);
    if (type == 'income') {
      batch.update(walletRef, {'balance': FieldValue.increment(amount)});
    } else if (type == 'expense') {
      batch.update(walletRef, {'balance': FieldValue.increment(-amount)});
    } else if (type == 'transfer' && toWalletId != null) {
      batch.update(walletRef, {'balance': FieldValue.increment(-amount)});
      batch.update(walletCol.doc(toWalletId), {'balance': FieldValue.increment(amount)});
    }

    // ===== Kiểm tra số dư tại Firestore trước khi commit (hard-stop) =====
    if (type == 'expense' || type == 'transfer') {
      final walletDoc = await walletCol.doc(walletId).get().timeout(
        const Duration(seconds: 8),
        onTimeout: () => throw Exception('Hết giờ kết nối Firestore'),
      );
      if (!walletDoc.exists) throw Exception('Không tìm thấy ví!');
      final walletData = (walletDoc.data() as Map?)?.cast<String, dynamic>();
      final currentBalance = (walletData?['balance'] as num?)?.toDouble() ?? 0.0;
      if (amount > currentBalance) {
        throw Exception('Không đủ số dư! Ví chỉ còn ${currentBalance.toStringAsFixed(0)} ₫');
      }
    }

    await batch.commit().timeout(
      const Duration(seconds: 10),
      onTimeout: () => throw Exception('Hết giờ chờ — Kiểm tra kết nối mạng và thử lại.'),
    );
    return txId;
  }

  // ===== Xóa giao dịch + hoàn trả số dư ví =====
  Future<void> deleteTransaction(String txId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('User not logged in');
    final txCol = await _getTxCollection();
    final walletCol = await _getWalletCollection();

    final doc = await txCol.doc(txId).get();
    if (!doc.exists) return;

    final data = doc.data() as Map<String, dynamic>;
    final createdById = (data['createdBy'] as Map?)?['userId'];

    if (createdById != user.uid) {
      throw Exception('Chỉ người tạo mới có thể xóa bản ghi này.');
    }

    final batch = _db.batch();
    batch.delete(txCol.doc(txId));

    // Hoàn trả số dư (reverse)
    final type = data['type'] as String? ?? '';
    final amount = (data['amount'] as num?)?.toDouble() ?? 0;
    final walletId = data['walletId'] as String?;
    final toWalletId = data['toWalletId'] as String?;

    if (walletId != null) {
      if (type == 'income') {
        batch.update(walletCol.doc(walletId), {'balance': FieldValue.increment(-amount)});
      } else if (type == 'expense') {
        batch.update(walletCol.doc(walletId), {'balance': FieldValue.increment(amount)});
      } else if (type == 'transfer' && toWalletId != null) {
        batch.update(walletCol.doc(walletId), {'balance': FieldValue.increment(amount)});
        batch.update(walletCol.doc(toWalletId), {'balance': FieldValue.increment(-amount)});
      }
    }

    await batch.commit();
  }

  // ===== Sửa giao dịch + điều chỉnh số dư ví =====
  Future<void> updateTransaction({
    required String txId,
    required TransactionModel oldTx, // giao dịch gốc để reverse balance
    required String categoryId,
    required String type,
    required double amount,
    required String walletId,
    String note = '',
    required DateTime date,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('User not logged in');

    final cols = await _getCollections();
    final txCol = cols.txCol;
    final walletCol = cols.walletCol;

    // Kiểm tra số dư nếu là chi tiêu (check với delta cần thêm)
    if (type == 'expense') {
      final walletDoc = await walletCol.doc(walletId).get().timeout(
        const Duration(seconds: 8),
        onTimeout: () => throw Exception('Hết giờ kết nối Firestore'),
      );
      if (!walletDoc.exists) throw Exception('Không tìm thấy ví!');
      final walletData = (walletDoc.data() as Map?)?.cast<String, dynamic>();
      final currentBalance = (walletData?['balance'] as num?)?.toDouble() ?? 0.0;
      // Số dư khả dụng = balance hiện tại + số tiền cũ đã trừ (hoàn về)
      final availableBalance = currentBalance + (oldTx.type == 'expense' && oldTx.walletId == walletId ? oldTx.amount : 0);
      if (amount > availableBalance) {
        throw Exception('Không đủ số dư! Ví chỉ còn ${availableBalance.toStringAsFixed(0)} ₫');
      }
    }

    final batch = _db.batch();

    // Cập nhật giao dịch
    batch.update(txCol.doc(txId), {
      'categoryId': categoryId,
      'type': type,
      'amount': amount,
      'walletId': walletId,
      'note': note,
      'date': Timestamp.fromDate(date),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    // Reverse balance của giao dịch cũ
    if (oldTx.walletId.isNotEmpty) {
      if (oldTx.type == 'income') {
        batch.update(walletCol.doc(oldTx.walletId), {'balance': FieldValue.increment(-oldTx.amount)});
      } else if (oldTx.type == 'expense') {
        batch.update(walletCol.doc(oldTx.walletId), {'balance': FieldValue.increment(oldTx.amount)});
      }
    }

    // Apply balance mới
    if (walletId.isNotEmpty) {
      if (type == 'income') {
        batch.update(walletCol.doc(walletId), {'balance': FieldValue.increment(amount)});
      } else if (type == 'expense') {
        batch.update(walletCol.doc(walletId), {'balance': FieldValue.increment(-amount)});
      }
    }

    await batch.commit().timeout(
      const Duration(seconds: 10),
      onTimeout: () => throw Exception('Hết giờ chờ — Kiểm tra kết nối mạng và thử lại.'),
    );
  }


  // ===== Stream danh sách giao dịch =====
  Future<Stream<QuerySnapshot>> watchTransactions({String? filterUserId}) async {
    final col = await _getTxCollection();
    Query query = col.orderBy('date', descending: true);

    // Filter theo thành viên nếu có
    if (filterUserId != null) {
      query = query.where('createdBy.userId', isEqualTo: filterUserId);
    }

    return query.snapshots();
  }

  // ===== Lấy giao dịch hôm nay =====
  Future<int> countTodayTransactions() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return 0;

    final today = DateTime.now();
    final startOfDay = DateTime(today.year, today.month, today.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));

    final col = await _getTxCollection();
    final snap = await col
        .where('createdBy.userId', isEqualTo: uid)
        .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
        .where('date', isLessThan: Timestamp.fromDate(endOfDay))
        .get();

    return snap.docs.length;
  }
}

final transactionRepositoryProvider = Provider<TransactionRepository>(
  (ref) => TransactionRepository(),
);

final transactionsProvider = StreamProvider<List<TransactionModel>>((ref) async* {
  final user = ref.watch(authStateProvider).valueOrNull;
  if (user == null) {
    yield [];
    return;
  }
  
  final familyId = ref.watch(userFamilyIdProvider).valueOrNull;
  final db = FirebaseFirestore.instance;
  
  CollectionReference col;
  if (familyId != null && familyId.isNotEmpty) {
    col = db.collection('families').doc(familyId).collection('transactions');
  } else {
    col = db.collection('users').doc(user.uid).collection('transactions');
  }

  final stream = col.orderBy('date', descending: true).snapshots();
  await for (final snap in stream) {
    yield snap.docs.map((doc) => TransactionModel.fromMap(doc.id, doc.data() as Map<String, dynamic>)).toList();
  }
});
