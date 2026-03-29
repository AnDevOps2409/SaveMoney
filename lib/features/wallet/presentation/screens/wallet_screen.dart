import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';
import 'package:savemoney/core/constants/app_colors.dart';
import 'package:savemoney/core/utils/format_utils.dart';
import 'package:savemoney/features/auth/data/auth_service.dart';
import 'package:savemoney/features/wallet/data/wallet_repository.dart';
import 'package:savemoney/features/transaction/data/transaction_repository.dart';
import 'package:savemoney/features/family/data/family_repository.dart';
import 'package:savemoney/features/family/domain/family_model.dart';
import 'package:savemoney/shared/models/models.dart';
import 'package:savemoney/features/wallet/presentation/screens/settings_screen.dart';

class WalletScreen extends ConsumerWidget {
  const WalletScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = FirebaseAuth.instance.currentUser;
    final displayName = user?.displayName ?? 'Người dùng';
    final email = user?.email ?? '';
    final photoUrl = user?.photoURL;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        slivers: [
          // ===== SliverAppBar with Avatar =====
          SliverAppBar(
            backgroundColor: AppColors.background,
            expandedHeight: 200,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [AppColors.primary.withAlpha(120), AppColors.background],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(height: 48),
                    // Avatar
                    Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: AppColors.primary, width: 3),
                        boxShadow: [BoxShadow(color: AppColors.primary.withAlpha(77), blurRadius: 16)],
                      ),
                      child: CircleAvatar(
                        radius: 40,
                        backgroundColor: AppColors.surface,
                        backgroundImage: photoUrl != null ? NetworkImage(photoUrl) : null,
                        child: photoUrl == null
                            ? Text(
                                displayName.isNotEmpty ? displayName[0].toUpperCase() : 'U',
                                style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w700, color: AppColors.primary),
                              )
                            : null,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(displayName, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                    Text(email, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                  ],
                ),
              ),
            ),
          ),

          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // ===== Thống kê tháng =====
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [AppColors.primary.withAlpha(40), AppColors.surface],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColors.primary.withAlpha(60)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Tháng này', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                      const SizedBox(height: 12),
                      ref.watch(transactionsProvider).when(
                        data: (transactions) {
                          final now = DateTime.now();
                          final currentMonthTx = transactions.where((tx) =>
                              tx.date.year == now.year && tx.date.month == now.month).toList();

                          double income = 0;
                          double expense = 0;
                          for (var tx in currentMonthTx) {
                            if (tx.type == 'income') income += tx.amount;
                            if (tx.type == 'expense' || tx.type == 'transfer') expense += tx.amount;
                          }
                          final balance = income - expense;

                          return Row(
                            children: [
                              Expanded(child: _StatItem(icon: Icons.arrow_downward_rounded, label: 'Thu nhập', value: FormatUtils.formatAmount(income), color: AppColors.income)),
                              Container(width: 1, height: 50, color: AppColors.divider),
                              Expanded(child: _StatItem(icon: Icons.arrow_upward_rounded, label: 'Chi tiêu', value: FormatUtils.formatAmount(expense), color: AppColors.expense)),
                              Container(width: 1, height: 50, color: AppColors.divider),
                              Expanded(child: _StatItem(icon: Icons.account_balance_rounded, label: 'Còn lại', value: FormatUtils.formatAmount(balance), color: balance >= 0 ? AppColors.income : AppColors.expense)),
                            ],
                          );
                        },
                        loading: () => const Center(child: Padding(padding: EdgeInsets.all(12), child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator()))),
                        error: (e, st) => const Text('Lỗi tải dữ liệu', style: TextStyle(color: AppColors.expense)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // ===== Ví của tôi =====
                const Text('Ví của tôi', style: TextStyle(color: AppColors.textSecondary, fontSize: 13, fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                _SettingCard(items: [
                  _SettingItem(
                    icon: Icons.account_balance_wallet_outlined, 
                    label: 'Quản lý ví', 
                    onTap: () => _showWalletsSheet(context, ref)
                  ),
                ]),
                const SizedBox(height: 16),

                // ===== Menu sections =====
                const Text('Cài đặt', style: TextStyle(color: AppColors.textSecondary, fontSize: 13, fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                _SettingCard(items: [
                  _SettingItem(
                    icon: Icons.notifications_outlined,
                    label: 'Thông báo',
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen(initialSection: 'notification'))),
                  ),
                  _SettingItem(
                    icon: Icons.lock_outline,
                    label: 'Bảo mật',
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen(initialSection: 'security'))),
                  ),
                  _SettingItem(
                    icon: Icons.language,
                    label: 'Ngôn ngữ',
                    trailing: 'Tiếng Việt',
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen(initialSection: 'language'))),
                  ),
                  _SettingItem(
                    icon: Icons.dark_mode_outlined,
                    label: 'Giao diện',
                    trailing: 'Tối',
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen(initialSection: 'theme'))),
                  ),
                ]),
                const SizedBox(height: 16),

                const Text('Gia đình', style: TextStyle(color: AppColors.textSecondary, fontSize: 13, fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),

                // Family Section logic
                Consumer(
                  builder: (context, ref, child) {
                    final familyIdAsync = ref.watch(userFamilyIdProvider);
                    
                    return familyIdAsync.when(
                      data: (familyId) {
                        if (familyId == null) {
                          // Chưa có family
                          return _SettingCard(items: [
                            _SettingItem(
                              icon: Icons.group_add_outlined,
                              label: 'Tạo / Tham gia gia đình',
                              onTap: () => context.push('/family-setup'),
                            ),
                          ]);
                        }

                        // Đã có family -> watch Family Stream
                        final familyStream = ref.watch(watchFamilyProvider(familyId));
                        return familyStream.when(
                          data: (family) {
                            if (family == null) return const SizedBox();
                            
                            return _SettingCard(items: [
                              _SettingItem(
                                icon: Icons.group_rounded,
                                label: family.name,
                                trailing: '${family.members.length} thành viên',
                                onTap: () => _showFamilyMembersBottomSheet(context, family),
                              ),
                              _SettingItem(
                                icon: Icons.qr_code_2,
                                label: 'Mã mời',
                                trailing: family.inviteCode,
                                onTap: () {
                                  Clipboard.setData(ClipboardData(text: family.inviteCode));
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('Đã copy mã mời: ${family.inviteCode}'),
                                      backgroundColor: AppColors.primary,
                                      behavior: SnackBarBehavior.floating,
                                      margin: const EdgeInsets.only(bottom: 80, left: 16, right: 16),
                                    ),
                                  );
                                },
                              ),
                              _SettingItem(
                                icon: Icons.exit_to_app,
                                label: 'Rời gia đình',
                                onTap: () => _showLeaveFamilyDialog(context, ref, family.id),
                              ),
                            ]);
                          },
                          loading: () => const Center(child: CircularProgressIndicator()),
                          error: (e, st) => Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Lỗi tải thông tin gia đình (có thể do dữ liệu cũ)', style: TextStyle(color: AppColors.expense)),
                              TextButton(
                                onPressed: () => ref.read(familyRepositoryProvider).leaveFamily(familyId).then((_) => ref.invalidate(userFamilyIdProvider)),
                                child: const Text('Bấm vào đây để Khôi phục/Rời', style: TextStyle(color: AppColors.primary)),
                              )
                            ],
                          ),
                        );
                      },
                      loading: () => const Center(child: CircularProgressIndicator()),
                      error: (e, st) => const Text('Lỗi tải thông tin gia đình'),
                    );
                  },
                ),
                
                const SizedBox(height: 16),

                const Text('Khác', style: TextStyle(color: AppColors.textSecondary, fontSize: 13, fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                _SettingCard(items: [
                  _SettingItem(icon: Icons.info_outline, label: 'Về ứng dụng', onTap: () {}),
                  _SettingItem(icon: Icons.star_border, label: 'Đánh giá app', onTap: () {}),
                  _SettingItem(icon: Icons.share_outlined, label: 'Chia sẻ', onTap: () {}),
                ]),
                const SizedBox(height: 16),

                // ===== Logout =====
                GestureDetector(
                  onTap: () async {
                    await AuthService.signOut();
                    if (context.mounted) context.go('/login');
                  },
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.expense.withAlpha(20),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.expense.withAlpha(60)),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.logout, color: AppColors.expense, size: 20),
                        SizedBox(width: 8),
                        Text('Đăng xuất', style: TextStyle(color: AppColors.expense, fontWeight: FontWeight.w700, fontSize: 16)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 100),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  void _showWalletsSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        height: MediaQuery.of(ctx).size.height * 0.75,
        decoration: const BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            Container(margin: const EdgeInsets.only(top: 8), width: 40, height: 4, decoration: BoxDecoration(color: AppColors.divider, borderRadius: BorderRadius.circular(2))),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Ví của tôi', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                  IconButton(icon: const Icon(Icons.add_circle, color: AppColors.primary), onPressed: () => _showAddWalletDialog(context, ref)),
                ],
              ),
            ),
            const Divider(height: 1, color: AppColors.divider),
            Expanded(
              child: Consumer(
                builder: (context, ref, child) {
                  final walletsAsync = ref.watch(walletsProvider);
                  return walletsAsync.when(
                    data: (wallets) {
                      if (wallets.isEmpty) {
                        return Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Text('Chưa có ví nào!', style: TextStyle(color: AppColors.textSecondary)),
                              const SizedBox(height: 16),
                              ElevatedButton.icon(
                                onPressed: () {
                                  ref.read(walletRepositoryProvider).createDefaultWallets();
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.primary,
                                  foregroundColor: Colors.white,
                                ),
                                icon: const Icon(Icons.auto_awesome),
                                label: const Text('Tạo 3 ví mẫu cơ bản'),
                              ),
                            ],
                          ),
                        );
                      }
                      return ListView.builder(
                        itemCount: wallets.length,
                        itemBuilder: (context, i) {
                          final wallet = wallets[i];
                          return Dismissible(
                            key: Key(wallet.id),
                            direction: DismissDirection.endToStart,
                            background: Container(
                              alignment: Alignment.centerRight,
                              padding: const EdgeInsets.only(right: 20),
                              decoration: BoxDecoration(
                                color: AppColors.expense.withAlpha(30),
                                borderRadius: BorderRadius.circular(12),
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
                                  title: const Text('Xóa ví?', style: TextStyle(color: AppColors.textPrimary)),
                                  content: const Text('Bạn chắc chắn muốn xóa ví này? Tất cả giao dịch sẽ bị ảnh hưởng nếu đã dùng ví này.', style: TextStyle(color: AppColors.textSecondary)),
                                  actions: [
                                    TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Huỷ')),
                                    TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Xóa', style: TextStyle(color: AppColors.expense))),
                                  ],
                                ),
                              );
                              if (confirmed == true) {
                                await ref.read(walletRepositoryProvider).deleteWallet(wallet.id);
                              }
                              return false;
                            },
                            child: ListTile(
                              leading: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(color: wallet.color.withAlpha(51), borderRadius: BorderRadius.circular(8)),
                                child: Icon(wallet.icon, color: wallet.color),
                              ),
                              title: Text(wallet.name, style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(FormatUtils.formatAmount(wallet.balance), style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.income)),
                                  const SizedBox(width: 8),
                                  const Icon(Icons.edit_outlined, size: 18, color: AppColors.textSecondary),
                                ],
                              ),
                              onTap: () => _showEditWalletDialog(context, ref, wallet),
                            ),
                          );
                        },
                      );
                    },
                    loading: () => const Center(child: CircularProgressIndicator()),
                    error: (e, st) => Center(child: Text('Lỗi: $e')),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddWalletDialog(BuildContext context, WidgetRef ref) {
    final nameCtrl = TextEditingController();
    final balanceCtrl = TextEditingController();
    
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Thêm ví mới', style: TextStyle(color: AppColors.textPrimary)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nameCtrl, style: const TextStyle(color: AppColors.textPrimary), decoration: const InputDecoration(labelText: 'Tên ví (Ví dụ: Tiền mặt)', labelStyle: TextStyle(color: AppColors.textSecondary))),
            const SizedBox(height: 16),
            TextField(controller: balanceCtrl, keyboardType: TextInputType.number, style: const TextStyle(color: AppColors.textPrimary), decoration: const InputDecoration(labelText: 'Số dư ban đầu', labelStyle: TextStyle(color: AppColors.textSecondary))),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Hủy', style: TextStyle(color: AppColors.textSecondary))),
          ElevatedButton(
            onPressed: () async {
              final val = double.tryParse(balanceCtrl.text) ?? 0.0;
              if (nameCtrl.text.isNotEmpty) {
                await ref.read(walletRepositoryProvider).addWallet(
                  name: nameCtrl.text,
                  type: 'cash',
                  initialBalance: val,
                  color: AppColors.primary,
                  icon: Icons.account_balance_wallet,
                );
                if (ctx.mounted) Navigator.pop(ctx);
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            child: const Text('Thêm', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showEditWalletDialog(BuildContext context, WidgetRef ref, WalletModel wallet) {
    final nameCtrl = TextEditingController(text: wallet.name);
    final balanceCtrl = TextEditingController(
      text: wallet.balance == 0 ? '' : FormatUtils.formatInputNumber(wallet.balance.toStringAsFixed(0)),
    );

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: wallet.color.withAlpha(40), borderRadius: BorderRadius.circular(8)),
              child: Icon(wallet.icon, color: wallet.color, size: 20),
            ),
            const SizedBox(width: 12),
            const Text('Chỉnh sửa ví', style: TextStyle(color: AppColors.textPrimary, fontSize: 16)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              style: const TextStyle(color: AppColors.textPrimary),
              decoration: const InputDecoration(
                labelText: 'Tên ví',
                labelStyle: TextStyle(color: AppColors.textSecondary),
                prefixIcon: Icon(Icons.label_outline, color: AppColors.textSecondary),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: balanceCtrl,
              keyboardType: TextInputType.number,
              inputFormatters: [FormatUtils.moneyInputFormatter],
              style: const TextStyle(color: AppColors.textPrimary),
              decoration: const InputDecoration(
                labelText: 'Số dư hiện tại (VNĐ)',
                labelStyle: TextStyle(color: AppColors.textSecondary),
                prefixIcon: Icon(Icons.monetization_on_outlined, color: AppColors.textSecondary),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Hủy', style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () async {
              final balance = double.tryParse(balanceCtrl.text.replaceAll('.', '').replaceAll(',', '')) ?? wallet.balance;
              final name = nameCtrl.text.trim().isEmpty ? wallet.name : nameCtrl.text.trim();
              await ref.read(walletRepositoryProvider).updateWallet(
                walletId: wallet.id,
                name: name,
                balance: balance,
              );
              if (ctx.mounted) Navigator.pop(ctx);
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            child: const Text('Lưu', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showLeaveFamilyDialog(BuildContext context, WidgetRef ref, String familyId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Rời gia đình', style: TextStyle(color: AppColors.textPrimary)),
        content: const Text('Bạn có chắc chắn muốn rời khỏi gia đình này? Bạn sẽ không thể xem hoặc chỉnh sửa các giao dịch chung nữa.', style: TextStyle(color: AppColors.textSecondary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Hủy', style: TextStyle(color: AppColors.textMuted)),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context); // close dialog
              try {
                await ref.read(familyRepositoryProvider).leaveFamily(familyId);
                ref.invalidate(userFamilyIdProvider);
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Lỗi: $e')));
                }
              }
            },
            child: const Text('Rời khỏi', style: TextStyle(color: AppColors.expense, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showFamilyMembersBottomSheet(BuildContext context, FamilyModel family) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: EdgeInsets.only(top: 24, left: 24, right: 24, bottom: MediaQuery.of(ctx).padding.bottom + 80),
        decoration: const BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 48,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.textMuted.withAlpha(50),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text('Thành viên gia đình (${family.members.length})', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
            const SizedBox(height: 16),
            ...family.members.map((member) {
              final isAdmin = member.role == 'admin';
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 20,
                      backgroundColor: AppColors.primary.withAlpha(30),
                      backgroundImage: member.photoUrl != null ? NetworkImage(member.photoUrl!) : null,
                      child: member.photoUrl == null
                          ? Text(member.displayName[0].toUpperCase(), style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold))
                          : null,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(member.displayName, style: const TextStyle(color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.w600)),
                          Text(isAdmin ? 'Quản trị viên' : 'Thành viên', style: TextStyle(color: isAdmin ? AppColors.primary : AppColors.textSecondary, fontSize: 13)),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                onPressed: () => context.push('/family-setup').then((_) => Navigator.pop(context)),
                icon: const Icon(Icons.person_add_outlined, color: Colors.white, size: 20),
                label: const Text('Mời thêm người thân', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
            )
          ],
        ),
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  const _StatItem({required this.icon, required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: 18),
        const SizedBox(height: 4),
        Text(value, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: color)),
        Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
      ],
    );
  }
}

class _SettingCard extends StatelessWidget {
  final List<_SettingItem> items;
  const _SettingCard({required this.items});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Material(
        color: AppColors.surface,
        child: Column(
          children: items.asMap().entries.map((entry) {
            final item = entry.value;
            final isLast = entry.key == items.length - 1;
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                InkWell(
                  onTap: item.onTap,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceLight,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(item.icon, color: AppColors.textSecondary, size: 18),
                        ),
                        const SizedBox(width: 14),
                        Expanded(child: Text(item.label, style: const TextStyle(color: AppColors.textPrimary, fontSize: 15))),
                        if (item.trailing != null)
                          Text(item.trailing!, style: const TextStyle(color: AppColors.textMuted, fontSize: 13)),
                        const SizedBox(width: 4),
                        const Icon(Icons.chevron_right, color: AppColors.textMuted, size: 18),
                      ],
                    ),
                  ),
                ),
                if (!isLast) const Divider(height: 1, indent: 56, color: AppColors.divider),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }
}

class _SettingItem {
  final IconData icon;
  final String label;
  final String? trailing;
  final VoidCallback onTap;
  const _SettingItem({required this.icon, required this.label, this.trailing, required this.onTap});
}
