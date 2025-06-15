import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:get/get_navigation/src/root/get_material_app.dart';
import 'package:pomodoro_timer/core/dependencies.dart';
import 'package:pomodoro_timer/core/routes/routes.dart';
import 'package:pomodoro_timer/dependencies.dart';
import "core/pages/pages.dart";
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

Future main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: ".env");
  Dependencies.init();

  tz.initializeTimeZones();
  tz.setLocalLocation(tz.getLocation('Asia/Seoul')); // 한국 시간대
  
  const AndroidInitializationSettings androidSettings = 
    AndroidInitializationSettings('@mipmap/ic_launcher'); // 또는 'app_icon'
  
  const DarwinInitializationSettings iosSettings = 
      DarwinInitializationSettings();
  
  const InitializationSettings settings = InitializationSettings(
    android: androidSettings,
    iOS: iosSettings,
  );

  await flutterLocalNotificationsPlugin.initialize(settings);
  const AndroidNotificationChannel channel = AndroidNotificationChannel(
    'pomodoro_channel', // scheduleNotification에서 사용하는 ID와 동일해야 함
    'Pomodoro Notifications',
    description: 'Pomodoro timer notifications',
    importance: Importance.high,
  );

  // Android 13+ 권한 요청
  if (Platform.isAndroid) {
    await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
  }

  await flutterLocalNotificationsPlugin
    .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
    ?.createNotificationChannel(channel);
  runApp(const MainApp());
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      theme: ThemeData(
        fontFamily: "Pretendard",
      ),
      getPages: Pages.pages,
      initialRoute: Routes.qr.path,
    );
  }
}

