import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:go_router/go_router.dart';
import 'package:savemoney/core/constants/app_colors.dart';
import 'package:savemoney/core/utils/format_utils.dart';
import 'package:savemoney/features/transaction/data/transaction_repository.dart';
import 'package:savemoney/features/wallet/data/wallet_repository.dart';
import 'package:savemoney/shared/models/mock_data.dart';
import 'package:savemoney/shared/models/models.dart';
import 'package:savemoney/shared/widgets/category_icon.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  bool _balanceVisible = true;
  DateTime _selectedMonth = DateTime(DateTime.now().year, DateTime.now().month);

  void _prevMonth() => setState(() {
    _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month - 1);
  });
  void _nextMonth() {
    final now = DateTime.now();
    final next = DateTime(_selectedMonth.year, _selectedMonth.month + 1);
    if (!next.isAfter(DateTime(now.year, now.month))) {
      setState(() => _selectedMonth = next);
    }
  }
  bool get _isCurrentMonth {
    final now = DateTime.now();
    return _selectedMonth.year == now.year && _selectedMonth.month == now.month;
  }

  @override
  Widget build(BuildContext context) {
    final transactionsAsync = ref.watch(transactionsProvider);
    final familyWalletsAsync = ref.watch(familyWalletsProvider);

    // Tính toán từ stream
    double totalBalance = 0;
    double income = 0;
    double expense = 0;
    List<TransactionModel> recentTx = [];
    
    // Fallback UI trong lúc loading hoặc error
    Widget? bodyContent;

    transactionsAsync.when(
      data: (transactions) {
        // Lọc giao dịch tháng được chọn
        final currentMonthTx = transactions.where((t) {
          return t.date.year == _selectedMonth.year && t.date.month == _selectedMonth.month;
        }).toList();

        // Tổng số dư riêng của tôi (chỉ các ví của user hiện tại)
        final myWallets = ref.read(walletsProvider).valueOrNull ?? [];
        totalBalance = myWallets.fold(0.0, (sum, w) => sum + w.balance);
        
        income = currentMonthTx.where((t) => t.type == 'income').fold(0, (sum, t) => sum + t.amount);
        expense = currentMonthTx.where((t) => t.type == 'expense').fold(0, (sum, t) => sum + t.amount);
        
        // 5 giao dịch gần nhất
        recentTx = transactions.take(5).toList();
        
        bodyContent = _buildContent(totalBalance, income, expense, recentTx, currentMonthTx);
      },
      loading: () => bodyContent = const Center(child: CircularProgressIndicator()),
      error: (e, st) => bodyContent = Center(child: Text('Lỗi tải dữ liệu: $e')),
    );

    return Scaffold(
      backgroundColor: AppColors.background,
      body: bodyContent ?? const SizedBox(),
    );
  }

  Widget _buildContent(double totalBalance, double income, double expense, List<TransactionModel> recentTx, List<TransactionModel> currentMonthTx) {
    return CustomScrollView(
        slivers: [
          // ===== SliverAppBar =====
          SliverAppBar(
            backgroundColor: AppColors.background,
            floating: true,
            pinned: false,
            title: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                GestureDetector(
                  onTap: _prevMonth,
                  child: const Padding(
                    padding: EdgeInsets.all(4),
                    child: Icon(Icons.chevron_left, color: AppColors.textPrimary, size: 22),
                  ),
                ),
                const SizedBox(width: 4),
                GestureDetector(
                  onTap: () async {
                    // Long press to pick month from date picker
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: _selectedMonth,
                      firstDate: DateTime(2020),
                      lastDate: DateTime.now(),
                      initialDatePickerMode: DatePickerMode.year,
                      builder: (ctx, child) => Theme(
                        data: ThemeData.dark().copyWith(colorScheme: const ColorScheme.dark(primary: AppColors.primary)),
                        child: child!,
                      ),
                    );
                    if (picked != null) setState(() => _selectedMonth = DateTime(picked.year, picked.month));
                  },
                  child: Text(
                    'Tháng ${_selectedMonth.month}, ${_selectedMonth.year}',
                    style: const TextStyle(fontSize: 15, color: AppColors.textPrimary, fontWeight: FontWeight.w600),
                  ),
                ),
                const SizedBox(width: 4),
                GestureDetector(
                  onTap: _isCurrentMonth ? null : _nextMonth,
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: Icon(Icons.chevron_right,
                      color: _isCurrentMonth ? AppColors.textMuted : AppColors.textPrimary, size: 22),
                  ),
                ),
              ],
            ),
            actions: [
              IconButton(icon: const Icon(Icons.search, color: AppColors.textSecondary), onPressed: () {}),
              IconButton(
                icon: const Icon(Icons.account_circle_outlined, color: AppColors.textSecondary),
                onPressed: () => context.go('/wallet'),
              ),
              IconButton(
                icon: const Icon(Icons.notifications_outlined, color: AppColors.textSecondary),
                onPressed: () {},
              ),
            ],
          ),

          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            sliver: SliverList(
              delegate: SliverChildListDelegate([

                // ===== Tổng số dư =====
                const SizedBox(height: 8),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              _balanceVisible
                                  ? '${FormatUtils.formatAmount(totalBalance)}'
                                  : '••••• ₫',
                              style: const TextStyle(
                                fontSize: 32,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary,
                                letterSpacing: -0.5,
                              ),
                            ),
                            const SizedBox(width: 8),
                            GestureDetector(
                              onTap: () => setState(() => _balanceVisible = !_balanceVisible),
                              child: Icon(
                                _balanceVisible ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                                color: AppColors.textSecondary,
                                size: 20,
                              ),
                            ),
                          ],
                        ),
                        const Text('Tổng số dư', style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                      ],
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                // ===== Card ví của tôi =====
                _WalletCard(),

                const SizedBox(height: 24),

                // ===== Báo cáo tháng =====
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Báo cáo tháng này', style: TextStyle(color: AppColors.textSecondary, fontSize: 14)),
                    TextButton(
                      onPressed: () => context.go('/reports'),
                      child: const Text('Xem báo cáo', style: TextStyle(color: AppColors.primary, fontSize: 13)),
                    ),
                  ],
                ),

                // ===== Chart Card =====
                _ChartCard(
                  income: income,
                  expense: expense,
                  currentMonthTx: currentMonthTx,
                  selectedMonth: _selectedMonth,
                ),

                const SizedBox(height: 8),

                // ===== Chi tiêu nhiều nhất =====
                _TopCategoryCard(currentMonthTx: currentMonthTx),



                // ===== Giao dịch gần đây =====
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Giao dịch gần đây', style: TextStyle(color: AppColors.textSecondary, fontSize: 14)),
                    TextButton(
                      onPressed: () => context.go('/transactions'),
                      child: const Text('Xem tất cả', style: TextStyle(color: AppColors.primary, fontSize: 13)),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // Recent transactions
                Container(
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    children: recentTx.asMap().entries.map((entry) {
                      final tx = entry.value;
                      final isLast = entry.key == recentTx.length - 1;
                      return _TransactionTile(transaction: tx, showDivider: !isLast);
                    }).toList(),
                  ),
                ),

                const SizedBox(height: 100), // Bottom nav space
              ]),
            ),
          ),
        ],
      );
  }
}

// ===== Wallet Card =====
class _WalletCard extends ConsumerWidget {
  const _WalletCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final walletsAsync = ref.watch(walletsProvider);
    final familyWalletsAsync = ref.watch(familyWalletsProvider);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Ví của tôi',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15, color: AppColors.textPrimary)),
              TextButton(
                onPressed: () => context.go('/wallet'),
                child: const Text('Xem tất cả', style: TextStyle(color: AppColors.primary, fontSize: 13)),
              ),
            ],
          ),
          walletsAsync.when(
            data: (wallets) {
              final familyWallets = familyWalletsAsync.valueOrNull ?? [];
              final familyTotal = familyWallets.fold(0.0, (sum, w) => sum + w.balance);
              
              if (wallets.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Text('Chưa có ví nào', style: TextStyle(color: AppColors.textSecondary)),
                );
              }
              final totalBalance = wallets.fold(0.0, (sum, w) => sum + w.balance);
              return Column(
                children: [
                  // Tổng gia đình
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        Container(
                          width: 36, height: 36,
                          decoration: BoxDecoration(
                            color: AppColors.income.withAlpha(40),
                            borderRadius: BorderRadius.circular(9),
                          ),
                          child: const Icon(Icons.group_rounded, color: AppColors.income, size: 18),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(child: Text('Tổng ví gia đình',
                          style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.textPrimary, fontSize: 14))),
                        Text(
                          FormatUtils.formatAmount(familyTotal),
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: familyTotal >= 0 ? AppColors.income : AppColors.expense,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Tổng cộng cá nhân
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        Container(
                          width: 36, height: 36,
                          decoration: BoxDecoration(
                            color: AppColors.primary.withAlpha(40),
                            borderRadius: BorderRadius.circular(9),
                          ),
                          child: const Icon(Icons.account_balance_wallet, color: AppColors.primary, size: 18),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(child: Text('Tổng tất cả ví của tôi',
                          style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.textPrimary, fontSize: 14))),
                        Text(
                          FormatUtils.formatAmount(totalBalance),
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: totalBalance >= 0 ? AppColors.income : AppColors.expense,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const Divider(height: 1, color: AppColors.divider),
                  const SizedBox(height: 6),
                  // Từng ví
                  ...wallets.map((w) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 5),
                    child: Row(
                      children: [
                        Container(
                          width: 30, height: 30,
                          decoration: BoxDecoration(
                            color: w.color.withAlpha(40),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(w.icon, color: w.color, size: 15),
                        ),
                        const SizedBox(width: 10),
                        Expanded(child: Text(w.name,
                          style: const TextStyle(color: AppColors.textPrimary, fontSize: 13, fontWeight: FontWeight.w500))),
                        Text(FormatUtils.formatAmount(w.balance),
                          style: TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w600,
                            color: w.balance >= 0 ? AppColors.textPrimary : AppColors.expense)),
                      ],
                    ),
                  )),
                ],
              );
            },
            loading: () => const Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (e, _) => const Text('Lỗi tải ví', style: TextStyle(color: AppColors.expense)),
          ),
        ],
      ),
    );
  }
}



// ===== Chart Card (Interactive) =====
class _ChartCard extends ConsumerStatefulWidget {
  final double income;
  final double expense;
  final List<TransactionModel> currentMonthTx;
  final DateTime selectedMonth;

  const _ChartCard({
    required this.income,
    required this.expense,
    required this.currentMonthTx,
    required this.selectedMonth,
  });

  @override
  ConsumerState<_ChartCard> createState() => _ChartCardState();
}

class _ChartCardState extends ConsumerState<_ChartCard> with SingleTickerProviderStateMixin {
  String? _selected; // null | 'expense' | 'income'
  late AnimationController _aniCtrl;
  late Animation<double> _expandAnim;

  @override
  void initState() {
    super.initState();
    _aniCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 300));
    _expandAnim = CurvedAnimation(parent: _aniCtrl, curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    _aniCtrl.dispose();
    super.dispose();
  }

  void _toggle(String type) {
    setState(() {
      if (_selected == type) {
        _selected = null;
        _aniCtrl.reverse();
      } else {
        _selected = type;
        _aniCtrl.forward();
      }
    });
  }

  List<FlSpot> _buildSpots(String type) {
    final daysInMonth = DateUtils.getDaysInMonth(widget.selectedMonth.year, widget.selectedMonth.month);
    final dailyMap = <int, double>{};
    for (final tx in widget.currentMonthTx) {
      if (tx.type == type) {
        dailyMap[tx.date.day] = (dailyMap[tx.date.day] ?? 0) + tx.amount;
      }
    }
    // Cumulative sum
    double running = 0;
    final spots = <FlSpot>[];
    for (int d = 1; d <= daysInMonth; d++) {
      running += dailyMap[d] ?? 0;
      spots.add(FlSpot(d.toDouble(), running));
    }
    return spots;
  }

  @override
  Widget build(BuildContext context) {
    final isExpense = _selected == 'expense';
    final isIncome = _selected == 'income';
    final color = isExpense ? AppColors.expense : AppColors.income;
    final spots = _selected != null ? _buildSpots(_selected!) : <FlSpot>[];
    final maxY = spots.isEmpty ? 1.0 : (spots.map((s) => s.y).reduce((a, b) => a > b ? a : b) * 1.2).clamp(1.0, double.infinity);
    final daysInMonth = DateUtils.getDaysInMonth(widget.selectedMonth.year, widget.selectedMonth.month);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Hai card bấm được
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => _toggle('expense'),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: isExpense ? AppColors.expense.withAlpha(20) : Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isExpense ? AppColors.expense : Colors.transparent,
                        width: 1.5,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Text('Tổng đã chi', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                            const Spacer(),
                            Icon(isExpense ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                              color: AppColors.expense, size: 16),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          FormatUtils.formatAmount(widget.expense),
                          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: AppColors.expense),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: GestureDetector(
                  onTap: () => _toggle('income'),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: isIncome ? AppColors.income.withAlpha(20) : Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isIncome ? AppColors.income : Colors.transparent,
                        width: 1.5,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Text('Tổng thu', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                            const Spacer(),
                            Icon(isIncome ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                              color: AppColors.income, size: 16),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          FormatUtils.formatAmount(widget.income),
                          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: AppColors.income),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),

          // Line chart - expand/collapse
          SizeTransition(
            sizeFactor: _expandAnim,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 16),
                if (_selected != null && spots.isNotEmpty)
                  SizedBox(
                    height: 130,
                    child: LineChart(
                      LineChartData(
                        minX: 1,
                        maxX: daysInMonth.toDouble(),
                        minY: 0,
                        maxY: maxY,
                        gridData: FlGridData(
                          show: true,
                          drawVerticalLine: false,
                          horizontalInterval: maxY / 3,
                          getDrawingHorizontalLine: (_) => FlLine(color: AppColors.divider, strokeWidth: 0.5),
                        ),
                        titlesData: FlTitlesData(
                          leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                          bottomTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              interval: 10,
                              getTitlesWidget: (val, _) {
                                if (val == 1 || val == 10 || val == 20 || val == daysInMonth.toDouble()) {
                                  return Padding(
                                    padding: const EdgeInsets.only(top: 4),
                                    child: Text('${val.toInt()}', style: const TextStyle(fontSize: 9, color: AppColors.textMuted)),
                                  );
                                }
                                return const SizedBox();
                              },
                            ),
                          ),
                        ),
                        borderData: FlBorderData(show: false),
                        lineTouchData: LineTouchData(
                          touchTooltipData: LineTouchTooltipData(
                            getTooltipItems: (spots) => spots.map((s) => LineTooltipItem(
                              FormatUtils.formatCompact(s.y),
                              TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 11),
                            )).toList(),
                          ),
                        ),
                        lineBarsData: [
                          LineChartBarData(
                            spots: spots,
                            isCurved: true,
                            color: color,
                            barWidth: 2.5,
                            dotData: FlDotData(
                              show: true,
                              checkToShowDot: (spot, _) => spot.x == spots.last.x,
                              getDotPainter: (spot, _, __, ___) => FlDotCirclePainter(
                                radius: 4, color: color, strokeColor: Colors.white, strokeWidth: 2,
                              ),
                            ),
                            belowBarData: BarAreaData(
                              show: true,
                              gradient: LinearGradient(
                                begin: Alignment.topCenter, end: Alignment.bottomCenter,
                                colors: [color.withAlpha(60), color.withAlpha(0)],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                else if (_selected != null)
                  Container(
                    height: 80,
                    alignment: Alignment.center,
                    child: Text(
                      'Không có dữ liệu tháng này',
                      style: const TextStyle(color: AppColors.textMuted, fontSize: 13),
                    ),
                  ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
                    const SizedBox(width: 6),
                    Text(
                      _selected == 'expense' ? 'Chi tiêu tích lũy theo ngày' : 'Thu nhập tích lũy theo ngày',
                      style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}



// ===== Top Category =====
class _TopCategoryCard extends StatefulWidget {
  final List<TransactionModel> currentMonthTx;
  const _TopCategoryCard({required this.currentMonthTx});

  @override
  State<_TopCategoryCard> createState() => _TopCategoryCardState();
}

class _TopCategoryCardState extends State<_TopCategoryCard> {
  bool _showWeek = false;

  List<(String, double, int)> _computeTopCategories(bool isWeek) {
    final now = DateTime.now();
    
    // Filter expenses
    var expenses = widget.currentMonthTx.where((t) => t.type == 'expense').toList();
    
    // Filter week if needed
    if (isWeek) {
      final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
      expenses = expenses.where((t) => t.date.isAfter(startOfWeek) || t.date.isAtSameMomentAs(startOfWeek)).toList();
    }
    
    if (expenses.isEmpty) return [];

    final totalExpense = expenses.fold(0.0, (sum, t) => sum + t.amount);
    if (totalExpense == 0) return [];

    // Group by categoryId
    final grouped = <String, double>{};
    for (var tx in expenses) {
      grouped[tx.categoryId] = (grouped[tx.categoryId] ?? 0.0) + tx.amount;
    }

    // Sort descending
    final sorted = grouped.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    
    // Take top 3
    return sorted.take(3).map((e) {
      final percent = ((e.value / totalExpense) * 100).round();
      return (e.key, e.value, percent);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final topCategories = _computeTopCategories(_showWeek);

    return Container(
      margin: const EdgeInsets.only(top: 16),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Chi tiêu nhiều nhất', style: TextStyle(color: AppColors.textSecondary, fontSize: 14)),
              TextButton(
                onPressed: () => context.go('/reports'),
                child: const Text('Xem chi tiết', style: TextStyle(color: AppColors.primary, fontSize: 13)),
              ),
            ],
          ),
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(16)),
            child: Column(
              children: [
                // Week/Month toggle — now interactive!
                Container(
                  margin: const EdgeInsets.all(8),
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(color: AppColors.surfaceLight, borderRadius: BorderRadius.circular(10)),
                  child: Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setState(() => _showWeek = true),
                          child: _ToggleTab(label: 'Tuần', isActive: _showWeek),
                        ),
                      ),
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setState(() => _showWeek = false),
                          child: _ToggleTab(label: 'Tháng', isActive: !_showWeek),
                        ),
                      ),
                    ],
                  ),
                ),
                ...topCategories.map((item) {
                  final cat = MockData.getCategoryById(item.$1);
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    child: Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(color: cat.color.withAlpha(38), borderRadius: BorderRadius.circular(12)),
                          child: Icon(cat.icon, color: cat.color, size: 22),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(cat.name, style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.textPrimary, fontSize: 15)),
                              Text(FormatUtils.formatAmount(item.$2), style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                            ],
                          ),
                        ),
                        Text(
                          '${item.$3}%',
                          style: const TextStyle(color: AppColors.expense, fontWeight: FontWeight.w700, fontSize: 16),
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ToggleTab extends StatelessWidget {
  final String label;
  final bool isActive;
  const _ToggleTab({required this.label, required this.isActive});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: isActive ? AppColors.surface : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: TextStyle(
          color: isActive ? AppColors.textPrimary : AppColors.textMuted,
          fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
          fontSize: 13,
        ),
      ),
    );
  }
}

// ===== Transaction Tile =====
class _TransactionTile extends StatelessWidget {
  final TransactionModel transaction;
  final bool showDivider;
  const _TransactionTile({required this.transaction, this.showDivider = true});

  @override
  Widget build(BuildContext context) {
    final category = MockData.getCategoryById(transaction.categoryId);
    final isIncome = transaction.type == 'income';

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: category.color.withAlpha(38),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(category.icon, color: category.color, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      transaction.note.isNotEmpty ? transaction.note : category.name,
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15, color: AppColors.textPrimary),
                    ),
                    Text(
                      FormatUtils.formatDateLong(transaction.date),
                      style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
              Text(
                FormatUtils.formatAmount(transaction.amount),
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                  color: isIncome ? AppColors.income : AppColors.expense,
                ),
              ),
            ],
          ),
        ),
        if (showDivider)
          const Divider(height: 1, thickness: 0.5, indent: 72, endIndent: 16, color: AppColors.divider),
      ],
    );
  }
}

