import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:savemoney/core/services/notification_service.dart';
import 'package:savemoney/core/constants/app_colors.dart';

// ===== Providers =====
final settingsProvider = ChangeNotifierProvider((ref) => SettingsNotifier());

class SettingsNotifier extends ChangeNotifier {
  bool _notifEnabled = true;
  int _notifHour = 21;
  int _notifMinute = 0;
  String _language = 'vi';
  bool _darkMode = true;
  bool _biometricEnabled = false;

  bool get notifEnabled => _notifEnabled;
  int get notifHour => _notifHour;
  int get notifMinute => _notifMinute;
  String get language => _language;
  bool get darkMode => _darkMode;
  bool get biometricEnabled => _biometricEnabled;

  SettingsNotifier() {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    _notifEnabled   = prefs.getBool('notif_enabled') ?? true;
    _notifHour      = prefs.getInt('notif_hour') ?? 21;
    _notifMinute    = prefs.getInt('notif_minute') ?? 0;
    _language       = prefs.getString('language') ?? 'vi';
    _darkMode       = prefs.getBool('dark_mode') ?? true;
    _biometricEnabled = prefs.getBool('biometric') ?? false;
    notifyListeners();
  }

  Future<void> setNotifEnabled(bool val) async {
    _notifEnabled = val;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('notif_enabled', val);
    if (val) {
      await NotificationService.scheduleDailyReminder();
    } else {
      await NotificationService.cancelDailyReminder();
    }
    notifyListeners();
  }

  Future<void> setNotifTime(int hour, int minute) async {
    _notifHour = hour;
    _notifMinute = minute;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('notif_hour', hour);
    await prefs.setInt('notif_minute', minute);
    if (_notifEnabled) {
      await NotificationService.scheduleDailyReminder();
    }
    notifyListeners();
  }

  Future<void> setLanguage(String lang) async {
    _language = lang;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('language', lang);
    notifyListeners();
  }

  Future<void> setDarkMode(bool val) async {
    _darkMode = val;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('dark_mode', val);
    notifyListeners();
  }

  Future<void> setBiometric(bool val) async {
    _biometricEnabled = val;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('biometric', val);
    notifyListeners();
  }
}

// ===== SettingsScreen =====
class SettingsScreen extends ConsumerStatefulWidget {
  final String? initialSection; // 'notification' | 'security' | 'language' | 'theme'
  const SettingsScreen({super.key, this.initialSection});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final _scrollController = ScrollController();
  final _notiKey = GlobalKey();
  final _securityKey = GlobalKey();
  final _langKey = GlobalKey();
  final _themeKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    if (widget.initialSection != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToSection());
    }
  }

  void _scrollToSection() {
    final key = switch (widget.initialSection) {
      'notification' => _notiKey,
      'security' => _securityKey,
      'language' => _langKey,
      'theme' => _themeKey,
      _ => _notiKey,
    };
    final ctx = key.currentContext;
    if (ctx != null) {
      Scrollable.ensureVisible(ctx, duration: const Duration(milliseconds: 400), curve: Curves.easeOut);
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(settingsProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: AppColors.textPrimary, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Cài đặt', style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
      ),
      body: ListView(
        controller: _scrollController,
        padding: const EdgeInsets.all(16),
        children: [

          // ===== THÔNG BÁO =====
          _SectionHeader(key: _notiKey, icon: Icons.notifications_outlined, title: 'Thông báo', color: AppColors.primary),
          _SettingsCard(
            children: [
              _SwitchRow(
                icon: Icons.notifications_active_outlined,
                iconColor: AppColors.primary,
                title: 'Bật thông báo nhắc nhở',
                subtitle: 'Nhắc nhở ghi giao dịch hàng ngày',
                value: s.notifEnabled,
                onChanged: (v) => s.setNotifEnabled(v),
              ),
              if (s.notifEnabled) ...[
                const Divider(height: 1, color: AppColors.divider, indent: 56),
                _TapRow(
                  icon: Icons.access_time_outlined,
                  iconColor: AppColors.primary,
                  title: 'Giờ nhắc nhở',
                  trailing: '${s.notifHour.toString().padLeft(2, '0')}:${s.notifMinute.toString().padLeft(2, '0')}',
                  onTap: () async {
                    final picked = await showTimePicker(
                      context: context,
                      initialTime: TimeOfDay(hour: s.notifHour, minute: s.notifMinute),
                      builder: (ctx, child) => Theme(
                        data: ThemeData.dark().copyWith(
                          colorScheme: const ColorScheme.dark(primary: AppColors.primary),
                        ),
                        child: child!,
                      ),
                    );
                    if (picked != null) s.setNotifTime(picked.hour, picked.minute);
                  },
                ),
              ],
            ],
          ),

          const SizedBox(height: 20),

          // ===== BẢO MẬT =====
          _SectionHeader(key: _securityKey, icon: Icons.lock_outline, title: 'Bảo mật', color: const Color(0xFFE91E63)),
          _SettingsCard(
            children: [
              if (Platform.isAndroid || Platform.isIOS)
                _SwitchRow(
                  icon: Icons.fingerprint,
                  iconColor: const Color(0xFFE91E63),
                  title: 'Mở khoá bằng vân tay',
                  subtitle: 'Yêu cầu xác thực khi mở app',
                  value: s.biometricEnabled,
                  onChanged: (v) => s.setBiometric(v),
                )
              else
                const _UnavailableRow(
                  icon: Icons.fingerprint,
                  iconColor: Color(0xFFE91E63),
                  title: 'Mở khoá bằng vân tay',
                  subtitle: 'Chỉ hỗ trợ trên điện thoại',
                ),
              const Divider(height: 1, color: AppColors.divider, indent: 56),
              _TapRow(
                icon: Icons.delete_forever_outlined,
                iconColor: AppColors.expense,
                title: 'Xoá toàn bộ dữ liệu',
                trailing: '',
                trailingColor: AppColors.expense,
                onTap: () => _showDeleteDataDialog(context),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // ===== NGÔN NGỮ =====
          _SectionHeader(key: _langKey, icon: Icons.language, title: 'Ngôn ngữ', color: const Color(0xFF1E88E5)),
          _SettingsCard(
            children: [
              _RadioRow(
                icon: Icons.flag,
                iconColor: const Color(0xFF1E88E5),
                title: 'Tiếng Việt',
                subtitle: 'Vietnamese',
                isSelected: s.language == 'vi',
                onTap: () => s.setLanguage('vi'),
              ),
              const Divider(height: 1, color: AppColors.divider, indent: 56),
              _RadioRow(
                icon: Icons.flag_outlined,
                iconColor: const Color(0xFF1E88E5),
                title: 'English',
                subtitle: 'Tiếng Anh',
                isSelected: s.language == 'en',
                onTap: () => s.setLanguage('en'),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // ===== GIAO DIỆN =====
          _SectionHeader(key: _themeKey, icon: Icons.palette_outlined, title: 'Giao diện', color: const Color(0xFF5E35B1)),
          _SettingsCard(
            children: [
              _RadioRow(
                icon: Icons.dark_mode,
                iconColor: const Color(0xFF5E35B1),
                title: 'Tối',
                subtitle: 'Dark mode — mặc định',
                isSelected: s.darkMode,
                onTap: () {
                  s.setDarkMode(true);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('🌙 Đang dùng giao diện Tối'),
                      backgroundColor: AppColors.primary,
                      duration: Duration(seconds: 2),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                },
              ),
              const Divider(height: 1, color: AppColors.divider, indent: 56),
              _RadioRow(
                icon: Icons.light_mode_outlined,
                iconColor: const Color(0xFF5E35B1),
                title: 'Sáng',
                subtitle: 'Light mode',
                isSelected: !s.darkMode,
                onTap: () {
                  s.setDarkMode(false);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('☀️ Đã lưu. Light mode sẽ hoàn thiện trong bản update tới.'),
                      duration: Duration(seconds: 3),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                },
              ),
            ],
          ),

          const SizedBox(height: 100),
        ],
      ),
    );
  }

  void _showDeleteDataDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Xoá dữ liệu?', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w700)),
        content: const Text(
          'Tất cả giao dịch, ví và mục tiêu sẽ bị xoá vĩnh viễn. Hành động này không thể hoàn tác.',
          style: TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Huỷ', style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.expense, elevation: 0),
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('❌ Chức năng xoá dữ liệu đã bị vô hiệu hoá để bảo vệ dữ liệu.'),
                  backgroundColor: AppColors.expense,
                ),
              );
            },
            child: const Text('Xoá', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}

// ===== Helpers =====
class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  final Color color;
  const _SectionHeader({super.key, required this.icon, required this.title, required this.color});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(color: color.withAlpha(30), borderRadius: BorderRadius.circular(8)),
          child: Icon(icon, color: color, size: 16),
        ),
        const SizedBox(width: 8),
        Text(title, style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.w700)),
      ],
    ),
  );
}

class _SettingsCard extends StatelessWidget {
  final List<Widget> children;
  const _SettingsCard({required this.children});

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(16)),
    child: Column(children: children),
  );
}

class _SwitchRow extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;
  const _SwitchRow({required this.icon, required this.iconColor, required this.title,
    required this.subtitle, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    child: Row(
      children: [
        Container(
          width: 36, height: 36,
          decoration: BoxDecoration(color: iconColor.withAlpha(25), borderRadius: BorderRadius.circular(10)),
          child: Icon(icon, color: iconColor, size: 18),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.textPrimary, fontSize: 14)),
              Text(subtitle, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
            ],
          ),
        ),
        Switch(
          value: value,
          onChanged: onChanged,
          activeColor: iconColor,
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
      ],
    ),
  );
}

class _TapRow extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String trailing;
  final Color? trailingColor;
  final VoidCallback onTap;
  const _TapRow({required this.icon, required this.iconColor, required this.title,
    required this.trailing, required this.onTap, this.trailingColor});

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(12),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(color: iconColor.withAlpha(25), borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, color: iconColor, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(title, style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.textPrimary, fontSize: 14))),
          if (trailing.isNotEmpty) ...[
            Text(trailing, style: TextStyle(color: trailingColor ?? AppColors.textSecondary, fontSize: 13, fontWeight: FontWeight.w600)),
            const SizedBox(width: 4),
          ],
          const Icon(Icons.chevron_right, color: AppColors.textMuted, size: 18),
        ],
      ),
    ),
  );
}

class _RadioRow extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final bool isSelected;
  final VoidCallback onTap;
  const _RadioRow({required this.icon, required this.iconColor, required this.title,
    required this.subtitle, required this.isSelected, required this.onTap});

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(color: iconColor.withAlpha(25), borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, color: iconColor, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.textPrimary, fontSize: 14)),
                Text(subtitle, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
              ],
            ),
          ),
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 20, height: 20,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isSelected ? iconColor : Colors.transparent,
              border: Border.all(color: isSelected ? iconColor : AppColors.textMuted, width: 2),
            ),
            child: isSelected ? const Icon(Icons.check, size: 12, color: Colors.white) : null,
          ),
        ],
      ),
    ),
  );
}

class _UnavailableRow extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  const _UnavailableRow({required this.icon, required this.iconColor, required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    child: Row(
      children: [
        Container(
          width: 36, height: 36,
          decoration: BoxDecoration(color: AppColors.surfaceLight, borderRadius: BorderRadius.circular(10)),
          child: Icon(icon, color: AppColors.textMuted, size: 18),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.textMuted, fontSize: 14)),
              Text(subtitle, style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
            ],
          ),
        ),
        const Text('N/A', style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
      ],
    ),
  );
}
