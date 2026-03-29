import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'dart:math' as math;
import 'package:savemoney/core/constants/app_colors.dart';
import 'package:savemoney/core/utils/format_utils.dart';
import 'package:savemoney/features/budget/data/budget_repository.dart';
import 'package:savemoney/shared/models/mock_data.dart';
import 'package:savemoney/shared/models/models.dart';

/// Format số được thêm dấu chấm phân cách nghìn khi gõ (VD: 5000000 → 5.000.000)
class _ThousandsFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    final raw = newValue.text.replaceAll('.', '');
    if (raw.isEmpty) return newValue.copyWith(text: '');
    final number = int.tryParse(raw);
    if (number == null) return oldValue;
    final formatted = _format(number);
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }

  String _format(int n) {
    final s = n.toString();
    final buf = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write('.');
      buf.write(s[i]);
    }
    return buf.toString();
  }
}

class BudgetScreen extends ConsumerStatefulWidget {
  const BudgetScreen({super.key});

  @override
  ConsumerState<BudgetScreen> createState() => _BudgetScreenState();
}

class _BudgetScreenState extends ConsumerState<BudgetScreen> {
  void _showAddBudgetSheet() {
    String? selectedCategoryId;
    final amountCtrl = TextEditingController();
    final allCategories = [...MockData.expenseCategories];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setInner) => Padding(
          padding: EdgeInsets.fromLTRB(16, 20, 16, MediaQuery.of(ctx).viewInsets.bottom + 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Tạo ngân sách', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
              const SizedBox(height: 16),
              const Text('Danh mục', style: TextStyle(fontSize: 13, color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              SizedBox(
                height: 48,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: allCategories.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (_, i) {
                    final cat = allCategories[i];
                    final selected = cat.id == selectedCategoryId;
                    return GestureDetector(
                      onTap: () => setInner(() => selectedCategoryId = cat.id),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: selected ? cat.color.withAlpha(40) : AppColors.surfaceLight,
                          border: Border.all(color: selected ? cat.color : Colors.transparent, width: 1.5),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(cat.icon, size: 16, color: selected ? cat.color : AppColors.textSecondary),
                            const SizedBox(width: 6),
                            Text(cat.name, style: TextStyle(fontSize: 12, color: selected ? cat.color : AppColors.textSecondary, fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),
              const Text('Hạn mức (₫)', style: TextStyle(fontSize: 13, color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              TextField(
                controller: amountCtrl,
                keyboardType: TextInputType.number,
                inputFormatters: [_ThousandsFormatter()],
                style: const TextStyle(color: AppColors.textPrimary, fontSize: 16),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: AppColors.surfaceLight,
                  hintText: 'Ví dụ: 5.000.000',
                  hintStyle: const TextStyle(color: AppColors.textMuted),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () async {
                    final amount = double.tryParse(amountCtrl.text.replaceAll(',', '').replaceAll('.', '')) ?? 0;
                    if (selectedCategoryId == null || amount <= 0) return;
                    try {
                      await ref.read(budgetRepositoryProvider).addBudget(
                        categoryId: selectedCategoryId!,
                        limitAmount: amount,
                      );
                      if (ctx.mounted) Navigator.pop(ctx);
                    } catch (e) {
                      if (ctx.mounted) {
                        ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text('Lỗi: $e')));
                      }
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: const Text('Tạo ngân sách', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 16)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final budgetsAsync = ref.watch(budgetsProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Ngân sách'),
      ),
      body: budgetsAsync.when(
        data: (budgets) {
          final totalBudget = budgets.fold<double>(0, (s, b) => s + b.limitAmount);
          final totalSpent = budgets.fold<double>(0, (s, b) => s + b.spentAmount);
          final remaining = totalBudget - totalSpent;

          return SingleChildScrollView(
        child: Column(
          children: [
            // ===== Month tab =====
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: const BoxDecoration(
                      border: Border(bottom: BorderSide(color: AppColors.textPrimary, width: 2)),
                    ),
                    child: const Text('Tháng này', style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                  ),
                ],
              ),
            ),

            // ===== Arc Gauge =====
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  children: [
                    SizedBox(
                      height: 180,
                      child: _BudgetGauge(
                        totalBudget: totalBudget,
                        spent: totalSpent,
                        remaining: remaining,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _GaugeStat(value: FormatUtils.formatCompact(totalBudget), label: 'Tổng NS'),
                        _GaugeStat(value: FormatUtils.formatCompact(totalSpent), label: 'Đã chi'),
                        _GaugeStat(value: '4 ngày', label: 'Đến cuối tháng'),
                      ],
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _showAddBudgetSheet,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                        ),
                        child: const Text('+ Tạo Ngân sách', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // ===== Budget list =====
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                children: budgets.map((budget) => Dismissible(
                  key: Key(budget.id),
                  direction: DismissDirection.endToStart,
                  background: Container(
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 20),
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: AppColors.expense.withAlpha(30),
                      borderRadius: BorderRadius.circular(16),
                    ),
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
                    final confirmed = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        backgroundColor: AppColors.surface,
                        title: const Text('Xóa ngân sách?', style: TextStyle(color: AppColors.textPrimary)),
                        content: const Text('Bạn chắc chắn muốn xóa ngân sách này?', style: TextStyle(color: AppColors.textSecondary)),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Huỷ')),
                          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Xóa', style: TextStyle(color: AppColors.expense))),
                        ],
                      ),
                    );
                    if (confirmed == true) {
                      await ref.read(budgetRepositoryProvider).deleteBudget(budget.id);
                    }
                    return false;
                  },
                  child: _BudgetCard(budget: budget),
                )).toList(),
              ),
            ),
            const SizedBox(height: 120),
          ],
        ),
      );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => Center(child: Text('Lỗi: $e')),
      ),
    );
  }
}

// ===== Arc Gauge Widget =====
class _BudgetGauge extends StatelessWidget {
  final double totalBudget;
  final double spent;
  final double remaining;

  const _BudgetGauge({required this.totalBudget, required this.spent, required this.remaining});

  @override
  Widget build(BuildContext context) {
    final progress = (spent / totalBudget).clamp(0.0, 1.0);
    return Stack(
      alignment: Alignment.center,
      children: [
        CustomPaint(
          size: const Size(double.infinity, 180),
          painter: _ArcPainter(progress: progress),
        ),
        Positioned(
          bottom: 20,
          child: Column(
            children: [
              const Text('Số tiền bạn có thể chi', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
              Text(
                FormatUtils.formatAmount(remaining),
                style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w700, color: AppColors.primary),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ArcPainter extends CustomPainter {
  final double progress;
  _ArcPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height * 0.85);
    final radius = size.width * 0.42;
    const startAngle = math.pi;
    const sweepAngle = math.pi;

    // Background arc
    final bgPaint = Paint()
      ..color = AppColors.surfaceLight
      ..strokeWidth = 14
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle, sweepAngle, false, bgPaint,
    );

    // Progress arc
    final color = progress >= 1.0 ? AppColors.expense : AppColors.primary;
    final fgPaint = Paint()
      ..color = color
      ..strokeWidth = 14
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle, sweepAngle * progress, false, fgPaint,
    );

    // Dot at end
    final angle = startAngle + sweepAngle * progress;
    final dotCenter = Offset(
      center.dx + radius * math.cos(angle),
      center.dy + radius * math.sin(angle),
    );
    canvas.drawCircle(dotCenter, 8, Paint()..color = color);
    canvas.drawCircle(dotCenter, 5, Paint()..color = Colors.white);
  }

  @override
  bool shouldRepaint(_ArcPainter oldDelegate) => oldDelegate.progress != progress;
}

class _GaugeStat extends StatelessWidget {
  final String value;
  final String label;
  const _GaugeStat({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
        Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
      ],
    );
  }
}

// ===== Budget Card =====
class _BudgetCard extends StatelessWidget {
  final BudgetModel budget;
  const _BudgetCard({required this.budget});

  @override
  Widget build(BuildContext context) {
    final cat = MockData.getCategoryById(budget.categoryId);
    final progress = budget.progressPercent.clamp(0.0, 1.0);
    final isOver = budget.isOverBudget;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: cat.color.withAlpha(38),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(cat.icon, color: cat.color, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(cat.name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15, color: AppColors.textPrimary)),
                    Text(
                      isOver ? 'Vượt ngân sách!' : 'Còn lại ${FormatUtils.formatAmount(budget.remainingAmount)}',
                      style: TextStyle(fontSize: 12, color: isOver ? AppColors.expense : AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
              Text(
                FormatUtils.formatAmount(budget.limitAmount),
                style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.textPrimary),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // Progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 6,
              backgroundColor: AppColors.surfaceLight,
              valueColor: AlwaysStoppedAnimation<Color>(isOver ? AppColors.expense : AppColors.primary),
            ),
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Text(
                'Hôm nay',
                style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
