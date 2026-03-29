import 'package:flutter/material.dart';
import 'package:savemoney/shared/models/models.dart';

// ============ MOCK CATEGORIES ============
class MockData {
  static const List<CategoryModel> expenseCategories = [
    CategoryModel(id: 'food', name: 'Ăn uống', type: 'expense', color: Color(0xFFE53935), icon: Icons.restaurant),
    CategoryModel(id: 'transport', name: 'Di chuyển', type: 'expense', color: Color(0xFF1E88E5), icon: Icons.directions_car),
    CategoryModel(id: 'shopping', name: 'Mua sắm', type: 'expense', color: Color(0xFF8E24AA), icon: Icons.shopping_bag),
    CategoryModel(id: 'health', name: 'Sức khỏe', type: 'expense', color: Color(0xFF00897B), icon: Icons.medical_services),
    CategoryModel(id: 'entertainment', name: 'Giải trí', type: 'expense', color: Color(0xFFFB8C00), icon: Icons.sports_esports),
    CategoryModel(id: 'bills', name: 'Hóa đơn', type: 'expense', color: Color(0xFF00ACC1), icon: Icons.receipt),
    CategoryModel(id: 'education', name: 'Giáo dục', type: 'expense', color: Color(0xFF6D4C41), icon: Icons.school),
    CategoryModel(id: 'travel', name: 'Du lịch', type: 'expense', color: Color(0xFFE91E63), icon: Icons.flight),
    CategoryModel(id: 'investment', name: 'Đầu tư', type: 'expense', color: Color(0xFF5E35B1), icon: Icons.trending_up),
    CategoryModel(id: 'other_expense', name: 'Khác', type: 'expense', color: Color(0xFF757575), icon: Icons.more_horiz),
  ];

  static const List<CategoryModel> incomeCategories = [
    CategoryModel(id: 'salary', name: 'Lương', type: 'income', color: Color(0xFF43A047), icon: Icons.attach_money),
    CategoryModel(id: 'bonus', name: 'Thưởng', type: 'income', color: Color(0xFFFFB300), icon: Icons.card_giftcard),
    CategoryModel(id: 'freelance', name: 'Freelance', type: 'income', color: Color(0xFF00BCD4), icon: Icons.laptop),
    CategoryModel(id: 'invest_profit', name: 'Lãi đầu tư', type: 'income', color: Color(0xFF5E35B1), icon: Icons.show_chart),
    CategoryModel(id: 'other_income', name: 'Khác', type: 'income', color: Color(0xFF757575), icon: Icons.more_horiz),
  ];

  static final List<WalletModel> wallets = [
    const WalletModel(id: 'cash', name: 'Tiền mặt', type: 'cash', balance: 2500000, color: Color(0xFF43A047), icon: Icons.account_balance_wallet),
    const WalletModel(id: 'bank', name: 'MB Bank', type: 'bank', balance: 15000000, color: Color(0xFF1E88E5), icon: Icons.account_balance),
    const WalletModel(id: 'momo', name: 'MoMo', type: 'ewallet', balance: 850000, color: Color(0xFFE91E63), icon: Icons.phone_android),
  ];

  static final List<TransactionModel> transactions = [
    TransactionModel(id: 't1', walletId: 'bank', categoryId: 'salary', type: 'income', amount: 8000000, note: 'Lương tháng 3', date: DateTime(2026, 3, 26)),
    TransactionModel(id: 't2', walletId: 'cash', categoryId: 'food', type: 'expense', amount: 85000, note: 'Ăn trưa', date: DateTime(2026, 3, 27)),
    TransactionModel(id: 't3', walletId: 'cash', categoryId: 'transport', type: 'expense', amount: 200000, note: 'Đổ xăng', date: DateTime(2026, 3, 27)),
    TransactionModel(id: 't4', walletId: 'bank', categoryId: 'investment', type: 'expense', amount: 5000000, note: 'Đầu tư', date: DateTime(2026, 3, 26)),
    TransactionModel(id: 't5', walletId: 'bank', categoryId: 'food', type: 'expense', amount: 1500000, note: 'Ăn uống cả tuần', date: DateTime(2026, 3, 26)),
    TransactionModel(id: 't6', walletId: 'momo', categoryId: 'bills', type: 'expense', amount: 500000, note: 'Tiền điện', date: DateTime(2026, 3, 25)),
    TransactionModel(id: 't7', walletId: 'cash', categoryId: 'entertainment', type: 'expense', amount: 250000, note: 'Cà phê + bạn bè', date: DateTime(2026, 3, 25)),
    TransactionModel(id: 't8', walletId: 'bank', categoryId: 'shopping', type: 'expense', amount: 1200000, note: 'Quần áo', date: DateTime(2026, 3, 24)),
  ];

  static final List<BudgetModel> budgets = [
    BudgetModel(id: 'b1', categoryId: 'food', limitAmount: 3000000, spentAmount: 1585000, startDate: DateTime(2026, 3, 1)),
    BudgetModel(id: 'b2', categoryId: 'transport', limitAmount: 1000000, spentAmount: 200000, startDate: DateTime(2026, 3, 1)),
    BudgetModel(id: 'b3', categoryId: 'investment', limitAmount: 5000000, spentAmount: 5000000, startDate: DateTime(2026, 3, 1)),
    BudgetModel(id: 'b4', categoryId: 'entertainment', limitAmount: 500000, spentAmount: 250000, startDate: DateTime(2026, 3, 1)),
  ];

  // Helpers
  static double get totalBalance => wallets.fold(0, (sum, w) => sum + w.balance);

  static double get monthlyIncome => transactions
      .where((t) => t.type == 'income' && t.date.month == 3)
      .fold(0, (sum, t) => sum + t.amount);

  static double get monthlyExpense => transactions
      .where((t) => t.type == 'expense' && t.date.month == 3)
      .fold(0, (sum, t) => sum + t.amount);

  static CategoryModel getCategoryById(String id) {
    return [...expenseCategories, ...incomeCategories]
        .firstWhere((c) => c.id == id, orElse: () => expenseCategories.last);
  }

  static WalletModel getWalletById(String id) {
    return wallets.firstWhere((w) => w.id == id, orElse: () => wallets.first);
  }
}
