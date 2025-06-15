import 'package:flutter/material.dart';
import 'onboarding_screen.dart';
import 'notification_service.dart';
import 'background_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  try {
    print(' 알림 서비스 초기화 중...');
    await NotificationService.initialize();
    
    print('백그라운드 서비스 초기화 중...');
    await BackgroundService.initializeService();
    
    print('모든 서비스 초기화 완료');
  } catch (e) {
    print('서비스 초기화 실패: $e');
    // 실패해도 앱은 계속 실행
  }
  
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
        primarySwatch: Colors.blue,
      ),
      debugShowCheckedModeBanner: false,
      home: const LogoScreen(), // 로고 화면부터 시작
    );
  }
}