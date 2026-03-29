import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:savemoney/shared/models/models.dart';
import 'package:savemoney/shared/models/mock_data.dart';
import 'package:savemoney/core/services/notification_service.dart';
import 'package:savemoney/features/auth/domain/auth_provider.dart';
import 'package:savemoney/features/family/data/family_repository.dart';
import 'package:savemoney/features/transaction/data/transaction_repository.dart';

class BudgetRepository {
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
      return _db.collection('families').doc(familyId).collection('budgets');
    }
    return _db.collection('users').doc(uid).collection('budgets');
  }

  Future<String> addBudget({
    required String categoryId,
    required double limitAmount,
    String period = 'month',
  }) async {
    final col = await _getCollection();
    final id = _uuid.v4();
    final now = DateTime.now();

    await col.doc(id).set({
      'id': id,
      'categoryId': categoryId,
      'limitAmount': limitAmount,
      'spentAmount': 0.0,
      'period': period,
      'startDate': Timestamp.fromDate(DateTime(now.year, now.month, 1)),
      'createdAt': FieldValue.serverTimestamp(),
    });

    return id;
  }

  Future<void> deleteBudget(String budgetId) async {
    final col = await _getCollection();
    await col.doc(budgetId).delete();
  }
}

final budgetRepositoryProvider = Provider((ref) => BudgetRepository());
// Chứa danh sách ngân sách gốc từ Firestore
final baseBudgetsProvider = StreamProvider<List<BudgetModel>>((ref) async* {
  final user = ref.watch(authStateProvider).valueOrNull;
  if (user == null) { yield []; return; }

  final familyId = ref.watch(userFamilyIdProvider).valueOrNull;
  final db = FirebaseFirestore.instance;

  CollectionReference budgetCol;
  if (familyId != null && familyId.isNotEmpty) {
    budgetCol = db.collection('families').doc(familyId).collection('budgets');
  } else {
    budgetCol = db.collection('users').doc(user.uid).collection('budgets');
  }

  yield* budgetCol.snapshots().map((snap) {
    return snap.docs.map((doc) => BudgetModel.fromMap(doc.id, doc.data() as Map<String, dynamic>)).toList();
  });
});

/// Provider tính spentAmount thực tế từ giao dịch tháng hiện tại bằng cách combine 2 streams
final budgetsProvider = Provider<AsyncValue<List<BudgetModel>>>((ref) {
  final budgetsAsync = ref.watch(baseBudgetsProvider);
  final txsAsync = ref.watch(transactionsProvider);

  if (budgetsAsync.isLoading || txsAsync.isLoading) {
    return const AsyncLoading();
  }
  
  if (budgetsAsync.hasError) {
    return AsyncError(budgetsAsync.error!, budgetsAsync.stackTrace!);
  }
  
  if (txsAsync.hasError) {
    return AsyncError(txsAsync.error!, txsAsync.stackTrace!);
  }

  final budgets = budgetsAsync.value ?? [];
  final txs = txsAsync.value ?? [];

  final now = DateTime.now();
  final spendingMap = <String, double>{};

  // Tổng hợp các giao dịch chi tiêu trong tháng hiện tại
  for (final tx in txs) {
    if (tx.type == 'expense' && tx.date.year == now.year && tx.date.month == now.month) {
      spendingMap[tx.categoryId] = (spendingMap[tx.categoryId] ?? 0) + tx.amount;
    }
  }

  // Trả về danh sách ngân sách với spentAmount mới nhất
  final updatedBudgets = <BudgetModel>[];
  for (int i = 0; i < budgets.length; i++) {
    final b = budgets[i];
    final spent = spendingMap[b.categoryId] ?? 0;
    updatedBudgets.add(BudgetModel(
      id: b.id,
      categoryId: b.categoryId,
      limitAmount: b.limitAmount,
      spentAmount: spent,
      period: b.period,
      startDate: b.startDate,
    ));

    // Trigger budget notifications khi vượt ngưỡng
    if (b.limitAmount > 0) {
      final percent = (spent / b.limitAmount * 100).round();
      final categoryName = MockData.getCategoryById(b.categoryId).name;
      if (spent > b.limitAmount) {
        NotificationService.showBudgetExceeded(
          budgetIndex: i,
          categoryName: categoryName,
        );
      } else if (percent >= 80) {
        NotificationService.showBudgetWarning(
          budgetIndex: i,
          categoryName: categoryName,
          percent: percent,
        );
      }
    }
  }

  return AsyncData(updatedBudgets);
});
