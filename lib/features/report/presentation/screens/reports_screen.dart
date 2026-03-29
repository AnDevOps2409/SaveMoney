import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:savemoney/core/constants/app_colors.dart';
import 'package:savemoney/core/utils/format_utils.dart';
import 'package:savemoney/features/transaction/data/transaction_repository.dart';
import 'package:savemoney/shared/models/mock_data.dart';
import 'package:savemoney/shared/models/models.dart';

class ReportsScreen extends ConsumerStatefulWidget {
  const ReportsScreen({super.key});

  @override
  ConsumerState<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends ConsumerState<ReportsScreen> {
  // null = chưa chọn gì; 'expense' hoặc 'income' = đang xem detail
  String? _activeType;
  int _touchedIndex = -1;

  /// Tính tổng theo từng ngày trong tháng hiện tại
  Map<int, double> _buildDailyTotals(List<TransactionModel> txs, String type) {
    final now = DateTime.now();
    final map = <int, double>{};
    for (final tx in txs) {
      if (tx.type == type && tx.date.year == now.year && tx.date.month == now.month) {
        map[tx.date.day] = (map[tx.date.day] ?? 0) + tx.amount;
      }
    }
    return map;
  }

  /// Tính tổng theo từng tháng trong 6 tháng gần nhất
  List<double> _buildMonthlyTotals(List<TransactionModel> txs, String type) {
    final now = DateTime.now();
    return List.generate(6, (i) {
      final m = DateTime(now.year, now.month - (5 - i));
      return txs
          .where((t) => t.type == type && t.date.year == m.year && t.date.month == m.month)
          .fold(0.0, (s, t) => s + t.amount);
    });
  }

  @override
  Widget build(BuildContext context) {
    final transactionsAsync = ref.watch(transactionsProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        automaticallyImplyLeading: false,
        title: const Text('Báo cáo'),
        leading: BackButton(
          color: AppColors.textPrimary,
          onPressed: () {
            if (Navigator.canPop(context)) {
              Navigator.pop(context);
            } else {
              GoRouter.of(context).go('/home');
            }
          },
        ),
      ),
      body: transactionsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Lỗi: $e', style: const TextStyle(color: AppColors.expense))),
        data: (allTransactions) {
          final now = DateTime.now();
          final currentMonthTxs = allTransactions.where(
            (t) => t.date.year == now.year && t.date.month == now.month,
          ).toList();

          final totalExpense = currentMonthTxs.where((t) => t.type == 'expense').fold(0.0, (s, t) => s + t.amount);
          final totalIncome  = currentMonthTxs.where((t) => t.type == 'income').fold(0.0, (s, t) => s + t.amount);

          // Dữ liệu cho view đang active
          final activeTotal = _activeType == 'expense' ? totalExpense : (_activeType == 'income' ? totalIncome : 0.0);
          final activeTxs = _activeType != null
              ? currentMonthTxs.where((t) => t.type == _activeType).toList()
              : <TransactionModel>[];

          final categoryAmounts = <String, double>{};
          for (final tx in activeTxs) {
            categoryAmounts[tx.categoryId] = (categoryAmounts[tx.categoryId] ?? 0) + tx.amount;
          }
          final sorted = categoryAmounts.entries.toList()..sort((a, b) => b.value.compareTo(a.value));

          final dailyMap = _activeType != null ? _buildDailyTotals(allTransactions, _activeType!) : <int, double>{};
          final daysInMonth = DateUtils.getDaysInMonth(now.year, now.month);
          final dailyMax = dailyMap.values.fold(0.0, (m, v) => v > m ? v : m);
          final dailyChartMax = dailyMax == 0 ? 1000000.0 : dailyMax * 1.25;

          final monthlyExpense = _buildMonthlyTotals(allTransactions, 'expense');
          final monthlyIncome  = _buildMonthlyTotals(allTransactions, 'income');
          final monthlyData = _activeType == 'income' ? monthlyIncome : monthlyExpense;
          final monthlyMax = monthlyData.fold(0.0, (m, v) => v > m ? v : m);
          final monthlyChartMax = monthlyMax == 0 ? 1000000.0 : monthlyMax * 1.25;

          final activeColor = _activeType == 'income' ? AppColors.income : AppColors.expense;
          final now6 = DateTime.now();
          final monthLabels = List.generate(6, (i) {
            final m = DateTime(now6.year, now6.month - (5 - i));
            return 'T${m.month}';
          });

          return SingleChildScrollView(
            child: Column(
              children: [

                // ===== 2 Summary Cards (bấm được) =====
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: Row(
                    children: [
                      _SummaryCard(
                        label: 'Tổng đã chi',
                        value: totalExpense,
                        color: AppColors.expense,
                        isActive: _activeType == 'expense',
                        onTap: () => setState(() {
                          _activeType = _activeType == 'expense' ? null : 'expense';
                          _touchedIndex = -1;
                        }),
                      ),
                      const SizedBox(width: 12),
                      _SummaryCard(
                        label: 'Tổng đã thu',
                        value: totalIncome,
                        color: AppColors.income,
                        isActive: _activeType == 'income',
                        onTap: () => setState(() {
                          _activeType = _activeType == 'income' ? null : 'income';
                          _touchedIndex = -1;
                        }),
                      ),
                    ],
                  ),
                ),

                // ===== Biểu đồ theo ngày (chỉ hiện khi đang chọn) =====
                if (_activeType != null) ...[
                  const SizedBox(height: 16),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: activeColor.withAlpha(60), width: 1.5),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 10, height: 10,
                                decoration: BoxDecoration(color: activeColor, shape: BoxShape.circle),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '${_activeType == "expense" ? "Chi tiêu" : "Thu nhập"} theo ngày — T${now.month}/${now.year}',
                                style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.textPrimary, fontSize: 13),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            FormatUtils.formatAmount(activeTotal),
                            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: activeColor),
                          ),
                          const SizedBox(height: 16),
                          SizedBox(
                            height: 130,
                            child: dailyMap.isEmpty
                                ? Center(
                                    child: Text(
                                      'Chưa có giao dịch tháng này',
                                      style: const TextStyle(color: AppColors.textSecondary),
                                    ),
                                  )
                                : BarChart(
                                    BarChartData(
                                      alignment: BarChartAlignment.start,
                                      maxY: dailyChartMax,
                                      gridData: FlGridData(
                                        show: true,
                                        drawVerticalLine: false,
                                        getDrawingHorizontalLine: (_) =>
                                            FlLine(color: AppColors.divider, strokeWidth: 0.5),
                                      ),
                                      borderData: FlBorderData(show: false),
                                      titlesData: FlTitlesData(
                                        leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                        bottomTitles: AxisTitles(
                                          sideTitles: SideTitles(
                                            showTitles: true,
                                            interval: 5,
                                            getTitlesWidget: (val, _) {
                                              final day = val.toInt() + 1;
                                              if (day % 5 != 0 && day != 1) return const SizedBox.shrink();
                                              return Text('$day', style: const TextStyle(fontSize: 9, color: AppColors.textMuted));
                                            },
                                          ),
                                        ),
                                      ),
                                      barGroups: List.generate(daysInMonth, (i) {
                                        final day = i + 1;
                                        final value = dailyMap[day] ?? 0.0;
                                        return BarChartGroupData(
                                          x: i,
                                          barRods: [
                                            BarChartRodData(
                                              toY: value,
                                              color: value > 0 ? activeColor : activeColor.withAlpha(30),
                                              width: 6,
                                              borderRadius: const BorderRadius.vertical(top: Radius.circular(3)),
                                            ),
                                          ],
                                        );
                                      }),
                                    ),
                                  ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // ===== Pie Chart category =====
                  if (sorted.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                      child: Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(20)),
                        child: Column(
                          children: [
                            SizedBox(
                              height: 180,
                              child: PieChart(
                                PieChartData(
                                  sectionsSpace: 2,
                                  centerSpaceRadius: 46,
                                  pieTouchData: PieTouchData(touchCallback: (event, response) {
                                    setState(() {
                                      _touchedIndex = response?.touchedSection?.touchedSectionIndex ?? -1;
                                    });
                                  }),
                                  sections: sorted.asMap().entries.map((entry) {
                                    final idx = entry.key;
                                    final cat = MockData.getCategoryById(entry.value.key);
                                    final pct = activeTotal > 0 ? entry.value.value / activeTotal * 100 : 0.0;
                                    final isTouched = idx == _touchedIndex;
                                    return PieChartSectionData(
                                      color: cat.color,
                                      value: entry.value.value,
                                      radius: isTouched ? 58 : 48,
                                      title: '${pct.toStringAsFixed(0)}%',
                                      titleStyle: const TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.w700),
                                    );
                                  }).toList(),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                  // ===== Category breakdown =====
                  if (sorted.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                      child: Container(
                        decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(20)),
                        child: Column(
                          children: [
                            Padding(
                              padding: const EdgeInsets.all(16),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text('Theo danh mục',
                                    style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                                  Text('${sorted.length} mục',
                                    style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                                ],
                              ),
                            ),
                            ...sorted.take(6).toList().asMap().entries.map((entry) {
                              final cat = MockData.getCategoryById(entry.value.key);
                              final pct = activeTotal > 0 ? (entry.value.value / activeTotal * 100) : 0.0;
                              return Column(
                                children: [
                                  if (entry.key > 0) const Divider(height: 1, color: AppColors.divider, indent: 72),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                    child: Row(
                                      children: [
                                        Container(
                                          width: 40, height: 40,
                                          decoration: BoxDecoration(
                                              color: cat.color.withAlpha(38),
                                              borderRadius: BorderRadius.circular(10)),
                                          child: Icon(cat.icon, color: cat.color, size: 20),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(cat.name,
                                                style: const TextStyle(fontWeight: FontWeight.w600,
                                                    color: AppColors.textPrimary, fontSize: 14)),
                                              const SizedBox(height: 4),
                                              ClipRRect(
                                                borderRadius: BorderRadius.circular(2),
                                                child: LinearProgressIndicator(
                                                  value: pct / 100,
                                                  minHeight: 4,
                                                  backgroundColor: AppColors.surfaceLight,
                                                  valueColor: AlwaysStoppedAnimation<Color>(cat.color),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Column(
                                          crossAxisAlignment: CrossAxisAlignment.end,
                                          children: [
                                            Text(FormatUtils.formatAmount(entry.value.value),
                                              style: const TextStyle(fontWeight: FontWeight.w600,
                                                  color: AppColors.textPrimary, fontSize: 13)),
                                            Text('${pct.toStringAsFixed(0)}%',
                                              style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              );
                            }),
                            const SizedBox(height: 8),
                          ],
                        ),
                      ),
                    ),
                ],

                // ===== Biểu đồ 6 tháng (hiện khi chưa chọn card) =====
                if (_activeType == null) ...[
                  const SizedBox(height: 16),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(20)),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('6 tháng gần nhất',
                            style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                          const SizedBox(height: 4),
                          const Text('Bấm vào card phía trên để xem chi tiết theo ngày',
                            style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                          const SizedBox(height: 16),
                          SizedBox(
                            height: 150,
                            child: BarChart(
                              BarChartData(
                                alignment: BarChartAlignment.spaceAround,
                                maxY: monthlyChartMax,
                                gridData: FlGridData(
                                  show: true, drawVerticalLine: false,
                                  getDrawingHorizontalLine: (_) => FlLine(color: AppColors.divider, strokeWidth: 0.5),
                                ),
                                borderData: FlBorderData(show: false),
                                titlesData: FlTitlesData(
                                  leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                  bottomTitles: AxisTitles(
                                    sideTitles: SideTitles(
                                      showTitles: true,
                                      getTitlesWidget: (val, _) {
                                        final idx = val.toInt();
                                        if (idx < 0 || idx >= 6) return const SizedBox.shrink();
                                        return Text(monthLabels[idx],
                                          style: const TextStyle(fontSize: 11, color: AppColors.textMuted));
                                      },
                                    ),
                                  ),
                                ),
                                barGroups: List.generate(6, (i) {
                                  final isNow = i == 5;
                                  return BarChartGroupData(
                                    x: i,
                                    barRods: [
                                      BarChartRodData(
                                        toY: monthlyExpense[i],
                                        color: isNow ? AppColors.expense : AppColors.expense.withAlpha(70),
                                        width: 10,
                                        borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                                      ),
                                      BarChartRodData(
                                        toY: monthlyIncome[i],
                                        color: isNow ? AppColors.income : AppColors.income.withAlpha(70),
                                        width: 10,
                                        borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                                      ),
                                    ],
                                  );
                                }),
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Container(width: 8, height: 8, decoration: const BoxDecoration(color: AppColors.expense, shape: BoxShape.circle)),
                              const SizedBox(width: 4),
                              const Text('Chi tiêu', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                              const SizedBox(width: 12),
                              Container(width: 8, height: 8, decoration: const BoxDecoration(color: AppColors.income, shape: BoxShape.circle)),
                              const SizedBox(width: 4),
                              const Text('Thu nhập', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],

                const SizedBox(height: 100),
              ],
            ),
          );
        },
      ),
    );
  }
}

// ===== Summary Card =====
class _SummaryCard extends StatelessWidget {
  final String label;
  final double value;
  final Color color;
  final bool isActive;
  final VoidCallback onTap;
  const _SummaryCard({required this.label, required this.value, required this.color,
      required this.isActive, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            color: isActive ? color.withAlpha(30) : AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isActive ? color : Colors.transparent,
              width: 1.5,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(isActive ? Icons.expand_less : Icons.expand_more,
                    size: 14, color: isActive ? color : AppColors.textMuted),
                  const SizedBox(width: 4),
                  Text(label, style: TextStyle(fontSize: 12, color: isActive ? color : AppColors.textSecondary)),
                ],
              ),
              const SizedBox(height: 4),
              Text(FormatUtils.formatAmount(value),
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800,
                    color: isActive ? color : AppColors.textPrimary)),
            ],
          ),
        ),
      ),
    );
  }
}
