import 'package:flutter/material.dart';
import 'onboarding_screen.dart';
import 'notification_service.dart';
import 'background_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  await NotificationService.initialize();
  await BackgroundService.initializeService();
  
  runApp(const YurappoApp());
}

class YurappoApp extends StatelessWidget {
  const YurappoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '유라뽀: Your Life saver Pomodoro',
      theme: ThemeData(
        useMaterial3: true,
      ),
      debugShowCheckedModeBanner: false,
      home: const LogoScreen(), // 로고 화면부터 시작
    );
  }
}