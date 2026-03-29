import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:savemoney/core/constants/app_colors.dart';
import 'package:savemoney/features/gold/data/gold_service.dart';

const _kGold  = Color(0xFFFFD700);
const _kGreen = Color(0xFF00C875);
const _kRed   = Color(0xFFEE5442);

class _ThousandFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue o, TextEditingValue n) {
    final digits = n.text.replaceAll('.', '').replaceAll(',', '');
    if (digits.isEmpty) return n.copyWith(text: '');
    final buf = StringBuffer();
    for (int i = 0; i < digits.length; i++) {
      if (i > 0 && (digits.length - i) % 3 == 0) buf.write('.');
      buf.write(digits[i]);
    }
    final f = buf.toString();
    return TextEditingValue(text: f, selection: TextSelection.collapsed(offset: f.length));
  }
}

class _DecimalFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue o, TextEditingValue n) {
    final text = n.text;
    if (text.isEmpty) return n;
    if (text.split('.').length - 1 > 1) return o;
    if (!RegExp(r'^\d*\.?\d*$').hasMatch(text)) return o;
    return n;
  }
}

class CloseGoldLotSheet extends StatefulWidget {
  final GoldService svc;
  final GoldTransaction tx;
  final double marketPrice;

  const CloseGoldLotSheet({
    super.key, required this.svc, required this.tx, required this.marketPrice,
  });

  @override
  State<CloseGoldLotSheet> createState() => _CloseGoldLotSheetState();
}

class _CloseGoldLotSheetState extends State<CloseGoldLotSheet> {
  final _qtyCtrl   = TextEditingController();
  final _priceCtrl = TextEditingController();
  final _noteCtrl  = TextEditingController();
  DateTime _date = DateTime.now();
  bool _saving = false;
  String? _error;

  double get _qty   => double.tryParse(_qtyCtrl.text.trim()) ?? 0;
  double get _price => double.tryParse(
      _priceCtrl.text.replaceAll('.', '').replaceAll(',', '')) ?? 0;
  double get _pnl    => (_price - widget.tx.unitPrice) * _qty;
  double get _pnlPct => widget.tx.unitPrice > 0
      ? (_price - widget.tx.unitPrice) / widget.tx.unitPrice * 100 : 0;

  String _fmt(double v) => v.toStringAsFixed(0).replaceAllMapped(
      RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (m) => '${m[1]}.');

  @override
  void initState() {
    super.initState();
    if (widget.marketPrice > 0) {
      _priceCtrl.text = _fmt(widget.marketPrice);
    }
  }

  @override
  void dispose() {
    _qtyCtrl.dispose(); _priceCtrl.dispose(); _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2018),
      lastDate: DateTime.now(),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.dark(
            primary: _kGold, surface: AppColors.surface,
            onSurface: AppColors.textPrimary)),
        child: child!),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _save() async {
    if (_qty <= 0) { setState(() => _error = 'Nhập số chỉ muốn bán'); return; }
    if (_qty > widget.tx.remainingChi + 0.01) {
      setState(() => _error = 'Chỉ còn ${_fmt(widget.tx.remainingChi)} chỉ'); return;
    }
    if (_price <= 0) { setState(() => _error = 'Nhập giá bán'); return; }
    setState(() { _saving = true; _error = null; });
    final dateStr =
        '${_date.year}-${_date.month.toString().padLeft(2,'0')}-${_date.day.toString().padLeft(2,'0')}';
    final ok = await widget.svc.addSell(
      buyId: widget.tx.id, quantityChi: _qty, unitPrice: _price,
      date: dateStr, note: _noteCtrl.text.trim(),
    );
    if (ok && mounted) Navigator.pop(context, true);
    else setState(() { _error = 'Lỗi lưu'; _saving = false; });
  }

  @override
  Widget build(BuildContext context) {
    final remaining = widget.tx.remainingChi;
    final isProfit  = _pnl > 0;
    final pnlColor  = isProfit ? _kGreen : _kRed;

    return Padding(
      padding: EdgeInsets.only(
        left: 20, right: 20, top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom +
                MediaQuery.of(context).padding.bottom + 72,
      ),
      child: SingleChildScrollView(child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(child: Container(width: 40, height: 4,
            margin: const EdgeInsets.only(bottom: 14),
            decoration: BoxDecoration(color: AppColors.border,
                borderRadius: BorderRadius.circular(2)))),

          Row(children: [
            SvgPicture.asset('assets/icons/yuanbao-2.svg',
                width: 24, height: 24,
                colorFilter: const ColorFilter.mode(_kGold, BlendMode.srcIn)),
            const SizedBox(width: 8),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Chốt lô ${widget.tx.brand}',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: _kGold)),
              Text('Giá mua: ${_fmt(widget.tx.unitPrice)}đ/chỉ  ·  Còn ${_fmt(remaining)} chỉ',
                  style: const TextStyle(fontSize: 10, color: AppColors.textSecondary)),
            ])),
          ]),
          const SizedBox(height: 18),

          _label('Số chỉ bán (còn ${_fmt(remaining)} chỉ)'),
          const SizedBox(height: 6),
          TextField(
            controller: _qtyCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [_DecimalFormatter()],
            onTapOutside: (_) => FocusManager.instance.primaryFocus?.unfocus(),
            onChanged: (_) => setState(() {}),
            style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w700),
            decoration: _inputDeco('VD: ${_fmt(remaining)} hoặc 1'),
          ),
          const SizedBox(height: 14),

          _label('Giá bán (đ/chỉ)'),
          const SizedBox(height: 6),
          Row(children: [
            Expanded(child: TextField(
              controller: _priceCtrl,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly, _ThousandFormatter()],
              onTapOutside: (_) => FocusManager.instance.primaryFocus?.unfocus(),
              onChanged: (_) => setState(() {}),
              style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w700),
              decoration: _inputDeco('Ví dụ: ${_fmt(widget.marketPrice)}'),
            )),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: () async {
                final pq = await widget.svc.getPhuquyPrice();
                final price = (pq['buy'] as num?)?.toDouble() ?? 0;
                if (price > 0) { _priceCtrl.text = _fmt(price); setState(() {}); }
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                decoration: BoxDecoration(
                  color: _kGold.withAlpha(40),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: _kGold.withAlpha(100), width: 0.8),
                ),
                child: const Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.sync_rounded, size: 14, color: _kGold),
                  SizedBox(width: 4),
                  Text('Giá PQ', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: _kGold)),
                ]),
              ),
            ),
          ]),
          const SizedBox(height: 14),

          _label('Ngày bán'),
          const SizedBox(height: 6),
          GestureDetector(
            onTap: _pickDate,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: _boxDeco(),
              child: Row(children: [
                Text('${_date.day.toString().padLeft(2,'0')}/${_date.month.toString().padLeft(2,'0')}/${_date.year}',
                  style: const TextStyle(color: AppColors.textPrimary,
                      fontWeight: FontWeight.w700, fontSize: 13)),
                const Spacer(),
                const Icon(Icons.calendar_today_rounded, size: 16, color: AppColors.textSecondary),
              ]),
            ),
          ),
          const SizedBox(height: 14),

          _label('Ghi chú (tùy chọn)'),
          const SizedBox(height: 6),
          TextField(
            controller: _noteCtrl,
            onTapOutside: (_) => FocusManager.instance.primaryFocus?.unfocus(),
            style: const TextStyle(color: AppColors.textPrimary, fontSize: 12),
            decoration: _inputDeco('VD: Chốt lãi đợt 1...'),
            minLines: 1, maxLines: 3,
          ),

          if (_qty > 0 && _price > 0) ...[
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: pnlColor.withAlpha(20),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: pnlColor.withAlpha(100)),
              ),
              child: Column(children: [
                Text(
                  '${isProfit ? "🏆 Lãi" : "📉 Lỗ"} '
                  '${isProfit ? "+" : ""}${_fmt(_pnl)}đ '
                  '(${_pnlPct >= 0 ? "+" : ""}${_pnlPct.toStringAsFixed(1)}%)',
                  style: TextStyle(color: pnlColor, fontWeight: FontWeight.w800, fontSize: 13),
                  textAlign: TextAlign.center,
                ),
                Text('${_fmt(_qty)} chỉ × (${_fmt(_price)} − ${_fmt(widget.tx.unitPrice)})đ',
                    style: const TextStyle(color: AppColors.textSecondary, fontSize: 10),
                    textAlign: TextAlign.center),
              ]),
            ),
          ],

          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(_error!, style: const TextStyle(color: _kRed, fontSize: 11)),
          ],
          const SizedBox(height: 20),

          SizedBox(
            width: double.infinity, height: 48,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: _kGold,
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(width: 20, height: 20,
                      child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2))
                  : const Text('Lưu Chốt Lô',
                      style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14)),
            ),
          ),
        ],
      )),
    );
  }

  Widget _label(String t) => Text(t,
      style: const TextStyle(fontSize: 11, color: AppColors.textSecondary, fontWeight: FontWeight.w600));

  BoxDecoration _boxDeco() => BoxDecoration(
    color: AppColors.background, borderRadius: BorderRadius.circular(10),
    border: Border.all(color: AppColors.border.withAlpha(128)));

  InputDecoration _inputDeco(String hint) => InputDecoration(
    hintText: hint,
    hintStyle: const TextStyle(color: AppColors.textMuted, fontSize: 12),
    filled: true, fillColor: AppColors.background,
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: AppColors.border.withAlpha(128))),
    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: AppColors.border.withAlpha(128))),
    focusedBorder: const OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(10)),
        borderSide: BorderSide(color: _kGold, width: 1.5)),
  );
}
