import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:savemoney/core/constants/app_colors.dart';
import 'package:savemoney/core/services/notification_service.dart';
import 'package:savemoney/core/utils/format_utils.dart';
import 'package:savemoney/features/wallet/data/wallet_repository.dart';
import 'package:savemoney/features/transaction/data/transaction_repository.dart';
import 'package:savemoney/shared/models/mock_data.dart';
import 'package:savemoney/shared/models/models.dart';
import 'package:savemoney/shared/widgets/top_toast.dart';

class AddTransactionScreen extends ConsumerStatefulWidget {
  final TransactionModel? transaction; // null = thêm mới, non-null = sửa
  const AddTransactionScreen({super.key, this.transaction});

  @override
  ConsumerState<AddTransactionScreen> createState() => _AddTransactionScreenState();
}

class _AddTransactionScreenState extends ConsumerState<AddTransactionScreen> {
  String _type = 'expense';
  String _amountStr = '0';
  String? _selectedCategoryId;
  String _selectedWalletId = 'cash';
  double _selectedWalletBalance = 0;
  DateTime _selectedDate = DateTime.now();
  final _noteController = TextEditingController();
  final _noteFocusNode = FocusNode();
  bool _saving = false;

  bool get _isEditing => widget.transaction != null;

  @override
  void initState() {
    super.initState();
    _noteFocusNode.addListener(() => setState(() {}));
    final tx = widget.transaction;
    if (tx != null) {
      _type = tx.type;
      _amountStr = tx.amount.toStringAsFixed(0);
      _selectedCategoryId = tx.categoryId;
      _selectedWalletId = tx.walletId;
      _selectedDate = tx.date;
      _noteController.text = tx.note;
    }
  }

  @override
  void dispose() {
    _noteController.dispose();
    _noteFocusNode.dispose();
    super.dispose();
  }

  List<CategoryModel> get _categories =>
      _type == 'income' ? MockData.incomeCategories : MockData.expenseCategories;

  void _onKey(String key) {
    setState(() {
      if (key == 'del') {
        if (_amountStr.length > 1) {
          _amountStr = _amountStr.substring(0, _amountStr.length - 1);
        } else {
          _amountStr = '0';
        }
      } else if (key == '.') {
        if (!_amountStr.contains('.')) _amountStr += '.';
      } else {
        if (_amountStr == '0') {
          _amountStr = key;
        } else {
          _amountStr += key;
        }
      }
    });
  }

  double get _amount => double.tryParse(_amountStr) ?? 0;

  String get _displayAmount {
    if (_amountStr == '0') return '0';
    if (_amountStr.endsWith('.')) {
      final whole = _amountStr.substring(0, _amountStr.length - 1);
      return '${FormatUtils.formatInputNumber(whole)},';
    }
    if (_amountStr.contains('.')) {
      final parts = _amountStr.split('.');
      return '${FormatUtils.formatInputNumber(parts[0])},${parts[1]}';
    }
    return FormatUtils.formatInputNumber(_amountStr);
  }

  @override
  Widget build(BuildContext context) {
    // Ẩn custom keypad khi note TextField đang focused (tránh 2 bàn phím cùng lúc)
    final bool showKeypad = !_noteFocusNode.hasFocus && MediaQuery.of(context).viewInsets.bottom == 0;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        leading: IconButton(
          icon: const Icon(Icons.close, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(_isEditing ? 'Sửa giao dịch' : 'Thêm giao dịch'),
        actions: [
          _saving
              ? const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
                )
              : Builder(builder: (ctx) {
                  // Trong edit mode: số dư khả dụng = số dư hiện tại + tiền chi tiêu cũ (sẽ được hoàn lại)
                  final double availableBalance = _isEditing &&
                      widget.transaction!.type == 'expense' &&
                      widget.transaction!.walletId == _selectedWalletId
                      ? _selectedWalletBalance + widget.transaction!.amount
                      : _selectedWalletBalance;
                  final bool canSave = _amount > 0 &&
                      _selectedCategoryId != null &&
                      ((_type != 'expense' && _type != 'transfer') || _amount <= availableBalance);
                  return TextButton(
                    onPressed: canSave ? () async {
                        setState(() => _saving = true);
                        try {
                          final repo = ref.read(transactionRepositoryProvider);
                          if (_isEditing) {
                            await repo.updateTransaction(
                              txId: widget.transaction!.id,
                              oldTx: widget.transaction!,
                              categoryId: _selectedCategoryId!,
                              type: _type,
                              amount: _amount,
                              walletId: _selectedWalletId,
                              note: _noteController.text.trim(),
                              date: _selectedDate,
                            );
                            if (mounted) {
                              TopToast.show(context, 'Đã cập nhật giao dịch!');
                              Navigator.pop(context);
                            }
                          } else {
                            await repo.addTransaction(
                              walletId: _selectedWalletId,
                              categoryId: _selectedCategoryId!,
                              type: _type,
                              amount: _amount,
                              note: _noteController.text.trim(),
                              date: _selectedDate,
                            );
                            await NotificationService.cancelDailyReminder();
                            await NotificationService.scheduleDailyReminder();
                            if (mounted) {
                              TopToast.show(context, 'Đã lưu giao dịch thành công!');
                              Navigator.pop(context);
                            }
                          }
                        } catch (e) {
                          if (mounted) {
                            final msg = e.toString().replaceFirst('Exception: ', '');
                            TopToast.show(context, msg, isError: true);
                          }
                        } finally {
                          if (mounted) setState(() => _saving = false);
                        }
                      } : null,
                    child: Text(_isEditing ? 'Cập nhật' : 'Lưu', style: TextStyle(
                      color: canSave ? AppColors.primary : AppColors.textMuted,
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                    )),
                  );
                }),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.only(
                left: 16, right: 16,
                bottom: MediaQuery.of(context).padding.bottom + 100,
              ),
              child: Column(
                children: [
          // ===== Type tabs =====
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  _TypeTab(label: 'Chi tiêu', isActive: _type == 'expense', color: AppColors.expense, onTap: () => setState(() { _type = 'expense'; _selectedCategoryId = null; })),
                  _TypeTab(label: 'Thu nhập', isActive: _type == 'income', color: AppColors.income, onTap: () => setState(() { _type = 'income'; _selectedCategoryId = null; })),
                  _TypeTab(label: 'Chuyển', isActive: _type == 'transfer', color: AppColors.warning, onTap: () => setState(() { _type = 'transfer'; _selectedCategoryId = null; })),
                ],
              ),
            ),
          ),

          // ===== Amount display =====
          Container(
            width: double.infinity,
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: _type == 'income' 
                    ? AppColors.income.withAlpha(51) 
                    : _type == 'expense' 
                        ? AppColors.expense.withAlpha(51) 
                        : AppColors.warning.withAlpha(51),
                width: 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: (_type == 'income' ? AppColors.income : (_type == 'expense' ? AppColors.expense : AppColors.warning)).withAlpha(20),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                )
              ],
            ),
            child: Column(
              children: [
                const Text('SỐ TIỀN', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary, letterSpacing: 1.2)),
                const SizedBox(height: 8),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    '$_displayAmount ₫',
                    style: TextStyle(
                      fontSize: 48,
                      fontWeight: FontWeight.w700,
                      color: _type == 'income' ? AppColors.income : _type == 'expense' ? AppColors.expense : AppColors.warning,
                      letterSpacing: -1,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ===== Category horizontal scroll =====
          SizedBox(
            height: 72,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemCount: _categories.length,
              itemBuilder: (context, index) {
                final cat = _categories[index];
                final isSelected = _selectedCategoryId == cat.id;
                return GestureDetector(
                  onTap: () => setState(() => _selectedCategoryId = cat.id),
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: isSelected ? cat.color.withAlpha(51) : AppColors.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected ? cat.color : Colors.transparent,
                        width: 1.5,
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(cat.icon, color: cat.color, size: 22),
                        const SizedBox(height: 2),
                        Text(
                          cat.name,
                          style: TextStyle(
                            fontSize: 10,
                            color: isSelected ? cat.color : AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),

          const SizedBox(height: 8),
          const Divider(height: 1, color: AppColors.divider),

                // ===== Form fields =====
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColors.divider, width: 0.5),
                  ),
                  child: Column(
                    children: [
                      _FormRow(
                        icon: Icons.calendar_today_outlined,
                        child: Text(
                          FormatUtils.formatDateLong(_selectedDate),
                          style: const TextStyle(color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.w500),
                        ),
                        onTap: () async {
                          final date = await showDatePicker(
                            context: context,
                            initialDate: _selectedDate,
                            firstDate: DateTime(2020),
                            lastDate: DateTime(2030),
                            builder: (ctx, child) => Theme(
                              data: Theme.of(ctx).copyWith(
                                colorScheme: const ColorScheme.dark(primary: AppColors.primary),
                              ),
                              child: child!,
                            ),
                          );
                          if (date != null) setState(() => _selectedDate = date);
                        },
                      ),
                      const SizedBox(height: 16),
                      const Divider(height: 1, color: AppColors.divider),
                      const SizedBox(height: 16),
                      _FormRow(
                        icon: Icons.account_balance_wallet_outlined,
                        child: ref.watch(walletsProvider).when(
                          data: (wallets) {
                            if (wallets.isEmpty) {
                              return const Text('Chưa có ví. Hãy tạo ví trước!',
                                style: TextStyle(color: AppColors.expense, fontSize: 14));
                            }
                            final wallet = wallets.firstWhere(
                              (w) => w.id == _selectedWalletId,
                              orElse: () => wallets.first,
                            );
                            // Only sync if wallet changed — prevents infinite rebuild loop
                            if (_selectedWalletId != wallet.id || _selectedWalletBalance != wallet.balance) {
                              WidgetsBinding.instance.addPostFrameCallback((_) {
                                if (mounted) {
                                  setState(() {
                                    _selectedWalletId = wallet.id;
                                    _selectedWalletBalance = wallet.balance;
                                  });
                                }
                              });
                            }
                            return Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: wallet.color.withAlpha(40),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Icon(wallet.icon, color: wallet.color, size: 16),
                                ),
                                const SizedBox(width: 10),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(wallet.name,
                                      style: const TextStyle(color: AppColors.textPrimary, fontSize: 15, fontWeight: FontWeight.w600)),
                                    Text(FormatUtils.formatAmount(wallet.balance),
                                      style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                                  ],
                                ),
                              ],
                            );
                          },
                          loading: () => const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                          error: (e, st) => const Text('Lỗi tải ví', style: TextStyle(color: AppColors.expense)),
                        ),
                        onTap: () => _showWalletPicker(),
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 24),
                
                // ===== Note Field =====
                Container(
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withAlpha(20),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      )
                    ],
                  ),
                  child: TextField(
                    controller: _noteController,
                  focusNode: _noteFocusNode,
                    minLines: 3,
                    maxLines: 5,
                    style: const TextStyle(color: AppColors.textPrimary, fontSize: 16),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: AppColors.surface,
                      prefixIcon: const Padding(
                        padding: EdgeInsets.only(bottom: 40),
                        child: Icon(Icons.edit_note_rounded, color: AppColors.textSecondary, size: 28),
                      ),
                      hintText: 'Thêm ghi chú giao dịch...',
                      hintStyle: const TextStyle(color: AppColors.textMuted, fontSize: 15),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20),
                        borderSide: BorderSide.none,
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20),
                        borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ], // Closes inner Column children
            ), // Closes inner Column
          ), // Closes SingleChildScrollView
        ), // Closes Expanded

          // ===== Keypad =====
          if (showKeypad)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              decoration: const BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.only(topLeft: Radius.circular(20), topRight: Radius.circular(20)),
              ),
              child: Column(
                children: [
                  Row(children: ['1', '2', '3'].map((k) => _KeypadButton(label: k, onTap: () => _onKey(k))).toList()),
                  Row(children: ['4', '5', '6'].map((k) => _KeypadButton(label: k, onTap: () => _onKey(k))).toList()),
                  Row(children: ['7', '8', '9'].map((k) => _KeypadButton(label: k, onTap: () => _onKey(k))).toList()),
                  Row(children: [
                    _KeypadButton(label: '.', onTap: () => _onKey('.')),
                    _KeypadButton(label: '0', onTap: () => _onKey('0')),
                    _KeypadButton(icon: Icons.backspace_outlined, onTap: () => _onKey('del')),
                  ]),
                  const SizedBox(height: 4),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: _amount > 0 && _selectedCategoryId != null ? () {
                        // Call the same save logic as the top right button
                        if (_saving) return;
                        setState(() => _saving = true);
                        final repo = ref.read(transactionRepositoryProvider);
                        repo.addTransaction(
                          walletId: _selectedWalletId,
                          categoryId: _selectedCategoryId!,
                          type: _type,
                          amount: _amount,
                          note: _noteController.text.trim(),
                          date: _selectedDate,
                        ).then((_) {
                          NotificationService.cancelDailyReminder();
                          NotificationService.scheduleDailyReminder();
                          if (mounted) {
                            TopToast.show(context, 'Đã lưu giao dịch thành công!');
                            Navigator.pop(context);
                          }
                        }).catchError((e) {
                          if (mounted) TopToast.show(context, 'Lỗi: ${e.toString()}', isError: true);
                        }).whenComplete(() {
                          if (mounted) setState(() => _saving = false);
                        });
                      } : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _amount > 0 && _selectedCategoryId != null
                            ? AppColors.primary : AppColors.surfaceLight,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      child: _saving ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) 
                                     : const Text('LƯU', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white)),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
  void _showWalletPicker() {
    final wallets = ref.read(walletsProvider).valueOrNull ?? [];
    if (wallets.isEmpty) return;
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => ListView(
        shrinkWrap: true,
        padding: EdgeInsets.fromLTRB(16, 16, 16, MediaQuery.of(ctx).padding.bottom + 24),
        children: [
          const Text('Chọn ví', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
          const SizedBox(height: 12),
          ...wallets.map((w) => ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 0, vertical: 4),
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: w.color.withAlpha(40), borderRadius: BorderRadius.circular(10)),
              child: Icon(w.icon, color: w.color),
            ),
            title: Text(w.name, style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600)),
            subtitle: Text(FormatUtils.formatAmount(w.balance), style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
            trailing: _selectedWalletId == w.id
              ? Icon(Icons.check_circle, color: w.color)
              : null,
            onTap: () {
              setState(() {
                _selectedWalletId = w.id;
                _selectedWalletBalance = w.balance;
              });
              Navigator.pop(context);
            },
          )),
        ],
      ),
    );
  }
}
class _TypeTab extends StatelessWidget {
  final String label;
  final bool isActive;
  final Color color;
  final VoidCallback onTap;
  const _TypeTab({required this.label, required this.isActive, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isActive ? color.withAlpha(38) : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              fontWeight: isActive ? FontWeight.w700 : FontWeight.w400,
              color: isActive ? color : AppColors.textMuted,
            ),
          ),
        ),
      ),
    );
  }
}

class _FormRow extends StatelessWidget {
  final IconData icon;
  final Widget child;
  final VoidCallback? onTap;
  const _FormRow({required this.icon, required this.child, this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            Icon(icon, size: 20, color: AppColors.textSecondary),
            const SizedBox(width: 12),
            Expanded(child: child),
            if (onTap != null) const Icon(Icons.chevron_right, size: 18, color: AppColors.textMuted),
          ],
        ),
      ),
    );
  }
}

class _KeypadButton extends StatelessWidget {
  final String? label;
  final IconData? icon;
  final VoidCallback onTap;
  const _KeypadButton({this.label, this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.all(4),
          height: 48, // Reduced height of keypad button
          decoration: BoxDecoration(
            color: AppColors.surfaceLight,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Center(
            child: label != null
                ? Text(label!, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w500, color: AppColors.textPrimary))
                : Icon(icon!, size: 20, color: AppColors.textPrimary),
          ),
        ),
      ),
    );
  }
}
