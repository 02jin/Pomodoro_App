import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:get/get.dart';
import 'package:pomodoro_timer/app/weather/controllers/weather_controller.dart';
import 'package:pomodoro_timer/core/dependencies.dart';

class TestScreen extends StatelessWidget {
  final WeatherController weatherController = WeatherController.to;
  TestScreen({super.key});

  Future<void> _sendNotification() async {
    // 초기화 없이 바로 사용!
    await flutterLocalNotificationsPlugin.show(
      0,
      'Hello',
      'World!',
      NotificationDetails(
        android: AndroidNotificationDetails(
          'channel_id',
          'channel_name',
          importance: Importance.max,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            ElevatedButton(onPressed: () { Get.offAllNamed("/qr"); }, child: const Text("시작화면(QR코드)로 이동")),
            ElevatedButton(onPressed: () { Get.offAllNamed("/timer"); }, child: const Text("타이머 화면으로 이동")),
            ElevatedButton(onPressed: weatherController.updateWeather, child: const Text("위치 정보 받아오기")),
            ElevatedButton(onPressed: _sendNotification, child: const Text("알림 보내기")),
          ],
        ),
      )
    );
  }

}