import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:math' as math;
import 'package:savemoney/core/constants/app_colors.dart';
import 'package:savemoney/core/utils/format_utils.dart';
import 'package:savemoney/features/savings/data/savings_repository.dart';
import 'package:savemoney/features/gold/presentation/gold_tracker_screen.dart';
import 'package:flutter_svg/flutter_svg.dart';

// ===== MODEL =====
class SavingsGoal {
  final String id;
  final String name;
  final String emoji;
  final double targetAmount;
  double currentAmount;
  final DateTime deadline;
  final Color color;
  final List<SavingsContribution> contributions;

  SavingsGoal({
    required this.id,
    required this.name,
    required this.emoji,
    required this.targetAmount,
    required this.currentAmount,
    required this.deadline,
    required this.color,
    List<SavingsContribution>? contributions,
  }) : contributions = contributions ?? [];

  double get progress => (currentAmount / targetAmount).clamp(0.0, 1.0);
  int get daysLeft => deadline.difference(DateTime.now()).inDays;
  double get dailyRequired => daysLeft > 0 ? ((targetAmount - currentAmount) / daysLeft).clamp(0, double.infinity) : 0;
  double get monthlyRequired => dailyRequired * 30;
  bool get isCompleted => currentAmount >= targetAmount;
}

class SavingsContribution {
  final String id;
  final double amount;
  final DateTime date;
  final String note;

  SavingsContribution({
    required this.id,
    required this.amount,
    required this.date,
    required this.note,
  });
}

// ===== MOCK DATA =====
final mockSavingsGoals = [
  SavingsGoal(
    id: '1',
    name: 'Mua nhà',
    emoji: '🏠',
    targetAmount: 500000000,
    currentAmount: 127500000,
    deadline: DateTime(2026, 12, 31),
    color: const Color(0xFF43A047),
    contributions: [
      SavingsContribution(id: 'c1', amount: 5000000, date: DateTime(2026, 3, 1), note: 'Tháng 3'),
      SavingsContribution(id: 'c2', amount: 10000000, date: DateTime(2026, 2, 1), note: 'Tháng 2'),
    ],
  ),
  SavingsGoal(
    id: '2',
    name: 'Du lịch Nhật Bản',
    emoji: '✈️',
    targetAmount: 50000000,
    currentAmount: 18000000,
    deadline: DateTime(2026, 9, 1),
    color: const Color(0xFFE91E63),
    contributions: [
      SavingsContribution(id: 'c3', amount: 2000000, date: DateTime(2026, 3, 5), note: 'Tháng 3'),
    ],
  ),
  SavingsGoal(
    id: '3',
    name: 'Quỹ khẩn cấp',
    emoji: '🛡️',
    targetAmount: 30000000,
    currentAmount: 30000000,
    deadline: DateTime(2026, 6, 1),
    color: const Color(0xFF1E88E5),
    contributions: [],
  ),
];

// ===== MAIN SCREEN =====
class SavingsScreen extends ConsumerStatefulWidget {
  const SavingsScreen({super.key});

  @override
  ConsumerState<SavingsScreen> createState() => _SavingsScreenState();
}

class _SavingsScreenState extends ConsumerState<SavingsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final savingsAsync = ref.watch(savingsProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Tiết kiệm'),
        actions: [
          AnimatedBuilder(
            animation: _tabController,
            builder: (_, __) => _tabController.index == 0
                ? IconButton(
                    icon: const Icon(Icons.add_circle_outline, color: AppColors.primary),
                    onPressed: () => _showAddGoalSheet(context),
                  )
                : const SizedBox.shrink(),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: const Color(0xFFFFD700),
          indicatorWeight: 2.5,
          labelColor: const Color(0xFFFFD700),
          unselectedLabelColor: AppColors.textSecondary,
          labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
          unselectedLabelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
          tabs: [
            const Tab(text: '💰  Mục tiêu'),
            Tab(child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SvgPicture.asset(
                  'assets/icons/yuanbao-2.svg',
                  width: 14, height: 14,
                  colorFilter: const ColorFilter.mode(Color(0xFFFFD700), BlendMode.srcIn),
                ),
                const SizedBox(width: 6),
                const Text('Tích Vàng'),
              ],
            )),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        physics: const NeverScrollableScrollPhysics(),
        children: [
          // ── Tab 1: Mục tiêu tiết kiệm ──────────────────────
          savingsAsync.when(
            data: (goals) => goals.isEmpty
                ? _buildEmpty(context)
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                    itemCount: goals.length,
                    itemBuilder: (context, i) => Dismissible(
                      key: Key(goals[i].id),
                      direction: DismissDirection.endToStart,
                      background: Container(
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.only(right: 20),
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: AppColors.expense.withAlpha(30),
                          borderRadius: BorderRadius.circular(20),
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
                        title: const Text('Xóa mục tiêu?', style: TextStyle(color: AppColors.textPrimary)),
                        content: Text('Xóa "${goals[i].name}" và toàn bộ lịch sử tiết kiệm?', style: const TextStyle(color: AppColors.textSecondary)),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Huỷ')),
                          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Xóa', style: TextStyle(color: AppColors.expense))),
                        ],
                      ),
                    );
                    if (confirmed == true) {
                      await ref.read(savingsRepositoryProvider).deleteGoal(goals[i].id);
                    }
                    return false; // Firestore update will remove from list
                  },
                  child: _GoalCard(
                    goal: goals[i],
                    onAddMoney: () => _showAddMoneySheet(context, goals[i]),
                    onDelete: () async {
                      final confirmed = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          backgroundColor: AppColors.surface,
                          title: const Text('Xóa mục tiêu?', style: TextStyle(color: AppColors.textPrimary)),
                          content: Text('Xóa "${goals[i].name}" và toàn bộ lịch sử tiết kiệm?', style: const TextStyle(color: AppColors.textSecondary)),
                          actions: [
                            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Huỷ')),
                            TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Xóa', style: TextStyle(color: AppColors.expense))),
                          ],
                        ),
                      );
                      if (confirmed == true) {
                        await ref.read(savingsRepositoryProvider).deleteGoal(goals[i].id);
                      }
                    },
                    onTap: () => Navigator.of(context, rootNavigator: true).push(
                      MaterialPageRoute(builder: (_) => _GoalDetailScreen(goal: goals[i])),
                    ),
                  ),
                ),
              ),
        loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, st) => Center(child: Text('Lỗi: $e')),
          ),
          // ── Tab 2: Tích Vàng ─────────────────────────────────
          const GoldTrackerScreen(),
        ],
      ),
    );
  }

  Widget _buildEmpty(BuildContext context) => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset('assets/images/pig_0.png', width: 140, height: 140),
            const SizedBox(height: 16),
            const Text('Chưa có mục tiêu tiết kiệm', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
            const SizedBox(height: 8),
            const Text('Tạo mục tiêu đầu tiên của bạn\nđể bắt đầu hành trình tiết kiệm!', textAlign: TextAlign.center, style: TextStyle(color: AppColors.textSecondary)),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => _showAddGoalSheet(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary.withAlpha(25), // 10% opacity
                foregroundColor: AppColors.primary,
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
              ),
              icon: const Icon(Icons.add_circle_outline, size: 20),
              label: const Text('Thêm mục tiêu', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      );

  void _showAddGoalSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AddGoalSheet(
        onSave: (goal) {
          ref.read(savingsRepositoryProvider).addGoal(
            name: goal.name,
            emoji: goal.emoji,
            targetAmount: goal.targetAmount,
            deadline: goal.deadline,
            color: goal.color,
          );
          Navigator.pop(context);
        },
      ),
    );
  }

  void _showAddMoneySheet(BuildContext context, SavingsGoal goal) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AddMoneySheet(
        goal: goal,
        onSave: (amount, note) {
          ref.read(savingsRepositoryProvider).addContribution(
            goalId: goal.id,
            goalName: goal.name,
            amount: amount,
            note: note,
            currentAmount: goal.currentAmount,
            targetAmount: goal.targetAmount,
          );
          Navigator.pop(context);
        },
      ),
    );
  }
}

// ===== GOAL CARD =====
class _GoalCard extends StatelessWidget {
  final SavingsGoal goal;
  final VoidCallback onAddMoney;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _GoalCard({required this.goal, required this.onAddMoney, required this.onTap, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: goal.isCompleted ? goal.color.withAlpha(102) : AppColors.border,
            width: goal.isCompleted ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            // Mini piggy bank
            _MiniPiggyBank(progress: goal.progress, size: 72),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(goal.emoji, style: const TextStyle(fontSize: 16)),
                      const SizedBox(width: 6),
                      Expanded(child: Text(goal.name, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textPrimary))),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    goal.isCompleted ? '🎉 Hoàn thành!' : '${goal.daysLeft} ngày còn lại',
                    style: TextStyle(fontSize: 12, color: goal.isCompleted ? goal.color : AppColors.textSecondary),
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: goal.progress,
                      minHeight: 6,
                      backgroundColor: AppColors.surfaceLight,
                      valueColor: AlwaysStoppedAnimation<Color>(goal.color),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(FormatUtils.formatCompact(goal.currentAmount), style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: goal.color)),
                      Text('/ ${FormatUtils.formatCompact(goal.targetAmount)}', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            if (!goal.isCompleted)
              GestureDetector(
                onTap: onAddMoney,
                child: Container(
                  width: 36, height: 36,
                  decoration: BoxDecoration(color: goal.color.withAlpha(31), shape: BoxShape.circle),
                  child: Icon(Icons.add, color: goal.color, size: 20),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ===== HELPER: chọn ảnh theo progress =====
String _getPiggyImage(double progress) {
  if (progress >= 0.875) return 'assets/images/pig_100.png'; // 87-100%: đầy tràn
  if (progress >= 0.625) return 'assets/images/pig_75.png';  // 62-87%: gần đầy
  if (progress >= 0.375) return 'assets/images/pig_50.png';  // 37-62%: nửa đầy
  if (progress >= 0.125) return 'assets/images/pig_25.png';  // 12-37%: ít tiền
  return 'assets/images/pig_0.png';                          // 0-12%: trống
}

// ===== MINI PIGGY BANK (dùng ảnh + clipping để mô phỏng fill) =====
class _MiniPiggyBank extends StatelessWidget {
  final double progress;
  final double size;
  const _MiniPiggyBank({required this.progress, required this.size});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Golden glow halo (rất nhẹ vì ảnh đã có glow)
          if (progress > 0)
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFFFD700).withAlpha((progress * 25).toInt()),
                      blurRadius: 30,
                      spreadRadius: 0,
                    ),
                  ],
                ),
              ),
            ),
          // Ảnh piggy bank đúng trạng thái
          Image.asset(
            _getPiggyImage(progress),
            width: size,
            height: size,
            fit: BoxFit.contain,
          ),
          // Completion badge
          if (progress >= 1.0)
            Positioned(
              right: 0,
              bottom: 0,
              child: Container(
                width: 22, height: 22,
                decoration: const BoxDecoration(color: Color(0xFF43A047), shape: BoxShape.circle),
                child: const Icon(Icons.check, color: Colors.white, size: 14),
              ),
            ),
        ],
      ),
    );
  }
}

// ===== GOAL DETAIL SCREEN với Animation premium =====
class _GoalDetailScreen extends StatefulWidget {
  final SavingsGoal goal;
  const _GoalDetailScreen({required this.goal});

  @override
  State<_GoalDetailScreen> createState() => _GoalDetailScreenState();
}

class _GoalDetailScreenState extends State<_GoalDetailScreen>
    with TickerProviderStateMixin {
  late AnimationController _bounceController;
  late AnimationController _glowController;
  late AnimationController _fillController;
  late AnimationController _coinController;

  late Animation<double> _bounceAnim;
  late Animation<double> _glowAnim;
  late Animation<double> _fillAnim;
  late Animation<double> _coinAnim;

  double _targetFill = 0;
  bool _isAdding = false;
  final List<_CoinParticle> _coins = [];
  final _random = math.Random();

  @override
  void initState() {
    super.initState();
    _targetFill = widget.goal.progress;

    _bounceController = AnimationController(vsync: this, duration: const Duration(milliseconds: 500));
    _glowController = AnimationController(vsync: this, duration: const Duration(milliseconds: 300));
    _fillController = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
    _coinController = AnimationController(vsync: this, duration: const Duration(milliseconds: 1500)); // Rơi chậm 1.5s

    _bounceAnim = TweenSequence([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.04).chain(CurveTween(curve: Curves.easeOut)), weight: 40),
      TweenSequenceItem(tween: Tween(begin: 1.04, end: 0.98).chain(CurveTween(curve: Curves.easeInOut)), weight: 30),
      TweenSequenceItem(tween: Tween(begin: 0.98, end: 1.0).chain(CurveTween(curve: Curves.easeOut)), weight: 30),
    ]).animate(_bounceController);

    _glowAnim = Tween(begin: 0.0, end: 1.0).animate(CurvedAnimation(parent: _glowController, curve: Curves.easeOut));
    _fillAnim = Tween(begin: _targetFill, end: _targetFill).animate(CurvedAnimation(parent: _fillController, curve: Curves.easeOut));
    _coinAnim = Tween(begin: 0.0, end: 1.0).animate(CurvedAnimation(parent: _coinController, curve: Curves.easeIn));

    // Fade glow in
    _glowController.forward();
  }

  @override
  void dispose() {
    _bounceController.dispose();
    _glowController.dispose();
    _fillController.dispose();
    _coinController.dispose();
    super.dispose();
  }

  void _addMoney(double amount, String note, {bool saveHistory = true}) {
    setState(() {
      _isAdding = true;
      widget.goal.currentAmount += amount;
      if (saveHistory) {
        widget.goal.contributions.insert(0, SavingsContribution(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          amount: amount,
          date: DateTime.now(),
          note: note,
        ));
      }

      // Spawn coins dropping from above
      _coins.clear();
      for (int i = 0; i < 6; i++) {
        _coins.add(_CoinParticle(
          x: 0.2 + _random.nextDouble() * 0.6,
          delay: i * 0.10,
        ));
      }
    });

    // 📈 Fill animation: ease-OUT (smooth rise when adding)
    final oldFill = _targetFill;
    _targetFill = widget.goal.progress;
    _fillController.duration = const Duration(milliseconds: 600);
    _fillAnim = Tween(begin: oldFill, end: _targetFill).animate(
      CurvedAnimation(parent: _fillController, curve: Curves.easeOut),
    );
    _fillController.forward(from: 0);

    // 🐷 Bounce: scale 1 → 1.03 → 1 spring
    _bounceController.forward(from: 0);

    // ✨ Coin drop animation
    _coinController.forward(from: 0).then((_) {
      if (mounted) setState(() { _isAdding = false; _coins.clear(); });
    });

    // ✨ Glow pulse: bright 200ms then settle
    _glowController.animateTo(1.0, duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut).then((_) {
      _glowController.animateTo(0.5, duration: const Duration(milliseconds: 300),
          curve: Curves.easeIn);
    });
  }

  void _removeMoney(double amount, String note, {bool saveHistory = true}) {
    if (widget.goal.currentAmount <= 0) return;
    
    // Lưu tạm progress cũ để animate fill tụt xuống
    final double oldProgress = widget.goal.progress;
    final double oldFill = _fillAnim.value;

    setState(() {
      _isAdding = false; // State để biết đang Rút
      widget.goal.currentAmount = (widget.goal.currentAmount - amount).clamp(0, double.infinity);
      if (saveHistory) {
        widget.goal.contributions.insert(0, SavingsContribution(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          amount: -amount,
          date: DateTime.now(),
          note: note.isEmpty ? 'Rút tiền' : note,
        ));
      }
    });

    final double newFill = widget.goal.progress;

    // 📉 Fill animation: ease-IN (gradual drop when removing)
    final TweenSequence<double> removeAnim = TweenSequence([
      TweenSequenceItem(tween: Tween(begin: oldFill, end: newFill).chain(CurveTween(curve: Curves.easeIn)), weight: 100),
    ]);
    _fillAnim = removeAnim.animate(_fillController);
    _fillController.forward(from: 0.0);

    // � Spawn coins flying up
    _coins.clear();
    for (int i = 0; i < 6; i++) {
      _coins.add(_CoinParticle(x: math.Random().nextDouble(), delay: math.Random().nextDouble()));
    }
    _coinController.forward(from: 0);

    // �🐖 Piggy Bounce (Khi rút thì heo vẫn nảy lên giật mình)
    _bounceController.forward(from: 0.0);
    // ✨ Glow chớp nhẹ biểu hiện có giao dịch
    _glowAnim = Tween(begin: 0.0, end: 0.6).animate(CurvedAnimation(parent: _glowController, curve: Curves.easeOut));
    _glowController.forward(from: 0.0);
  }

  @override
  Widget build(BuildContext context) {
    final goal = widget.goal;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Row(
          children: [
            Text(goal.emoji, style: const TextStyle(fontSize: 22)),
            const SizedBox(width: 8),
            Text(goal.name),
          ],
        ),
        actions: [
          if (!goal.isCompleted)
            TextButton(
              onPressed: () => _showAddMoneySheet(context, goal),
              child: Text('+ Nạp', style: TextStyle(color: goal.color, fontWeight: FontWeight.w700)),
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Big piggy bank hero
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: goal.color.withAlpha(51)),
              ),
              child: Column(
                children: [
                  // Animated piggy bank
                  SizedBox(
                    height: 220,
                    child: AnimatedBuilder(
                      animation: Listenable.merge([_bounceController, _glowController, _fillController, _coinController]),
                      builder: (context, child) {
                        return Stack(
                          alignment: Alignment.center,
                          children: [
                            // Coins dropping from above
                            if (_coins.isNotEmpty)
                              ..._coins.map((coin) {
                                // T tính toán tiến trình (0.0 -> 1.0)
                                double t = (_coinAnim.value - coin.delay).clamp(0.0, 1.0);
                                if (t <= 0) return const SizedBox.shrink();
                                return Positioned(
                                  left: coin.x * 200 - 12, // Dàn bay ngang
                                  top: _isAdding 
                                      ? (t * 180 - 20)            // Nạp: Rơi từ trên (-20) xuống heo (160)
                                      : ((1.0 - t) * 180 - 40),   // Rút: Bay từ heo (140) ngược lên trời (-40)
                                  child: Opacity(
                                    opacity: (1.0 - t).clamp(0.0, 1.0), // Càng rơi xa càng mờ
                                    child: Transform(
                                      transform: Matrix4.identity()
                                        ..setEntry(3, 2, 0.001) // perspective
                                        ..rotateZ(t * 3.14 * (_isAdding ? 2 : -2) + coin.delay * 10) // spin Z ngược chiều nếu bay lên
                                        ..rotateX(t * 3.14 * (_isAdding ? 4 : -4)), // flip vertically
                                      alignment: Alignment.center,
                                      child: Container(
                                        width: 28, height: 14, // Tỉ lệ tiền giấy
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFFFB300), // Vàng cam chuẩn tông gold
                                          borderRadius: BorderRadius.circular(2),
                                          border: Border.all(color: const Color(0xFFFFE082), width: 1), // Viền sáng
                                          boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 2))],
                                        ),
                                        child: const Center(
                                          child: Text('\$', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: Color(0xFFFFF8E1))),
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              }).toList(),

                            // Glow corona (effect cực nhẹ vì ảnh AI đã có glow 3D)
                            Transform.scale(
                              scale: _bounceAnim.value * 1.05,
                              child: Container(
                                width: 120, height: 120,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(0xFFFFD700).withAlpha((_glowAnim.value * 35).toInt()),
                                      blurRadius: 50,
                                      spreadRadius: 5,
                                    ),
                                  ],
                                ),
                              ),
                            ),

                            // 🐷 Piggy bank: bounce + AnimatedSwitcher đổi ảnh khi đủ fill
                            Transform.scale(
                              scale: _bounceAnim.value,
                              child: AnimatedSwitcher(
                                duration: const Duration(milliseconds: 300),
                                transitionBuilder: (child, anim) => FadeTransition(
                                  opacity: anim, child: child,
                                ),
                                child: Image.asset(
                                  _getPiggyImage(_fillAnim.value),
                                  key: ValueKey(_getPiggyImage(_fillAnim.value)),
                                  width: 180,
                                  height: 180,
                                  fit: BoxFit.contain,
                                ),
                              ),
                            ),

                            // Fill level indicator overlay (bottom arc)
                            Positioned(
                              bottom: 8,
                              child: Container(
                                width: 140,
                                height: 8,
                                decoration: BoxDecoration(
                                  color: AppColors.surfaceLight,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(4),
                                  child: FractionallySizedBox(
                                    widthFactor: _fillAnim.value,
                                    alignment: Alignment.centerLeft,
                                    child: Container(
                                      decoration: BoxDecoration(
                                        gradient: const LinearGradient(
                                          colors: [Color(0xFFFFA000), Color(0xFFFFD700)],
                                        ),
                                        borderRadius: BorderRadius.circular(4),
                                        boxShadow: [BoxShadow(color: const Color(0xFFFFD700).withAlpha(128), blurRadius: 4)],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),

                            // Sparkle particles
                            if (_isAdding)
                              ...[
                                Positioned(top: 20 + _random.nextDouble() * 10, left: 30, child: _SparkleWidget(value: _glowAnim.value)),
                                Positioned(top: 40, right: 20, child: _SparkleWidget(value: _glowAnim.value * 0.8)),
                                Positioned(bottom: 40, left: 20, child: _SparkleWidget(value: _glowAnim.value * 0.6)),
                              ],
                          ],
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 16),
                  AnimatedBuilder(
                    animation: _fillAnim,
                    builder: (_, __) => Text(
                      FormatUtils.formatAmount(goal.currentAmount),
                      style: TextStyle(fontSize: 32, fontWeight: FontWeight.w800, color: goal.color),
                    ),
                  ),
                  Text('/ ${FormatUtils.formatAmount(goal.targetAmount)}', style: const TextStyle(fontSize: 16, color: AppColors.textSecondary)),
                  const SizedBox(height: 16),
                  AnimatedBuilder(
                    animation: _fillAnim,
                    builder: (_, __) => ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(
                        value: _fillAnim.value,
                        minHeight: 12,
                        backgroundColor: AppColors.surfaceLight,
                        valueColor: AlwaysStoppedAnimation<Color>(goal.color),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  AnimatedBuilder(
                    animation: _fillAnim,
                    builder: (_, __) => Text(
                      '${(_fillAnim.value * 100).toStringAsFixed(1)}% hoàn thành',
                      style: TextStyle(fontWeight: FontWeight.w700, color: goal.color),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Stats
            Row(
              children: [
                Expanded(child: _StatCard(label: 'Ngày còn lại', value: '${goal.daysLeft}', icon: Icons.calendar_today, color: goal.color)),
                const SizedBox(width: 12),
                Expanded(child: _StatCard(label: 'Cần/tháng', value: FormatUtils.formatCompact(goal.monthlyRequired), icon: Icons.repeat, color: AppColors.income)),
                const SizedBox(width: 12),
                Expanded(child: _StatCard(label: 'Cần/ngày', value: FormatUtils.formatCompact(goal.dailyRequired), icon: Icons.today, color: AppColors.expense)),
              ],
            ),
            const SizedBox(height: 24),

            const Text('Lịch sử nạp tiền', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
            const SizedBox(height: 12),
            if (goal.contributions.isEmpty)
              Container(
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(16)),
                child: const Center(
                  child: Text('Chưa có lần nạp nào\nBắt đầu tiết kiệm ngay! 🐷', textAlign: TextAlign.center, style: TextStyle(color: AppColors.textSecondary)),
                ),
              )
            else
              ...goal.contributions.map((c) {
                final isAdd = c.amount >= 0;
                return Dismissible(
                  key: Key(c.id),
                  direction: DismissDirection.endToStart,
                  background: Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    decoration: BoxDecoration(color: AppColors.expense, borderRadius: BorderRadius.circular(12)),
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 20),
                    child: const Icon(Icons.delete_outline, color: Colors.white),
                  ),
                  onDismissed: (_) {
                    // Undo tiền
                    if (isAdd) {
                      _removeMoney(c.amount.abs(), 'Xoá bản ghi', saveHistory: false);
                    } else {
                      _addMoney(c.amount.abs(), 'Xoá bản ghi', saveHistory: false);
                    }
                    setState(() { goal.contributions.remove(c); });
                  },
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(12)),
                    child: Row(
                      children: [
                        Container(
                          width: 40, height: 40,
                          decoration: BoxDecoration(color: (isAdd ? goal.color : AppColors.expense).withAlpha(31), shape: BoxShape.circle),
                          child: Center(
                            child: isAdd 
                                ? Image.asset('assets/images/pig.png', width: 20, height: 20, color: const Color(0xFFFFD700)) // Icon pig màu Gold
                                : const Icon(Icons.money_off, color: AppColors.expense, size: 20),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(c.note.isEmpty ? (isAdd ? 'Nạp tiết kiệm' : 'Rút tiền') : c.note, style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                              Text(FormatUtils.formatDateShort(c.date), style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                            ],
                          ),
                        ),
                        Text(
                          '${isAdd ? '+' : '-'}${FormatUtils.formatAmount(c.amount.abs())}', 
                          style: TextStyle(fontWeight: FontWeight.w700, color: isAdd ? goal.color : AppColors.expense, fontSize: 15)
                        ),
                      ],
                    ),
                  ),
                );
              }),
          ],
        ),
      ),
      bottomNavigationBar: Container(
        padding: EdgeInsets.fromLTRB(16, 12, 16, MediaQuery.of(context).padding.bottom + 12),
        decoration: BoxDecoration(
          color: AppColors.background,
          border: const Border(top: BorderSide(color: AppColors.divider, width: 0.5)),
          boxShadow: [
            BoxShadow(color: Colors.black.withAlpha(40), blurRadius: 20, offset: const Offset(0, -4)),
          ],
        ),
        child: Row(
          children: [
            // Rút tiền — compact icon button
            GestureDetector(
              onTap: () => _showAddMoneySheet(context, goal, isWithdraw: true),
              child: Container(
                width: 52, height: 52,
                decoration: BoxDecoration(
                  color: AppColors.expense.withAlpha(18),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.expense.withAlpha(80), width: 1.5),
                ),
                child: const Icon(Icons.arrow_upward_rounded, color: AppColors.expense, size: 22),
              ),
            ),
            const SizedBox(width: 12),
            // Nạp tiền — full width primary gradient
            Expanded(
              child: GestureDetector(
                onTap: goal.isCompleted ? null : () => _showAddMoneySheet(context, goal, isWithdraw: false),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  height: 52,
                  decoration: BoxDecoration(
                    gradient: goal.isCompleted ? null : LinearGradient(
                      colors: [goal.color, goal.color.withAlpha(200)],
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                    ),
                    color: goal.isCompleted ? AppColors.surfaceLight : null,
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: goal.isCompleted ? null : [
                      BoxShadow(color: goal.color.withAlpha(90), blurRadius: 12, offset: const Offset(0, 4)),
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        goal.isCompleted ? Icons.check_circle_outline : Icons.add_rounded,
                        color: Colors.white, size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        goal.isCompleted ? 'Đã hoàn thành 🎉' : 'Nạp tiền vào quỹ',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddMoneySheet(BuildContext context, SavingsGoal goal, {bool isWithdraw = false}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _AddMoneySheet(
        goal: goal,
        isWithdraw: isWithdraw,
        onSave: (amount, note) {
          Navigator.pop(context);
          if (isWithdraw) {
            _removeMoney(amount, note);
          } else {
            _addMoney(amount, note);
          }
        },
      ),
    );
  }
}


// ===== COIN PARTICLE =====
class _CoinParticle {
  final double x;
  final double delay;
  _CoinParticle({required this.x, required this.delay});
}

// ===== SPARKLE WIDGET =====
class _SparkleWidget extends StatelessWidget {
  final double value;
  const _SparkleWidget({required this.value});

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: value.clamp(0.0, 1.0),
      child: const Text('✨', style: TextStyle(fontSize: 14)),
    );
  }
}

// ===== STAT CARD =====
class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  const _StatCard({required this.label, required this.value, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(14)),
      child: Column(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 6),
          Text(value, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: color)),
          Text(label, style: const TextStyle(fontSize: 10, color: AppColors.textSecondary), textAlign: TextAlign.center),
        ],
      ),
    );
  }
}

// ===== ADD MONEY SHEET =====
class _AddMoneySheet extends StatefulWidget {
  final SavingsGoal goal;
  final bool isWithdraw;
  final Function(double amount, String note) onSave;
  const _AddMoneySheet({required this.goal, required this.onSave, this.isWithdraw = false});

  @override
  State<_AddMoneySheet> createState() => _AddMoneySheetState();
}

class _AddMoneySheetState extends State<_AddMoneySheet> {
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(context).viewInsets.bottom + 90),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Image.asset(_getPiggyImage(widget.goal.progress), width: 32, height: 32),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  '${widget.isWithdraw ? 'Rút từ' : 'Nạp vào'} "${widget.goal.name}"',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _amountController,
            keyboardType: TextInputType.number,
            inputFormatters: [FormatUtils.moneyInputFormatter],
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800,
                color: widget.isWithdraw ? AppColors.expense : widget.goal.color),
            decoration: InputDecoration(
              hintText: '0',
              hintStyle: const TextStyle(color: AppColors.textMuted),
              filled: true,
              fillColor: AppColors.background,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              prefixText: widget.isWithdraw ? '- ' : '+ ',
              prefixStyle: TextStyle(color: widget.isWithdraw ? AppColors.expense : widget.goal.color, fontWeight: FontWeight.w800, fontSize: 20),
              suffixText: 'đ',
              suffixStyle: TextStyle(color: widget.isWithdraw ? AppColors.expense : widget.goal.color, fontWeight: FontWeight.w600, fontSize: 16),
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 6, runSpacing: 6,
            children: [500000, 1000000, 2000000, 5000000, 10000000].map((a) =>
              GestureDetector(
                onTap: () => setState(() {
                  _amountController.text = FormatUtils.formatInputNumber(a.toString());
                }),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: (widget.isWithdraw ? AppColors.expense : widget.goal.color).withAlpha(30),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(FormatUtils.formatCompact(a.toDouble()),
                    style: TextStyle(fontSize: 12, color: widget.isWithdraw ? AppColors.expense : widget.goal.color, fontWeight: FontWeight.w600)),
                ),
              ),
            ).toList(),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _noteController,
            style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
            decoration: InputDecoration(
              hintText: 'Ghi chú (tùy chọn)',
              hintStyle: const TextStyle(color: AppColors.textMuted, fontSize: 14),
              filled: true,
              fillColor: AppColors.background,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              prefixIcon: const Icon(Icons.notes, color: AppColors.textMuted, size: 18),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.textSecondary,
                    side: const BorderSide(color: AppColors.divider),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 13),
                  ),
                  child: const Text('Hủy', style: TextStyle(fontSize: 14)),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 2,
                child: ElevatedButton(
                  onPressed: () {
                    final raw = _amountController.text.replaceAll('.', '').replaceAll(',', '');
                    final amount = double.tryParse(raw) ?? 0;
                    if (amount > 0) widget.onSave(amount, _noteController.text);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: widget.isWithdraw ? AppColors.expense : widget.goal.color,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    elevation: 0,
                  ),
                  child: Text(
                    widget.isWithdraw ? 'Xác nhận rút ↓' : 'Xác nhận nạp 💰',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ===== ADD GOAL SHEET =====
class _AddGoalSheet extends StatefulWidget {
  final Function(SavingsGoal) onSave;
  const _AddGoalSheet({required this.onSave});

  @override
  State<_AddGoalSheet> createState() => _AddGoalSheetState();
}

class _AddGoalSheetState extends State<_AddGoalSheet> {
  final _nameController = TextEditingController();
  final _targetController = TextEditingController();
  String _selectedEmoji = '🎯';
  Color _selectedColor = AppColors.primary;
  DateTime _deadline = DateTime.now().add(const Duration(days: 365));

  final _emojis = ['🎯', '🏠', '🚗', '✈️', '💍', '📚', '🏥', '🖥️', '🐷', '💰', '🎓', '🌴'];
  final _colors = [AppColors.primary, const Color(0xFFE91E63), const Color(0xFF1E88E5), const Color(0xFFFB8C00), const Color(0xFF5E35B1), const Color(0xFF00897B)];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(context).viewInsets.bottom + 90),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Image.asset('assets/images/pig_0_v2.png', width: 32, height: 32,
                  errorBuilder: (_, __, ___) => const Text('💰', style: TextStyle(fontSize: 28))),
                const SizedBox(width: 10),
                const Text('Tạo mục tiêu mới',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
              ],
            ),
            const SizedBox(height: 16),

            // Chọn emoji
            const Text('Biểu tượng', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6, runSpacing: 6,
              children: _emojis.map((e) => GestureDetector(
                onTap: () => setState(() => _selectedEmoji = e),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  width: 40, height: 40,
                  decoration: BoxDecoration(
                    color: _selectedEmoji == e ? _selectedColor.withAlpha(50) : AppColors.background,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: _selectedEmoji == e ? _selectedColor : Colors.transparent,
                      width: 1.5,
                    ),
                  ),
                  child: Center(child: Text(e, style: const TextStyle(fontSize: 20))),
                ),
              )).toList(),
            ),
            const SizedBox(height: 14),

            // Tên mục tiêu
            TextField(
              controller: _nameController,
              style: const TextStyle(color: AppColors.textPrimary, fontSize: 15),
              decoration: InputDecoration(
                hintText: 'Tên mục tiêu (vd: Mua xe)',
                hintStyle: const TextStyle(color: AppColors.textMuted, fontSize: 14),
                filled: true, fillColor: AppColors.background,
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                prefixIcon: const Icon(Icons.label_outline, color: AppColors.textMuted, size: 18),
              ),
            ),
            const SizedBox(height: 10),

            // Số tiền mục tiêu
            TextField(
              controller: _targetController,
              keyboardType: TextInputType.number,
              inputFormatters: [FormatUtils.moneyInputFormatter],
              style: TextStyle(color: _selectedColor, fontSize: 15, fontWeight: FontWeight.w700),
              decoration: InputDecoration(
                hintText: 'Số tiền cần tiết kiệm',
                hintStyle: const TextStyle(color: AppColors.textMuted, fontSize: 14),
                filled: true, fillColor: AppColors.background,
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                prefixIcon: Icon(Icons.monetization_on_outlined, color: _selectedColor, size: 18),
                suffixText: 'đ',
                suffixStyle: TextStyle(color: _selectedColor, fontWeight: FontWeight.w600),
              ),
            ),
            const SizedBox(height: 10),

            // Hạn chật
            GestureDetector(
              onTap: () async {
                final date = await showDatePicker(
                  context: context,
                  initialDate: _deadline,
                  firstDate: DateTime.now(),
                  lastDate: DateTime(2035),
                  builder: (ctx, child) => Theme(
                    data: ThemeData.dark().copyWith(colorScheme: ColorScheme.dark(primary: _selectedColor)),
                    child: child!,
                  ),
                );
                if (date != null) setState(() => _deadline = date);
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(12)),
                child: Row(
                  children: [
                    Icon(Icons.calendar_today, color: _selectedColor, size: 18),
                    const SizedBox(width: 10),
                    Text('Ngày hoàn thành: ${FormatUtils.formatDateShort(_deadline)}',
                      style: const TextStyle(color: AppColors.textPrimary, fontSize: 14)),
                    const Spacer(),
                    const Icon(Icons.chevron_right, color: AppColors.textMuted, size: 18),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),

            // Chọn màu
            const Text('Màu sắc', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
            const SizedBox(height: 8),
            Row(
              children: _colors.map((c) => GestureDetector(
                onTap: () => setState(() => _selectedColor = c),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  width: 30, height: 30,
                  margin: const EdgeInsets.only(right: 8),
                  decoration: BoxDecoration(
                    color: c,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: _selectedColor == c ? Colors.white : Colors.transparent,
                      width: 2.5,
                    ),
                    boxShadow: _selectedColor == c
                      ? [BoxShadow(color: c.withAlpha(100), blurRadius: 8)]
                      : null,
                  ),
                  child: _selectedColor == c
                    ? const Icon(Icons.check, color: Colors.white, size: 16)
                    : null,
                ),
              )).toList(),
            ),
            const SizedBox(height: 20),

            // Nút tạo
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.textSecondary,
                      side: const BorderSide(color: AppColors.divider),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: const Text('Hủy', style: TextStyle(fontSize: 14)),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    onPressed: () {
                      final name = _nameController.text.trim();
                      final rawDigits = _targetController.text.replaceAll('.', '').replaceAll(',', '');
                      final target = double.tryParse(rawDigits) ?? 0;
                      if (name.isNotEmpty && target > 0) {
                        widget.onSave(SavingsGoal(
                          id: DateTime.now().millisecondsSinceEpoch.toString(),
                          name: name, emoji: _selectedEmoji,
                          targetAmount: target, currentAmount: 0,
                          deadline: _deadline, color: _selectedColor,
                        ));
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _selectedColor,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      elevation: 0,
                    ),
                    child: const Text('Tạo mục tiêu 💰',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
