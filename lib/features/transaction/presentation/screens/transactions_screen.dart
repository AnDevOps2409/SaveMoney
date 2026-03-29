import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:savemoney/core/constants/app_colors.dart';
import 'package:savemoney/core/utils/format_utils.dart';
import 'package:savemoney/features/transaction/data/transaction_repository.dart';
import 'package:savemoney/features/transaction/presentation/screens/add_transaction_screen.dart';
import 'package:savemoney/shared/models/mock_data.dart';
import 'package:savemoney/shared/models/models.dart';
import 'package:savemoney/shared/widgets/top_toast.dart';

class TransactionsScreen extends ConsumerStatefulWidget {
  const TransactionsScreen({super.key});

  @override
  ConsumerState<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends ConsumerState<TransactionsScreen> {
  int _selectedPeriod = 1; // 0: trước, 1: này, 2: tương lai
  final _periods = ['THÁNG TRƯỚC', 'THÁNG NÀY', 'TƯƠNG LAI'];
  bool _isSearching = false;
  String _searchQuery = '';
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // Group transactions by date
  Map<DateTime, List<TransactionModel>> _groupByDate(List<TransactionModel> txs) {
    final map = <DateTime, List<TransactionModel>>{};
    for (final tx in txs) {
      final key = DateTime(tx.date.year, tx.date.month, tx.date.day);
      map.putIfAbsent(key, () => []);
      map[key]!.add(tx);
    }
    return Map.fromEntries(map.entries.toList()..sort((a, b) => b.key.compareTo(a.key)));
  }

  @override
  Widget build(BuildContext context) {
    final transactionsAsync = ref.watch(transactionsProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: transactionsAsync.when(
          data: (transactions) {
            final now = DateTime.now();
            List<TransactionModel> filteredTxs = [];
            
            // Lọc theo khoảng thời gian
            if (_selectedPeriod == 1) { // THÁNG NÀY
              filteredTxs = transactions.where((t) => t.date.year == now.year && t.date.month == now.month).toList();
            } else if (_selectedPeriod == 0) { // THÁNG TRƯỚC
              final lastMonth = DateTime(now.year, now.month - 1);
              filteredTxs = transactions.where((t) => t.date.year == lastMonth.year && t.date.month == lastMonth.month).toList();
            } else { // TƯƠNG LAI
              filteredTxs = transactions.where((t) => t.date.isAfter(DateTime(now.year, now.month + 1, 0))).toList();
            }

            // Lọc theo search query
            if (_searchQuery.isNotEmpty) {
              final q = _searchQuery.toLowerCase();
              filteredTxs = filteredTxs.where((t) => t.note.toLowerCase().contains(q)).toList();
            }

            final income = filteredTxs.where((t) => t.type == 'income').fold(0.0, (sum, t) => sum + t.amount);
            final expense = filteredTxs.where((t) => t.type == 'expense').fold(0.0, (sum, t) => sum + t.amount);
            final grouped = _groupByDate(filteredTxs);

            return _buildContent(context, income, expense, grouped);
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, st) => Center(child: Text('Lỗi: $e')),
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context, double income, double expense, Map<DateTime, List<TransactionModel>> grouped) {
    return Column(
          children: [
            // ===== HEADER: Số dư =====
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      GestureDetector(
                        onTap: () => GoRouter.of(context).go('/home'),
                        child: const Icon(Icons.arrow_back_ios_new, color: AppColors.textPrimary, size: 20),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Số dư', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                          Text(
                            FormatUtils.formatAmount(income - expense),
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w700,
                              color: (income - expense) >= 0 ? AppColors.textPrimary : AppColors.expense,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      IconButton(
                        icon: Icon(_isSearching ? Icons.close : Icons.search, color: AppColors.textSecondary),
                        onPressed: () {
                          setState(() {
                            _isSearching = !_isSearching;
                            if (!_isSearching) {
                              _searchQuery = '';
                              _searchController.clear();
                            }
                          });
                        },
                      ),
                      IconButton(icon: const Icon(Icons.more_vert, color: AppColors.textSecondary), onPressed: () {}),
                    ],
                  ),
                ],
              ),
            ),

            // ===== Wallet selector pill =====
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.language, size: 16, color: AppColors.textSecondary),
                      SizedBox(width: 6),
                      Text('Tổng cộng', style: TextStyle(fontSize: 14, color: AppColors.textPrimary)),
                      SizedBox(width: 4),
                      Icon(Icons.keyboard_arrow_down, size: 18, color: AppColors.textSecondary),
                    ],
                  ),
                ),
              ),
            ),

            // ===== Period tabs =====
            Container(
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: AppColors.divider, width: 0.5)),
              ),
              child: Row(
                children: _periods.asMap().entries.map((entry) {
                  final isActive = entry.key == _selectedPeriod;
                  return Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _selectedPeriod = entry.key),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          border: Border(
                            bottom: BorderSide(
                              color: isActive ? AppColors.textPrimary : Colors.transparent,
                              width: 2,
                            ),
                          ),
                        ),
                        child: Text(
                          entry.value,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: isActive ? AppColors.textPrimary : AppColors.textMuted,
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),

            // ===== Income / Expense summary =====
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Tiền vào', style: TextStyle(color: AppColors.textSecondary, fontSize: 14)),
                      Text(
                        FormatUtils.formatAmount(income),
                        style: const TextStyle(color: AppColors.income, fontWeight: FontWeight.w600, fontSize: 15),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Tiền ra', style: TextStyle(color: AppColors.textSecondary, fontSize: 14)),
                      Text(
                        FormatUtils.formatAmount(expense),
                        style: const TextStyle(color: AppColors.expense, fontWeight: FontWeight.w600, fontSize: 15),
                      ),
                    ],
                  ),
                  const Divider(height: 16, color: AppColors.divider),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Text(
                        FormatUtils.formatAmount(income - expense),
                        style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w700, fontSize: 15),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // ===== Report button =====
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: GestureDetector(
                onTap: () => context.go('/reports'),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withAlpha(31),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColors.primary.withAlpha(77)),
                  ),
                  child: const Text(
                    'Xem báo cáo cho giai đoạn này',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600, fontSize: 13),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 8),

            // ===== Transaction List =====
            Expanded(
              child: ListView.builder(
                itemCount: grouped.length,
                itemBuilder: (context, index) {
                  final date = grouped.keys.elementAt(index);
                  final txs = grouped[date]!;
                  final dayTotal = txs.fold<double>(
                    0,
                    (sum, tx) => tx.type == 'income' ? sum + tx.amount : sum - tx.amount,
                  );

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Date header
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                        child: Row(
                          children: [
                            Text(
                              '${date.day}',
                              style: const TextStyle(
                                fontSize: 40,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary,
                                height: 1,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _getDayLabel(date),
                                    style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                                  ),
                                  Text(
                                    'tháng ${date.month} ${date.year}',
                                    style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                                  ),
                                ],
                              ),
                            ),
                            Text(
                              FormatUtils.formatAmount(dayTotal.abs()),
                              style: TextStyle(
                                fontSize: 13,
                                color: dayTotal >= 0 ? AppColors.textSecondary : AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Transactions
                      ...txs.asMap().entries.map((entry) {
                        final tx = entry.value;
                        final isLast = entry.key == txs.length - 1;
                        return _TxRow(transaction: tx, showDivider: !isLast);
                      }),
                      const Divider(height: 1, thickness: 0.5, color: AppColors.divider),
                    ],
                  );
                },
              ),
            ),
          ],
        );
  }

  String _getDayLabel(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final d = DateTime(date.year, date.month, date.day);
    if (d == today) return 'Hôm nay';
    if (d == today.subtract(const Duration(days: 1))) return 'Hôm qua';
    return ['Thứ 2', 'Thứ 3', 'Thứ 4', 'Thứ 5', 'Thứ 6', 'Thứ 7', 'Chủ nhật'][date.weekday - 1];
  }
}

class _TxRow extends ConsumerWidget {
  final TransactionModel transaction;
  final bool showDivider;
  const _TxRow({required this.transaction, this.showDivider = true});

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final cat = MockData.getCategoryById(transaction.categoryId);
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: AppColors.surface,
      useRootNavigator: false,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(ctx).padding.bottom + 80),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40, height: 4,
              decoration: BoxDecoration(color: AppColors.divider, borderRadius: BorderRadius.circular(2)),
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: AppColors.expense.withAlpha(20), shape: BoxShape.circle),
              child: const Icon(Icons.delete_outline, color: AppColors.expense, size: 28),
            ),
            const SizedBox(height: 12),
            const Text('Xóa giao dịch?',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
            const SizedBox(height: 6),
            Text(
              transaction.note.isNotEmpty ? transaction.note : cat.name,
              style: const TextStyle(fontSize: 14, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 4),
            Text(
              FormatUtils.formatAmount(transaction.amount),
              style: TextStyle(
                fontSize: 16, fontWeight: FontWeight.w700,
                color: transaction.type == 'income' ? AppColors.income : AppColors.expense,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: AppColors.surfaceLight, borderRadius: BorderRadius.circular(10)),
              child: const Row(
                children: [
                  Icon(Icons.info_outline, size: 14, color: AppColors.textSecondary),
                  SizedBox(width: 6),
                  Expanded(child: Text('Số dư ví sẽ được hoàn lại tự động.',
                    style: TextStyle(fontSize: 12, color: AppColors.textSecondary))),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context, false),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: AppColors.divider),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: const Text('Huỷ', style: TextStyle(color: AppColors.textSecondary)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context, true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.expense,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      elevation: 0,
                    ),
                    child: const Text('Xóa', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );

    if (confirmed == true && context.mounted) {
      try {
        final repo = ref.read(transactionRepositoryProvider);
        await repo.deleteTransaction(transaction.id);
        if (context.mounted) {
          TopToast.show(context, 'Đã xóa giao dịch thành công!');
        }
      } catch (e) {
        if (context.mounted) {
          TopToast.show(context, 'Lỗi: ${e.toString()}', isError: true);
        }
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cat = MockData.getCategoryById(transaction.categoryId);
    final isIncome = transaction.type == 'income';

    return Dismissible(
      key: Key(transaction.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        color: AppColors.expense.withAlpha(30),
        child: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.delete_outline, color: AppColors.expense, size: 24),
            SizedBox(height: 4),
            Text('Xóa', style: TextStyle(color: AppColors.expense, fontSize: 11, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
      confirmDismiss: (_) async {
        await _confirmDelete(context, ref);
        return false; // dialog handles it — don't auto-dismiss
      },
      child: Column(
        children: [
          InkWell(
            onLongPress: () => _confirmDelete(context, ref),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                children: [
                  Container(
                    width: 44, height: 44,
                    decoration: BoxDecoration(color: cat.color.withAlpha(38), borderRadius: BorderRadius.circular(12)),
                    child: Icon(cat.icon, color: cat.color, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          transaction.note.isNotEmpty ? transaction.note : cat.name,
                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15, color: AppColors.textPrimary),
                        ),
                        Text(
                          '${transaction.date.day} tháng ${transaction.date.month} ${transaction.date.year}',
                          style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    (isIncome ? '+' : '-') + FormatUtils.formatAmount(transaction.amount),
                    style: TextStyle(
                      fontWeight: FontWeight.w600, fontSize: 15,
                      color: isIncome ? AppColors.income : AppColors.expense,
                    ),
                  ),
                  const SizedBox(width: 4),
                  GestureDetector(
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => AddTransactionScreen(transaction: transaction),
                      ),
                    ),
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withAlpha(20),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.edit_outlined, size: 15, color: AppColors.primary),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (showDivider)
            const Divider(height: 1, thickness: 0.5, indent: 72, endIndent: 0, color: AppColors.divider),
        ],
      ),
    );
  }
}

