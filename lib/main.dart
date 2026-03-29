import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'core/theme/app_theme.dart';
import 'core/router/app_router.dart';
import 'core/services/notification_service.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Set preferred orientations
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // System UI overlay style
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Color(0xFF1C1F2E),
    ),
  );

  // Boot an toàn
  try {
    // Khởi tạo locale data cho intl (vi_VN) - BẮT BUỘC trước khi dùng NumberFormat/DateFormat
    await initializeDateFormatting('vi_VN', null);

    // Firebase initialization
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    // Firestore offline persistence
    FirebaseFirestore.instance.settings = const Settings(
      persistenceEnabled: true,
      cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
    );

    // Cấu hình Notification nhưng KHÔNG await (để tránh block main thread trên bản Release khi Activity chưa có)
    Future.microtask(() async {
      try {
        await NotificationService.init();
        await NotificationService.scheduleDailyReminder();
      } catch (e) {
        debugPrint('Lỗi khởi tạo NotificationService: $e');
      }
    });
  } catch (e) {
    debugPrint('Lỗi khởi tạo hệ thống cơ bản: $e');
  }

  // Chắc chắn luôn gọi runApp() dù cho có lỗi gì xảy ra đi nữa
  runApp(const ProviderScope(child: SaveMoneyApp()));
}

class SaveMoneyApp extends ConsumerWidget {
  const SaveMoneyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(goRouterProvider);

    return MaterialApp.router(
      title: 'Save Money',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      routerConfig: router,
    );
  }
}
