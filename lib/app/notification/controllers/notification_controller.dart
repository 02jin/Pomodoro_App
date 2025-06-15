import 'package:flutter/cupertino.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:get/get.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:pomodoro_timer/core/dependencies.dart';
import 'package:timezone/timezone.dart' as tz;

class NotificationController extends GetxController {
  static NotificationController get to => Get.find<NotificationController>();

  Future<bool> requestNotificationPermissions() async {
    try {
      // Android 13+ 알림 권한
      if (await Permission.notification.isDenied) {
        final status = await Permission.notification.request();
        if (status != PermissionStatus.granted) {
          debugPrint('❌ 알림 권한이 거부되었습니다');
          return false;
        }
      }

      // 정확한 알람 권한 확인 (Android 12+)
      if (await Permission.scheduleExactAlarm.isDenied) {
        final status = await Permission.scheduleExactAlarm.request();
        if (status != PermissionStatus.granted) {
          debugPrint('❌ 정확한 알람 권한이 거부되었습니다');
          return false;
        }
      }

      debugPrint('✅ 모든 알림 권한이 허용되었습니다');
      return true;
      
    } catch (e) {
      debugPrint('❌ 권한 요청 중 오류: $e');
      return false;
    }
  }

  Future<void> scheduleNotification(int seconds, String title, String message) async {
    final hasPermission = await requestNotificationPermissions();
    if (!hasPermission) {
      debugPrint('❌ 권한이 없어서 알림을 예약할 수 없습니다');
      return;
    }

    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'pomodoro_channel', // main.dart에서 생성한 채널 ID와 동일
      'Pomodoro Notifications',
      channelDescription: 'Pomodoro timer notifications',
      importance: Importance.high,
      priority: Priority.high,
      enableVibration: true,
      enableLights: true,
      playSound: true,
      ticker: 'Pomodoro Timer',
    );

    const NotificationDetails details = NotificationDetails(android: androidDetails);
    
    final tz.TZDateTime now = tz.TZDateTime.now(tz.local);
    final tz.TZDateTime scheduledTime = now.add(Duration(seconds: seconds)); // 실제 seconds 값 사용
    
    debugPrint('예약할 시간: $seconds초');
    debugPrint('현재 시간: $now');
    debugPrint('예약 시간: $scheduledTime');
    debugPrint('시간 차이: ${scheduledTime.difference(now).inSeconds}초');

    try {
      // 고유한 ID 생성 (기존 알림과 충돌 방지)
      final int notificationId = DateTime.now().millisecondsSinceEpoch.remainder(100000);
      
      await flutterLocalNotificationsPlugin.zonedSchedule(
        notificationId,
        title,
        message,
        scheduledTime,
        details,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      );

      debugPrint('✅ 알림이 성공적으로 예약되었습니다 (ID: $notificationId)');

      // 예약된 알림 확인
      final pendingNotifications = await flutterLocalNotificationsPlugin.pendingNotificationRequests();
      debugPrint('📋 예약된 알림 개수: ${pendingNotifications.length}');
      for (var notification in pendingNotifications) {
        debugPrint('📋 알림 ID: ${notification.id}, 제목: ${notification.title}');
      }
      
    } catch (e) {
      debugPrint('❌ 알림 예약 실패: $e');
    }
  }

  // 즉시 알림 테스트용 메서드
  Future<void> showImmediateNotification(String title, String message) async {
    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'pomodoro_channel',
      'Pomodoro Notifications',
      channelDescription: 'Pomodoro timer notifications',
      importance: Importance.high,
      priority: Priority.high,
      enableVibration: true,
      enableLights: true,
      playSound: true,
    );

    const NotificationDetails details = NotificationDetails(android: androidDetails);
    
    try {
      await flutterLocalNotificationsPlugin.show(
        999, // 테스트용 고정 ID
        title,
        message,
        details,
      );
      debugPrint('✅ 즉시 알림 표시 완료');
    } catch (e) {
      debugPrint('❌ 즉시 알림 실패: $e');
    }
  }

  Future<void> cancelNotification() async {
    await flutterLocalNotificationsPlugin.cancelAll();
    debugPrint('🗑️ 모든 알림이 취소되었습니다');
  }
}