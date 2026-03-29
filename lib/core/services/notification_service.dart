import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest_all.dart' as tz;

class NotificationService {
  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static const int _dailyReminderID = 1001;
  static const int _budgetWarningBaseID = 2001;
  static const int _budgetExceededBaseID = 3001;
  static const int _savingsGoalBaseID = 4001;
  static const int _savingsCelebrationBaseID = 5001;

  // Chỉ hỗ trợ Android và iOS
  static bool get _isSupported =>
      defaultTargetPlatform == TargetPlatform.android ||
      defaultTargetPlatform == TargetPlatform.iOS;

  // ===== Khởi tạo =====
  static Future<void> init() async {
    if (!_isSupported) return; // Skip trên Windows/Web/macOS

    tz.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('Asia/Ho_Chi_Minh'));

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    await _plugin.initialize(
      const InitializationSettings(android: androidSettings, iOS: iosSettings),
    );

    await _plugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
  }

  // ===== Helper: đọc giờ/phút từ SharedPreferences =====
  static Future<({int hour, int minute})> _getScheduledTime() async {
    final prefs = await SharedPreferences.getInstance();
    final hour = prefs.getInt('notif_hour') ?? 21;
    final minute = prefs.getInt('notif_minute') ?? 0;
    return (hour: hour, minute: minute);
  }

  // ===== Lên lịch nhắc nhở hàng ngày theo giờ đã cài đặt =====
  static Future<void> scheduleDailyReminder() async {
    if (!_isSupported) return;

    await _plugin.cancel(_dailyReminderID);

    final time = await _getScheduledTime();
    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(
      tz.local, now.year, now.month, now.day, time.hour, time.minute, 0,
    );

    if (scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }

    await _plugin.zonedSchedule(
      _dailyReminderID,
      '💰 SaveMoney',
      'Bạn chưa nhập giao dịch hôm nay. Ghi lại trước khi quên nhé! 🐷',
      scheduled,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'daily_reminder_channel',
          'Nhắc nhở hàng ngày',
          channelDescription: 'Nhắc nhở ghi bản ghi chi tiêu mỗi ngày',
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  static Future<void> cancelDailyReminder() async {
    if (!_isSupported) return;
    await _plugin.cancel(_dailyReminderID);
  }

  // ===== Budget: Cảnh báo gần vượt ngân sách (≥80%) =====
  static Future<void> showBudgetWarning({
    required int budgetIndex,
    required String categoryName,
    required int percent,
  }) async {
    if (!_isSupported) return;
    await _plugin.show(
      _budgetWarningBaseID + budgetIndex,
      '⚠️ Gần vượt ngân sách',
      'Bạn đã dùng $percent% ngân sách "$categoryName". Hãy chi tiêu cẩn thận hơn!',
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'budget_warning_channel',
          'Cảnh báo ngân sách',
          channelDescription: 'Cảnh báo khi gần đạt giới hạn chi tiêu',
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: false,
          presentSound: true,
        ),
      ),
    );
  }

  // ===== Budget: Cảnh báo đã vượt ngân sách =====
  static Future<void> showBudgetExceeded({
    required int budgetIndex,
    required String categoryName,
  }) async {
    if (!_isSupported) return;
    await _plugin.show(
      _budgetExceededBaseID + budgetIndex,
      '🚨 Vượt ngân sách!',
      'Chi tiêu "$categoryName" đã vượt giới hạn tháng này. Kiểm tra ngay!',
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'budget_exceeded_channel',
          'Vượt ngân sách',
          channelDescription: 'Cảnh báo khi vượt giới hạn chi tiêu',
          importance: Importance.max,
          priority: Priority.max,
          icon: '@mipmap/ic_launcher',
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
    );
  }

  // ===== Savings: Lên lịch nhắc deadline mục tiêu (3 ngày trước) =====
  static Future<void> scheduleSavingsDeadlineReminder({
    required String goalId,
    required String goalName,
    required DateTime deadline,
  }) async {
    if (!_isSupported) return;

    final reminderDate = deadline.subtract(const Duration(days: 3));
    final now = DateTime.now();
    if (reminderDate.isBefore(now)) return; // Đã qua, bỏ qua

    final notifId = _savingsGoalBaseID + goalId.hashCode.abs() % 900;
    await _plugin.cancel(notifId);

    final scheduled = tz.TZDateTime(
      tz.local,
      reminderDate.year, reminderDate.month, reminderDate.day,
      9, 0, 0, // 9:00 sáng
    );

    await _plugin.zonedSchedule(
      notifId,
      '🎯 Sắp đến hạn mục tiêu!',
      'Mục tiêu "$goalName" còn 3 ngày nữa là đến hạn. Cố lên! 💪',
      scheduled,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'savings_reminder_channel',
          'Nhắc mục tiêu tiết kiệm',
          channelDescription: 'Nhắc nhở khi sắp đến hạn mục tiêu tiết kiệm',
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  // ===== Savings: Huỷ nhắc deadline =====
  static Future<void> cancelSavingsReminder(String goalId) async {
    if (!_isSupported) return;
    final notifId = _savingsGoalBaseID + goalId.hashCode.abs() % 900;
    await _plugin.cancel(notifId);
  }

  // ===== Savings: Chúc mừng đạt mục tiêu =====
  static Future<void> showSavingsCelebration({
    required String goalId,
    required String goalName,
  }) async {
    if (!_isSupported) return;
    final notifId = _savingsCelebrationBaseID + goalId.hashCode.abs() % 900;
    await _plugin.show(
      notifId,
      '🎉 Đạt mục tiêu!',
      'Tuyệt vời! Bạn đã hoàn thành mục tiêu "$goalName". Tiếp tục phát huy nhé!',
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'savings_celebration_channel',
          'Hoàn thành mục tiêu',
          channelDescription: 'Thông báo khi hoàn thành mục tiêu tiết kiệm',
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
    );
  }

  static Future<void> cancelAll() async {
    if (!_isSupported) return;
    await _plugin.cancelAll();
  }
}
