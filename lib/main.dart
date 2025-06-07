import 'package:flutter/material.dart';
import 'timer_page.dart';  // timer_page.dart 파일을 import

void main() {
  runApp(const PomodoroApp());
}

class PomodoroApp extends StatelessWidget {
  const PomodoroApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '열사병 방지 포모도로',
      theme: ThemeData(
        // 열사병 방지를 위한 시원한 색상 테마
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue,
          brightness: Brightness.light,
        ),
        useMaterial3: true,
      ),
      // 앱이 시작되면 바로 타이머 페이지를 보여줌
      home: const TimerPage(),
    );
  }
}
