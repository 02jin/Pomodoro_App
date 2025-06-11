import 'package:flutter/material.dart';
import 'timer.dart';  // timer_page.dart 파일을 import
import 'notification_service.dart';
import 'background_service.dart';

void main() async {
  // Flutter 위젯 바인딩 초기화
  WidgetsFlutterBinding.ensureInitialized();
  
  // 알림 서비스 초기화
  await NotificationService.initialize();
  
  // 백그라운드 서비스 초기화
  await BackgroundService.initializeService();
  
  runApp(const PomodoroApp());
}

class PomodoroApp extends StatelessWidget {
  const PomodoroApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '유라뽀',
      theme: ThemeData(
        // 열사병 방지를 위한 시원한 색상 테마
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue,
          brightness: Brightness.light,
        ),
        useMaterial3: true,
        // 앱바 테마 설정
        appBarTheme: AppBarTheme(
          elevation: 0,
          centerTitle: false,
          backgroundColor: Colors.blue.shade100,
        ),
        // 카드 테마 설정
        cardTheme: CardThemeData(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        // 버튼 테마 설정
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
      ),
      // 다크 테마 설정
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      // 디버그 배너 제거
      debugShowCheckedModeBanner: false,
      // 앱이 시작되면 바로 타이머 페이지를 보여줌
      home: const TimerPage(),
    );
  }
}