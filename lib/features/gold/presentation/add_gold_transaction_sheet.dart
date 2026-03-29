import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

class AddGoldTransactionSheet extends StatefulWidget {
  final GoldService svc;
  final GoldTransaction? existingTx;
  const AddGoldTransactionSheet({super.key, required this.svc, this.existingTx});
  @override
  State<AddGoldTransactionSheet> createState() => _AddGoldTxState();
}

class _AddGoldTxState extends State<AddGoldTransactionSheet> {
  String _type  = 'buy';
  String _brand = 'BTMC';
  DateTime _date = DateTime.now();
  final _qtyCtrl   = TextEditingController();
  final _priceCtrl  = TextEditingController();
  final _noteCtrl   = TextEditingController();
  String _qtyUnit = 'chi';
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final tx = widget.existingTx;
    if (tx != null) {
      _type  = tx.type;
      _brand = tx.brand;
      _date  = DateTime.tryParse(tx.date) ?? DateTime.now();
      _qtyCtrl.text   = _fmtNum(tx.quantityChi);
      _priceCtrl.text = _fmtNum(tx.unitPrice);
      _noteCtrl.text  = tx.note;
    }
  }

  String _fmtNum(double v) => v.toStringAsFixed(0).replaceAllMapped(
      RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (m) => '${m[1]}.');

  @override
  void dispose() {
    _qtyCtrl.dispose(); _priceCtrl.dispose(); _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _fillCurrentPrice() async {
    try {
      final pq = await widget.svc.getPhuquyPrice();
      final price = pq['sell'];
      if (price != null && (price as num) > 0) {
        _priceCtrl.text = (price as num).toInt().toString().replaceAllMapped(
            RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (m) => '${m[1]}.');
        setState(() {});
      }
    } catch (_) {}
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
    double qty = double.tryParse(_qtyCtrl.text.trim()) ?? 0;
    if (_qtyUnit == 'luong') qty *= 10;
    final rawPrice = _priceCtrl.text.replaceAll('.', '').replaceAll(',', '');
    final price = double.tryParse(rawPrice) ?? 0;
    if (qty <= 0) { setState(() => _error = 'Vui lòng nhập số lượng'); return; }
    if (price <= 0) { setState(() => _error = 'Vui lòng nhập đơn giá'); return; }
    setState(() { _saving = true; _error = null; });
    try {
      final dateStr = '${_date.year}-${_date.month.toString().padLeft(2,'0')}-${_date.day.toString().padLeft(2,'0')}';
      final bool ok;
      final existingId = widget.existingTx?.id;
      if (existingId != null) {
        ok = await widget.svc.updateTransaction(
          id: existingId, type: _type, brand: _brand,
          date: dateStr, quantityChi: qty, unitPrice: price, note: _noteCtrl.text.trim(),
        );
      } else {
        ok = await widget.svc.addTransaction(
          type: _type, brand: _brand, date: dateStr,
          quantityChi: qty, unitPrice: price, note: _noteCtrl.text.trim(),
        );
      }
      if (ok && mounted) Navigator.pop(context, true);
      else setState(() { _error = 'Lỗi lưu giao dịch'; _saving = false; });
    } catch (e) {
      setState(() { _error = e.toString(); _saving = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
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
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2)))),
          Text(widget.existingTx != null ? '✏️ Chỉnh sửa giao dịch' : '🪙 Thêm giao dịch vàng',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: _kGold)),
          const SizedBox(height: 18),
          _label('Loại giao dịch'),
          const SizedBox(height: 6),
          Row(children: [
            _toggleChip('Mua', 'buy', _kGreen),
            const SizedBox(width: 8),
            _toggleChip('Bán', 'sell', _kRed),
          ]),
          const SizedBox(height: 14),
          _label('Thương hiệu'),
          const SizedBox(height: 6),
          Row(children: [
            _brandChip('BTMC'),
            const SizedBox(width: 8),
            _brandChip('Phú Quý'),
            const SizedBox(width: 8),
            _brandChip('Doji'),
          ]),
          const SizedBox(height: 14),
          _label('Ngày'),
          const SizedBox(height: 6),
          GestureDetector(
            onTap: _pickDate,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: _boxDeco(),
              child: Row(children: [
                Text('${_date.day.toString().padLeft(2,'0')}/${_date.month.toString().padLeft(2,'0')}/${_date.year}',
                  style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w700, fontSize: 13)),
                const Spacer(),
                const Icon(Icons.calendar_today_rounded, size: 16, color: AppColors.textSecondary),
              ]),
            ),
          ),
          const SizedBox(height: 14),
          _label('Số lượng'),
          const SizedBox(height: 6),
          Row(children: [
            Expanded(child: TextField(
              controller: _qtyCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [_DecimalFormatter()],
              onTapOutside: (_) => FocusManager.instance.primaryFocus?.unfocus(),
              style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w700),
              decoration: _inputDeco('VD: 2 hoặc 0.5'),
            )),
            const SizedBox(width: 8),
            _unitChip('Chỉ', 'chi'),
            const SizedBox(width: 4),
            _unitChip('Lượng', 'luong'),
          ]),
          const SizedBox(height: 14),
          _label('Đơn giá (đ/chỉ)'),
          const SizedBox(height: 6),
          Row(children: [
            Expanded(child: TextField(
              controller: _priceCtrl,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly, _ThousandFormatter()],
              onTapOutside: (_) => FocusManager.instance.primaryFocus?.unfocus(),
              style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w700),
              decoration: _inputDeco('VD: 18.230.000'),
            )),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: _fillCurrentPrice,
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
          _label('Lý do / Ghi chú (tùy chọn)'),
          const SizedBox(height: 6),
          TextField(
            controller: _noteCtrl,
            onTapOutside: (_) => FocusManager.instance.primaryFocus?.unfocus(),
            style: const TextStyle(color: AppColors.textPrimary, fontSize: 12),
            decoration: _inputDeco('VD: Mua nhẫn cưới, phòng thủ lạm phát...'),
            minLines: 2, maxLines: 5,
          ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(_error!, style: const TextStyle(color: _kRed, fontSize: 11)),
          ],
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity, height: 48,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: _type == 'buy' ? _kGreen : _kRed,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(width: 20, height: 20,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : Text(widget.existingTx != null
                      ? 'Lưu thay đổi'
                      : (_type == 'buy' ? 'Lưu giao dịch MUA' : 'Lưu giao dịch BÁN'),
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
            ),
          ),
        ],
      )),
    );
  }

  Widget _label(String t) => Text(t,
    style: const TextStyle(fontSize: 11, color: AppColors.textSecondary, fontWeight: FontWeight.w600));

  Widget _toggleChip(String label, String value, Color color) {
    final active = _type == value;
    return Expanded(child: GestureDetector(
      onTap: () => setState(() => _type = value),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: active ? color.withAlpha(38) : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: active ? color : AppColors.border.withAlpha(128), width: active ? 1.5 : 0.5),
        ),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(value == 'buy' ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded,
              size: 14, color: active ? color : AppColors.textSecondary),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800,
              color: active ? color : AppColors.textSecondary)),
        ]),
      ),
    ));
  }

  Widget _brandChip(String label) {
    final active = _brand == label;
    return Expanded(child: GestureDetector(
      onTap: () => setState(() => _brand = label),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: active ? _kGold.withAlpha(38) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: active ? _kGold : AppColors.border.withAlpha(128), width: active ? 1.2 : 0.5),
        ),
        child: Text(label, textAlign: TextAlign.center,
          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800,
              color: active ? _kGold : AppColors.textSecondary)),
      ),
    ));
  }

  Widget _unitChip(String label, String value) {
    final active = _qtyUnit == value;
    return GestureDetector(
      onTap: () => setState(() => _qtyUnit = value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: active ? _kGold.withAlpha(38) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: active ? _kGold : AppColors.border.withAlpha(128), width: active ? 1.2 : 0.5),
        ),
        child: Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
            color: active ? _kGold : AppColors.textSecondary)),
      ),
    );
  }

  BoxDecoration _boxDeco() => BoxDecoration(
    color: AppColors.background,
    borderRadius: BorderRadius.circular(10),
    border: Border.all(color: AppColors.border.withAlpha(128)),
  );

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
