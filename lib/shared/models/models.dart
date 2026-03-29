// Mock data models - dùng tạm cho đến khi có Firebase
// Sẽ replace bằng Firestore sau

import 'package:flutter/material.dart';

// ============ USER MODEL ============
class UserModel {
  final String id;
  final String name;
  final String email;
  final String? photoUrl;

  const UserModel({
    required this.id,
    required this.name,
    required this.email,
    this.photoUrl,
  });
}

// ============ WALLET MODEL ============
class WalletModel {
  final String id;
  final String userId;
  final String name;
  final String type; // cash, bank, ewallet, credit_card
  final double balance;
  final String currency;
  final Color color;
  final IconData icon;

  const WalletModel({
    required this.id,
    this.userId = '',
    required this.name,
    required this.type,
    required this.balance,
    this.currency = 'VND',
    required this.color,
    required this.icon,
  });
}

// ============ CATEGORY MODEL ============
class CategoryModel {
  final String id;
  final String name;
  final String type; // expense or income
  final Color color;
  final IconData icon;

  const CategoryModel({
    required this.id,
    required this.name,
    required this.type,
    required this.color,
    required this.icon,
  });
}

// ============ TRANSACTION MODEL ============
class TransactionModel {
  final String id;
  final String walletId;
  final String categoryId;
  final String type; // expense, income, transfer
  final double amount;
  final String note;
  final DateTime date;
  final String? receiptUrl;
  final String? toWalletId; // for transfers

  const TransactionModel({
    required this.id,
    required this.walletId,
    required this.categoryId,
    required this.type,
    required this.amount,
    this.note = '',
    required this.date,
    this.receiptUrl,
    this.toWalletId,
  });

  factory TransactionModel.fromMap(String id, Map<String, dynamic> map) {
    return TransactionModel(
      id: id,
      walletId: map['walletId'] ?? '',
      categoryId: map['categoryId'] ?? '',
      type: map['type'] ?? 'expense',
      amount: (map['amount'] as num?)?.toDouble() ?? 0.0,
      note: map['note'] ?? '',
      date: map['date'] != null 
          ? (map['date'] as dynamic).toDate() 
          : DateTime.now(),
      receiptUrl: map['receiptUrl'],
      toWalletId: map['toWalletId'],
    );
  }
}

// ============ BUDGET MODEL ============
class BudgetModel {
  final String id;
  final String categoryId;
  final double limitAmount;
  final double spentAmount;
  final String period; // month, week
  final DateTime startDate;

  const BudgetModel({
    required this.id,
    required this.categoryId,
    required this.limitAmount,
    required this.spentAmount,
    this.period = 'month',
    required this.startDate,
  });

  factory BudgetModel.fromMap(String id, Map<String, dynamic> map) {
    return BudgetModel(
      id: id,
      categoryId: map['categoryId'] ?? '',
      limitAmount: (map['limitAmount'] as num?)?.toDouble() ?? 0.0,
      spentAmount: (map['spentAmount'] as num?)?.toDouble() ?? 0.0,
      period: map['period'] ?? 'month',
      startDate: map['startDate'] != null 
          ? (map['startDate'] as dynamic).toDate() 
          : DateTime.now(),
    );
  }

  double get remainingAmount => limitAmount - spentAmount;
  double get progressPercent => spentAmount / limitAmount;
  bool get isOverBudget => spentAmount > limitAmount;
}
