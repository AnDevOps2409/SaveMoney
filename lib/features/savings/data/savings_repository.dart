import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:savemoney/features/savings/presentation/screens/savings_screen.dart';
import 'package:flutter/material.dart';
import 'package:savemoney/core/services/notification_service.dart';
import 'package:savemoney/features/auth/domain/auth_provider.dart';
import 'package:savemoney/features/family/data/family_repository.dart';
import 'package:savemoney/core/utils/format_utils.dart';

class SavingsRepository {
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
      return _db.collection('families').doc(familyId).collection('savings');
    }
    return _db.collection('users').doc(uid).collection('savings');
  }

  Future<String> addGoal({
    required String name,
    required String emoji,
    required double targetAmount,
    required DateTime deadline,
    required Color color,
  }) async {
    final col = await _getCollection();
    final id = _uuid.v4();

    await col.doc(id).set({
      'id': id,
      'name': name,
      'emoji': emoji,
      'targetAmount': targetAmount,
      'currentAmount': 0.0,
      'deadline': Timestamp.fromDate(deadline),
      'color': color.value,
      'contributions': [],
      'createdAt': FieldValue.serverTimestamp(),
    });

    // Lên lịch nhắc deadline mục tiêu (3 ngày trước)
    await NotificationService.scheduleSavingsDeadlineReminder(
      goalId: id,
      goalName: name,
      deadline: deadline,
    );

    return id;
  }

  Future<void> addContribution({
    required String goalId,
    required String goalName,
    required double amount,
    required String note,
    required double currentAmount,
    required double targetAmount,
  }) async {
    final col = await _getCollection();
    final docRef = col.doc(goalId);
    
    final contribution = {
      'id': _uuid.v4(),
      'amount': amount,
      'date': Timestamp.now(),
      'note': note,
    };

    await docRef.update({
      'currentAmount': FieldValue.increment(amount),
      'contributions': FieldValue.arrayUnion([contribution]),
    });

    // Đạt mục tiêu: cất số schedule + show bạn chúc mừng
    final newTotal = currentAmount + amount;
    if (newTotal >= targetAmount) {
      await NotificationService.cancelSavingsReminder(goalId);
      await NotificationService.showSavingsCelebration(
        goalId: goalId,
        goalName: goalName,
      );
    }
  }

  Stream<List<SavingsGoal>> watchGoals() async* {
    final col = await _getCollection();
    yield* col.snapshots().map((snap) {
      return snap.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        
        final contributionsList = (data['contributions'] as List<dynamic>?)?.map((c) {
          final cMap = c as Map<String, dynamic>;
          return SavingsContribution(
            id: cMap['id'] ?? '',
            amount: (cMap['amount'] as num?)?.toDouble() ?? 0.0,
            date: (cMap['date'] as Timestamp?)?.toDate() ?? DateTime.now(),
            note: cMap['note'] ?? '',
          );
        }).toList() ?? [];

        // Sort descending by date
        contributionsList.sort((a, b) => b.date.compareTo(a.date));

        return SavingsGoal(
          id: doc.id,
          name: data['name'] ?? '',
          emoji: data['emoji'] ?? '💰',
          targetAmount: (data['targetAmount'] as num?)?.toDouble() ?? 0.0,
          currentAmount: (data['currentAmount'] as num?)?.toDouble() ?? 0.0,
          deadline: (data['deadline'] as Timestamp?)?.toDate() ?? DateTime.now(),
          color: Color(FormatUtils.parseInt(data['color'], 0xFF1E88E5)),
          contributions: contributionsList,
        );
      }).toList();
    });
  }
}

final savingsRepositoryProvider = Provider((ref) => SavingsRepository());

final savingsProvider = StreamProvider<List<SavingsGoal>>((ref) async* {
  final user = ref.watch(authStateProvider).valueOrNull;
  if (user == null) {
    yield [];
    return;
  }
  
  final familyId = ref.watch(userFamilyIdProvider).valueOrNull;
  final db = FirebaseFirestore.instance;
  
  CollectionReference col;
  if (familyId != null && familyId.isNotEmpty) {
    col = db.collection('families').doc(familyId).collection('savings');
  } else {
    col = db.collection('users').doc(user.uid).collection('savings');
  }

  yield* col.snapshots().map((snap) {
    return snap.docs.map((doc) {
      final data = doc.data() as Map<String, dynamic>;
      
      final contributionsList = (data['contributions'] as List<dynamic>?)?.map((c) {
        final cMap = c as Map<String, dynamic>;
        return SavingsContribution(
          id: cMap['id'] ?? '',
          amount: (cMap['amount'] as num?)?.toDouble() ?? 0.0,
          date: (cMap['date'] as Timestamp?)?.toDate() ?? DateTime.now(),
          note: cMap['note'] ?? '',
        );
      }).toList() ?? [];

      contributionsList.sort((a, b) => b.date.compareTo(a.date));

      return SavingsGoal(
        id: doc.id,
        name: data['name'] ?? '',
        emoji: data['emoji'] ?? '💰',
        targetAmount: (data['targetAmount'] as num?)?.toDouble() ?? 0.0,
        currentAmount: (data['currentAmount'] as num?)?.toDouble() ?? 0.0,
        deadline: (data['deadline'] as Timestamp?)?.toDate() ?? DateTime.now(),
        color: Color(FormatUtils.parseInt(data['color'], 0xFF1E88E5)),
        contributions: contributionsList,
      );
    }).toList();
  });
});

extension SavingsRepositoryExt on SavingsRepository {
  Future<void> deleteGoal(String goalId) async {
    await NotificationService.cancelSavingsReminder(goalId);
    final col = await _getCollection();
    await col.doc(goalId).delete();
  }
}
