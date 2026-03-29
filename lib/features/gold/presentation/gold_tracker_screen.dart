import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:savemoney/core/constants/app_colors.dart';
import 'package:savemoney/features/gold/data/gold_service.dart';
import 'package:savemoney/features/gold/presentation/add_gold_transaction_sheet.dart';
import 'package:savemoney/features/gold/presentation/close_gold_lot_sheet.dart';

const _kGold  = Color(0xFFFFD700);
const _kGreen = Color(0xFF00C875);
const _kRed   = Color(0xFFEE5442);

class GoldTrackerScreen extends StatefulWidget {
  const GoldTrackerScreen({super.key});
  @override
  State<GoldTrackerScreen> createState() => _GoldTrackerScreenState();
}

class _GoldTrackerScreenState extends State<GoldTrackerScreen> {
  final _svc = GoldService();
  GoldSummary? _summary;
  List<GoldTransaction> _txs = [];
  bool _loading = true;
  String? _filter;

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll() async {
    setState(() => _loading = true);
    try {
      final results = await Future.wait([
        _svc.getSummary(),
        _svc.getTransactions(type: _filter),
      ]);
      if (mounted) setState(() {
        _summary = results[0] as GoldSummary;
        _txs     = results[1] as List<GoldTransaction>;
        _loading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi tải dữ liệu: $e', style: const TextStyle(fontSize: 11)),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 10),
          ),
        );
      }
    }
  }

  Future<void> _delete(String id) async {
    await _svc.deleteTransaction(id);
    _loadAll();
  }

  Future<void> _edit(GoldTransaction tx) async {
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => AddGoldTransactionSheet(svc: _svc, existingTx: tx),
    );
    if (ok == true) _loadAll();
  }

  void _openAdd() async {
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => AddGoldTransactionSheet(svc: _svc),
    );
    if (ok == true) _loadAll();
  }

  Future<void> _openCloseLot(GoldTransaction tx) async {
    final marketPrice = _summary?.phuquyBuy ?? 0;
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => CloseGoldLotSheet(svc: _svc, tx: tx, marketPrice: marketPrice),
    );
    if (ok == true) _loadAll();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: RefreshIndicator(
        color: _kGold,
        onRefresh: _loadAll,
        child: CustomScrollView(
          slivers: [
            // _buildAppBar(),
            if (_loading)
              const SliverFillRemaining(
                child: Center(child: CircularProgressIndicator(color: _kGold)))
            else ...[
              SliverToBoxAdapter(child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: Column(children: [
                  _buildSummaryCards(),
                  const SizedBox(height: 10),
                  _buildAvgPriceCard(),
                  const SizedBox(height: 8),
                  _buildProfitBanner(),
                  const SizedBox(height: 12),
                  _buildPhuquyCard(),
                  const SizedBox(height: 14),
                  _buildFilterRow(),
                  const SizedBox(height: 8),
                ]),
              )),
              _buildTransactionList(),
              const SliverToBoxAdapter(child: SizedBox(height: 120)),
            ],
          ],
        ),
      ),
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 72),
        child: FloatingActionButton(
          onPressed: _openAdd,
          backgroundColor: _kGold,
          child: const Icon(Icons.add, color: Colors.black, size: 26),
        ),
      ),
    );
  }

  Widget _buildAppBar() => SliverAppBar(
    pinned: true, floating: false,
    backgroundColor: AppColors.background,
    surfaceTintColor: Colors.transparent,
    automaticallyImplyLeading: false,
    title: Row(children: [
      SvgPicture.asset('assets/icons/yuanbao-2.svg',
          width: 26, height: 26,
          colorFilter: const ColorFilter.mode(_kGold, BlendMode.srcIn)),
      const SizedBox(width: 8),
      const Text('Tích Vàng', style: TextStyle(
          fontSize: 17, fontWeight: FontWeight.w900, color: _kGold)),
    ]),
    bottom: PreferredSize(
      preferredSize: const Size.fromHeight(1),
      child: Container(height: 0.5, color: AppColors.border)),
  );

  // ── Summary Cards ──────────────────────────────────────────────────────────
  Widget _buildSummaryCards() {
    final s = _summary;
    if (s == null) return const SizedBox.shrink();
    return Column(children: [
      Row(children: [
        _summaryCard('💰 Tổng chi phí', _fmtMoney(s.netCost), _kGold),
        const SizedBox(width: 8),
        _summaryCard('🏅 Giá trị hiện tại', _fmtMoney(s.currentValue), _kGold),
      ]),
      const SizedBox(height: 8),
      Row(children: [
        _summaryCard('⚖️ Đang giữ', '${_fmtQty(s.holdingChi)} chỉ', AppColors.income),
        const SizedBox(width: 8),
        _summaryCard('📊 Giao dịch', '${s.buyCount} mua · ${s.sellCount} bán', AppColors.income),
      ]),
    ]);
  }

  Widget _summaryCard(String label, String value, Color accent) => Expanded(
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: accent.withAlpha(15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: accent.withAlpha(51), width: 0.5),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: const TextStyle(fontSize: 10, color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
        const SizedBox(height: 4),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(value, style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: accent)),
        ),
      ]),
    ),
  );

  // ── Avg Price Card ─────────────────────────────────────────────────────────
  Widget _buildAvgPriceCard() {
    final s = _summary;
    if (s == null || s.avgBuyPrice <= 0) return const SizedBox.shrink();
    const amber = Color(0xFFFFA000);
    final diff = s.phuquyBuy - s.avgBuyPrice;
    final isGood = diff >= 0;
    final diffColor = isGood ? _kGreen : _kRed;
    final fmtAvg = s.avgBuyPrice.toStringAsFixed(0).replaceAllMapped(
        RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (m) => '${m[1]}.');
    final fmtDiff = diff.abs().toStringAsFixed(0).replaceAllMapped(
        RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (m) => '${m[1]}.');
    final diffSign = isGood ? '+' : '-';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: amber.withAlpha(18),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: amber.withAlpha(76), width: 0.8),
      ),
      child: Row(children: [
        const Text('📊', style: TextStyle(fontSize: 20)),
        const SizedBox(width: 10),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Giá trung bình', style: TextStyle(
              fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.textSecondary)),
          const SizedBox(height: 3),
          Row(crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic, children: [
            Text(fmtAvg, style: const TextStyle(
                fontSize: 18, fontWeight: FontWeight.w900, color: amber)),
            const Text(' đ/chỉ', style: TextStyle(
                fontSize: 10, color: AppColors.textMuted)),
          ]),
        ])),
        if (s.phuquyBuy > 0)
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: diffColor.withAlpha(30),
                borderRadius: BorderRadius.circular(6)),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(isGood ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
                    size: 11, color: diffColor),
                const SizedBox(width: 2),
                Text('$diffSign$fmtDiff', style: TextStyle(
                    fontSize: 10, fontWeight: FontWeight.w800, color: diffColor)),
              ]),
            ),
            const SizedBox(height: 3),
            const Text('vs giá mua PQ', style: TextStyle(
                fontSize: 8, color: AppColors.textMuted)),
          ]),
      ]),
    );
  }

  // ── Profit Banner ──────────────────────────────────────────────────────────
  Widget _buildProfitBanner() {
    final s = _summary;
    if (s == null) return const SizedBox.shrink();
    final isUp  = s.profit >= 0;
    final color = isUp ? _kGreen : _kRed;
    final sign  = isUp ? '+' : '';
    final hasRealized = s.realizedPnl > 0;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: color.withAlpha(20),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withAlpha(76), width: 0.5),
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Row(children: [
          Icon(isUp ? Icons.trending_up_rounded : Icons.trending_down_rounded,
              color: color, size: 18),
          const SizedBox(width: 10),
          Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            Text(isUp ? 'Lãi tạm' : 'Lỗ tạm', style: TextStyle(
                fontSize: 10, fontWeight: FontWeight.w600, color: color.withAlpha(200))),
            Text('${_fmtQty(s.holdingChi)} chỉ đang giữ',
                style: const TextStyle(fontSize: 9, color: AppColors.textSecondary)),
          ]),
          const Spacer(),
          Text('$sign${_fmtMoney(s.profit)}', style: TextStyle(
              fontSize: 16, fontWeight: FontWeight.w900, color: color)),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
            decoration: BoxDecoration(
              color: color.withAlpha(38),
              borderRadius: BorderRadius.circular(6)),
            child: Text('$sign${s.profitPct.toStringAsFixed(2)}%',
                style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: color)),
          ),
        ]),
        if (hasRealized) ...[
          Divider(height: 14, thickness: 0.5, color: AppColors.border.withAlpha(100)),
          Row(children: [
            SvgPicture.asset('assets/icons/yuanbao-2.svg',
                width: 18, height: 18,
                colorFilter: const ColorFilter.mode(_kGold, BlendMode.srcIn)),
            const SizedBox(width: 10),
            Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
              const Text('Đã chốt lãi', style: TextStyle(
                  fontSize: 10, fontWeight: FontWeight.w600, color: _kGreen)),
              Text('${_fmtQty(s.totalSoldChiFromLots)} chỉ đã bán',
                  style: const TextStyle(fontSize: 9, color: AppColors.textSecondary)),
            ]),
            const Spacer(),
            Text('+${_fmtMoney(s.realizedPnl)}', style: const TextStyle(
                fontSize: 16, fontWeight: FontWeight.w900, color: _kGreen)),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
              decoration: BoxDecoration(color: _kGold.withAlpha(38), borderRadius: BorderRadius.circular(6)),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                SvgPicture.asset('assets/icons/yuanbao-2.svg',
                    width: 12, height: 12,
                    colorFilter: const ColorFilter.mode(_kGold, BlendMode.srcIn)),
                const SizedBox(width: 4),
                Text('${s.totalSellCountFromLots} lần',
                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: _kGold)),
              ]),
            ),
          ]),
        ],
      ]),
    );
  }

  // ── Phu Quy Price Card ─────────────────────────────────────────────────────
  Widget _buildPhuquyCard() {
    final s = _summary;
    if (s == null || s.phuquyBuy <= 0) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: _kGold.withAlpha(15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _kGold.withAlpha(51), width: 0.5),
      ),
      child: Row(children: [
        const Text('🥇', style: TextStyle(fontSize: 20)),
        const SizedBox(width: 10),
        const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Phú Quý Nhẫn 999.9', style: TextStyle(
              fontSize: 11, fontWeight: FontWeight.w800, color: _kGold)),
          Text('Giá tham chiếu hiện tại', style: TextStyle(
              fontSize: 9, color: AppColors.textMuted)),
        ])),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Row(children: [
            const Text('Mua ', style: TextStyle(fontSize: 9, color: AppColors.textMuted)),
            Text(_fmtMoney(s.phuquyBuy), style: const TextStyle(
                fontSize: 11, fontWeight: FontWeight.w700, color: _kGreen)),
          ]),
          const SizedBox(height: 2),
          Row(children: [
            const Text('Bán ', style: TextStyle(fontSize: 9, color: AppColors.textMuted)),
            Text(_fmtMoney(s.phuquySell), style: const TextStyle(
                fontSize: 11, fontWeight: FontWeight.w700, color: _kRed)),
          ]),
        ]),
      ]),
    );
  }

  // ── Filter Row ─────────────────────────────────────────────────────────────
  Widget _buildFilterRow() => Row(children: [
    const Text('📋 Lịch sử giao dịch', style: TextStyle(
        fontSize: 12, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
    const Spacer(),
    _filterChip('Tất cả', null),
    const SizedBox(width: 6),
    _filterChip('Mua', 'buy'),
    const SizedBox(width: 6),
    _filterChip('Bán', 'sell'),
  ]);

  Widget _filterChip(String label, String? value) {
    final active = _filter == value;
    final color = value == 'buy' ? _kGreen : value == 'sell' ? _kRed : _kGold;
    return GestureDetector(
      onTap: () { setState(() => _filter = value); _loadAll(); },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: active ? color.withAlpha(38) : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: active ? color : AppColors.border.withAlpha(128),
            width: active ? 1.2 : 0.5),
        ),
        child: Text(label, style: TextStyle(
            fontSize: 10, fontWeight: FontWeight.w700,
            color: active ? color : AppColors.textSecondary)),
      ),
    );
  }

  // ── Transaction List ───────────────────────────────────────────────────────
  Widget _buildTransactionList() {
    if (_txs.isEmpty) {
      return SliverFillRemaining(
        child: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('🪙', style: TextStyle(fontSize: 40)),
          const SizedBox(height: 12),
          const Text('Chưa có giao dịch nào', style: TextStyle(
              color: AppColors.textSecondary, fontSize: 14)),
          const SizedBox(height: 8),
          const Text('Nhấn + để thêm lần mua/bán vàng đầu tiên', style: TextStyle(
              color: AppColors.textMuted, fontSize: 11)),
        ])),
      );
    }
    final marketPrice = _summary?.phuquyBuy ?? 0;
    final avgBuy      = _summary?.avgBuyPrice ?? 0;
    return SliverList(
      delegate: SliverChildBuilderDelegate((_, i) {
        final tx = _txs[i];
        return _TxCard(
          tx: tx,
          marketPrice: marketPrice,
          avgBuyPrice: avgBuy,
          onDelete: () => _delete(tx.id),
          onEdit:   () => _edit(tx),
          onCloseLot: tx.isBuy && !tx.isFullySold ? () => _openCloseLot(tx) : null,
        );
      }, childCount: _txs.length),
    );
  }

  String _fmtMoney(double v) {
    final abs = v.abs();
    final s = abs.toStringAsFixed(0).replaceAllMapped(
        RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (m) => '${m[1]}.');
    return v < 0 ? '-$s đ' : '$s đ';
  }

  String _fmtQty(double v) {
    if (v == v.truncateToDouble()) return v.toStringAsFixed(0);
    return v.toStringAsFixed(1);
  }
}
// ─── Transaction Card ─────────────────────────────────────────────────────────

class _TxCard extends StatefulWidget {
  final GoldTransaction tx;
  final double marketPrice;   // giá PQ hiện tại /chỉ
  final double avgBuyPrice;   // giá vốn TB /chỉ
  final VoidCallback onDelete;
  final VoidCallback onEdit;
  final VoidCallback? onCloseLot;  // null = không hiện nút chốt

  const _TxCard({
    required this.tx,
    required this.marketPrice,
    required this.avgBuyPrice,
    required this.onDelete,
    required this.onEdit,
    this.onCloseLot,
  });

  @override
  State<_TxCard> createState() => _TxCardState();
}

class _TxCardState extends State<_TxCard> {
  String _fmt(double v) => v.abs().toStringAsFixed(0)
      .replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (m) => '${m[1]}.');

  String _fmtQtyLabel(double chi) {
    if (chi >= 10 && chi % 10 == 0) return '${(chi / 10).toStringAsFixed(0)} lượng';
    if (chi >= 10) return '${(chi / 10).toStringAsFixed(1)} lượng';
    return '${chi.toStringAsFixed(chi == chi.truncateToDouble() ? 0 : 1)} chỉ';
  }

  @override
  Widget build(BuildContext context) {
    final tx          = widget.tx;
    final isBuy       = tx.isBuy;
    // P&L calculation
    double pnl = 0, pnlPct = 0;
    if (isBuy && widget.marketPrice > 0) {
      pnl    = (widget.marketPrice - tx.unitPrice) * tx.quantityChi;
      pnlPct = tx.total > 0 ? pnl / tx.total * 100 : 0;
    } else if (!isBuy && widget.avgBuyPrice > 0) {
      pnl    = (tx.unitPrice - widget.avgBuyPrice) * tx.quantityChi;
      pnlPct = (widget.avgBuyPrice * tx.quantityChi) > 0
          ? pnl / (widget.avgBuyPrice * tx.quantityChi) * 100 : 0;
    }
    final isBreakOrProfit = pnl >= 0;
    final pnlColor = isBuy 
        ? (pnl > 0 ? _kGreen : (pnl == 0 ? AppColors.textSecondary : _kRed))
        : (isBuy ? _kRed : (pnl >= 0 ? _kGreen : _kRed)); // Sell uses opposite colors? Actually usually just green=profit, red=loss
    final pnlSign = pnl > 0 ? '+' : (pnl < 0 ? '-' : '');

    // Hold duration calculation
    String holdDuration = '';
    try {
      final parts = tx.date.split('-');
      if (parts.length == 3) {
        final txDate = DateTime(int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]));
        final now = DateTime.now();
        final diff = now.difference(txDate);
        if (diff.inDays == 0) holdDuration = 'Hôm nay';
        else if (diff.inDays < 30) holdDuration = '${diff.inDays} ngày';
        else {
          final months = diff.inDays ~/ 30;
          final days = diff.inDays % 30;
          holdDuration = days > 0 ? '$months tháng $days ngày' : '$months tháng';
        }
      }
    } catch (_) {}
    
    // Formatting date to dd/MM/yyyy
    String displayDate = tx.date;
    try {
      final parts = tx.date.split('-');
      if (parts.length == 3) displayDate = '${parts[2]}/${parts[1]}/${parts[0]}';
    } catch (_) {}

    return Dismissible(
      key: Key(tx.id),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => widget.onDelete(),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          color: _kRed.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(18),
        ),
        child: const Icon(Icons.delete_rounded, color: _kRed, size: 22),
      ),
      child: GestureDetector(
        onTap: widget.onEdit,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          decoration: BoxDecoration(
            color: const Color(0xFF141414), // Dark background matching mockup
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border.withValues(alpha: 0.3), width: 1),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 8, offset: const Offset(0, 4))],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── 1. Header Section ──
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Brand Icon & Badge
                    SizedBox(
                      width: 44, height: 44,
                      child: Stack(
                        children: [
                          Container(
                            decoration: BoxDecoration(
                              color: _kGold.withValues(alpha: 0.15),
                              shape: BoxShape.circle,
                              border: Border.all(color: _kGold.withValues(alpha: 0.4), width: 1),
                            ),
                            child: const Center(
                              child: Text('GOLD', style: TextStyle(
                                  fontSize: 10, fontWeight: FontWeight.w900, color: _kGold, letterSpacing: 0.5)),
                            ),
                          ),
                          Positioned(
                            right: 0, bottom: 0,
                            child: Container(
                              padding: const EdgeInsets.all(2),
                              decoration: const BoxDecoration(color: Color(0xFF141414), shape: BoxShape.circle),
                              child: Container(
                                padding: const EdgeInsets.all(2),
                                decoration: BoxDecoration(
                                  color: isBuy ? _kGreen : _kRed,
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  isBuy ? Icons.south_west_rounded : Icons.north_east_rounded,
                                  size: 8, color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Brand Name & Date
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  tx.brand.isEmpty ? 'Vàng Nhẫn' : tx.brand,
                                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: (isBuy ? _kGreen : _kRed).withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  isBuy ? (tx.isFullySold ? 'Chốt' : 'Mua') : 'Bán',
                                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: isBuy ? _kGreen : _kRed),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '$displayDate ${holdDuration.isNotEmpty ? '· $holdDuration' : ''}',
                            style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                          ),
                        ],
                      ),
                    ),
                    // Quantity Badge
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: _kGold.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: _kGold.withValues(alpha: 0.3), width: 1),
                      ),
                      child: Text(
                        _fmtQtyLabel(tx.quantityChi),
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: _kGold),
                      ),
                    ),
                  ],
                ),
              ),

              Container(height: 1, color: AppColors.border.withValues(alpha: 0.2)),

              // ── 2. Body Section (Metrics) ──
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _MetricRow(label: isBuy ? 'Giá mua:' : 'Giá bán:', value: '${_fmt(tx.unitPrice)} đ'),
                    const SizedBox(height: 8),
                    _MetricRow(label: isBuy ? 'Tổng tiền vốn:' : 'Tổng thu về:', value: '${_fmt(tx.total)} đ'),
                    const SizedBox(height: 8),
                    _MetricRow(
                      label: isBuy ? 'Giá trị hiện tại:' : 'Giá vốn tham chiếu:', 
                      value: isBuy ? '${_fmt(widget.marketPrice * tx.quantityChi)} đ' : '${_fmt(widget.avgBuyPrice * tx.quantityChi)} đ'
                    ),
                    // ── Ghi chú / Lý do mua ── hiện ngay sau Giá trị hiện tại
                    if (tx.note.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          const Icon(Icons.notes_rounded, size: 12, color: AppColors.textMuted),
                          const SizedBox(width: 5),
                          Expanded(
                            child: _MarqueeText(
                              text: tx.note,
                              style: const TextStyle(
                                fontSize: 11, color: AppColors.textMuted, fontStyle: FontStyle.italic),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),

              Container(height: 1, color: AppColors.border.withValues(alpha: 0.2)),

              // ── 3. Footer Section (P&L) ──
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          isBuy ? 'Lãi dự tính:' : 'Thực lãi lô:',
                          style: const TextStyle(fontSize: 13, color: AppColors.textSecondary, fontWeight: FontWeight.w500),
                        ),
                        const Spacer(),
                        if (pnl != 0) ...[
                          Text(
                            '$pnlSign${_fmt(pnl.abs())} đ',
                            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: pnl > 0 ? _kGreen : _kRed),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '$pnlSign${pnlPct.abs().toStringAsFixed(2)}%',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: pnl > 0 ? _kGreen : _kRed),
                          ),
                        ] else
                          const Text(
                            '0 đ',
                            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.textSecondary),
                          ),
                      ],
                    ),
                    if (pnl != 0 && tx.quantityChi > 0) ...[
                      const SizedBox(height: 6),
                      Text(
                        'Hiệu quả: $pnlSign${_fmt((pnl.abs() / tx.quantityChi))} đ / chỉ',
                        style: const TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: AppColors.textMuted),
                      ),
                    ],

                    // ── 4. Sells History (For Buy Tx ONLY) ──
                    if (isBuy && tx.sells.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceLight.withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppColors.border.withValues(alpha: 0.2)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                SvgPicture.asset('assets/icons/yuanbao-2.svg',
                                    width: 12, colorFilter: const ColorFilter.mode(_kGold, BlendMode.srcIn)),
                                const SizedBox(width: 4),
                                Text(
                                  'Đã chốt ${_fmtQtyLabel(tx.soldChi)} / ${_fmtQtyLabel(tx.quantityChi)}',
                                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: _kGold),
                                ),
                                const Spacer(),
                                Text(
                                  '${tx.realizedPnl >= 0 ? '+' : '-'}${_fmt(tx.realizedPnl)}đ',
                                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: tx.realizedPnl >= 0 ? _kGreen : _kRed),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            ...tx.sells.map((s) {
                              final parts = s.date.split('-');
                              final dateStr = parts.length == 3 ? '${parts[2]}/${parts[1]}' : '';
                              final singlePnl = (s.unitPrice - tx.unitPrice) * s.quantityChi;
                              return Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Row(
                                  children: [
                                    Text('• $dateStr', style: const TextStyle(fontSize: 10, color: AppColors.textSecondary)),
                                    const Spacer(),
                                    Text('${_fmt(s.unitPrice)}đ  [${singlePnl >= 0 ? '+' : '-'}${_fmt(singlePnl)}]',
                                        style: TextStyle(fontSize: 9, color: singlePnl >= 0 ? _kGreen.withValues(alpha: 0.8) : _kRed.withValues(alpha: 0.8))),
                                  ],
                                ),
                              );
                            }),
                          ],
                        ),
                      ),
                    ],

                    // ── 5. Nút Chốt lãi ──
                    if (isBuy && !tx.isFullySold && widget.onCloseLot != null) ...[
                      const SizedBox(height: 12),
                      Align(
                        alignment: Alignment.centerRight,
                        child: GestureDetector(
                          onTap: widget.onCloseLot,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            decoration: BoxDecoration(
                              color: _kGold.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: _kGold.withValues(alpha: 0.4), width: 1),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                SvgPicture.asset('assets/icons/yuanbao-2.svg',
                                    width: 12, colorFilter: const ColorFilter.mode(_kGold, BlendMode.srcIn)),
                                const SizedBox(width: 6),
                                const Text('Chốt lãi', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: _kGold)),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],

                  ],
                ),
              ),

            ],
          ),
        ),
      ),
    );
  }
}

class _MetricRow extends StatelessWidget {
  final String label;
  final String value;
  const _MetricRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(label, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary, fontWeight: FontWeight.w500)),
        const Spacer(),
        // Underlined 'đ' symbol handling
        Builder(builder: (_) {
          if (value.endsWith(' đ')) {
            final valStr = value.substring(0, value.length - 2);
            return RichText(
              text: TextSpan(
                children: [
                  TextSpan(text: '$valStr ', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white)),
                  const TextSpan(text: 'đ', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white, decoration: TextDecoration.underline)),
                ],
              ),
            );
          }
          return Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white));
        }),
      ],
    );
  }
}


// ─── Marquee Text ─────────────────────────────────────────────────────────────

class _MarqueeText extends StatefulWidget {
  final String text;
  final TextStyle style;
  final double velocity;   // px/s
  final Duration pause;    // dừng ở đầu / cuối

  const _MarqueeText({
    required this.text,
    required this.style,
    this.velocity = 40,
    this.pause = const Duration(milliseconds: 1500),
  });

  @override
  State<_MarqueeText> createState() => _MarqueeTextState();
}

class _MarqueeTextState extends State<_MarqueeText> {
  final _scroll = ScrollController();
  bool _running = false;

  @override
  void initState() {
    super.initState();
    // Bắt đầu sau khi layout xong
    WidgetsBinding.instance.addPostFrameCallback((_) => _loop());
  }

  @override
  void dispose() {
    _running = false;
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _loop() async {
    _running = true;
    while (_running && mounted) {
      if (!_scroll.hasClients) break;
      final maxExt = _scroll.position.maxScrollExtent;
      if (maxExt <= 0) break; // text vừa đủ, không cần chạy

      // Dừng ở đầu
      await Future.delayed(widget.pause);
      if (!_running || !mounted) break;

      // Cuộn tới cuối
      final duration = Duration(
          milliseconds: (maxExt / widget.velocity * 1000).round());
      await _scroll.animateTo(maxExt,
          duration: duration, curve: Curves.linear);
      if (!_running || !mounted) break;

      // Dừng ở cuối
      await Future.delayed(widget.pause);
      if (!_running || !mounted) break;

      // Cuộn về đầu nhanh
      await _scroll.animateTo(0,
          duration: const Duration(milliseconds: 300), curve: Curves.easeIn);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      controller: _scroll,
      scrollDirection: Axis.horizontal,
      physics: const NeverScrollableScrollPhysics(), // chỉ được animate, không vuốt tay
      child: Text(widget.text, style: widget.style, maxLines: 1),
    );
  }
}
