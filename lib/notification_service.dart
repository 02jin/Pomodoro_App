import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:vibration/vibration.dart';
import 'package:permission_handler/permission_handler.dart';

class NotificationService {
  static final FlutterLocalNotificationsPlugin _notificationsPlugin = 
      FlutterLocalNotificationsPlugin();

  // 초기화
  static Future<void> initialize() async {
    // 안드로이드 초기화 설정
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    // iOS 초기화 설정
    const DarwinInitializationSettings initializationSettingsIOS =
        DarwinInitializationSettings(
      requestSoundPermission: true,
      requestBadgePermission: true,
      requestAlertPermission: true,
    );

    const InitializationSettings initializationSettings =
        InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsIOS,
    );

    await _notificationsPlugin.initialize(initializationSettings);
    
    // 알림 권한 요청
    await _requestNotificationPermissions();
  }

  // 알림 권한 요청
  static Future<void> _requestNotificationPermissions() async {
    // 안드로이드 13 이상에서 알림 권한 요청
    if (await Permission.notification.isDenied) {
      await Permission.notification.request();
    }
  }

  // 작업 완료 알림
  static Future<void> showWorkCompletedNotification() async {
    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
      'pomodoro_channel',
      'Pomodoro Notifications',
      channelDescription: '포모도로 타이머 알림',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
      sound: RawResourceAndroidNotificationSound('notification_sound'),
    );

    const DarwinNotificationDetails iOSPlatformChannelSpecifics =
        DarwinNotificationDetails(
      sound: 'notification_sound.wav',
    );

    const NotificationDetails platformChannelSpecifics = NotificationDetails(
      android: androidPlatformChannelSpecifics,
      iOS: iOSPlatformChannelSpecifics,
    );

    await _notificationsPlugin.show(
      0, // 알림 ID
      '🎉 작업 완료!',
      '25분 작업이 완료되었습니다. 5분 휴식을 시작하세요!',
      platformChannelSpecifics,
    );

    // 진동
    await _vibrate();
  }

  // 휴식 완료 알림
  static Future<void> showBreakCompletedNotification() async {
    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
      'pomodoro_channel',
      'Pomodoro Notifications',
      channelDescription: '포모도로 타이머 알림',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
      sound: RawResourceAndroidNotificationSound('notification_sound'),
    );

    const DarwinNotificationDetails iOSPlatformChannelSpecifics =
        DarwinNotificationDetails(
      sound: 'notification_sound.wav',
    );

    const NotificationDetails platformChannelSpecifics = NotificationDetails(
      android: androidPlatformChannelSpecifics,
      iOS: iOSPlatformChannelSpecifics,
    );

    await _notificationsPlugin.show(
      1, // 알림 ID
      '💪 휴식 완료!',
      '휴식이 끝났습니다. 다음 작업을 시작할 준비가 되셨나요?',
      platformChannelSpecifics,
    );

    // 진동
    await _vibrate();
  }

  // 진동 기능
  static Future<void> _vibrate() async {
    // 진동 지원 여부 확인
    if (await Vibration.hasVibrator() ?? false) {
      // 패턴 진동 (0.5초 진동, 0.2초 멈춤, 0.5초 진동)
      await Vibration.vibrate(
        pattern: [0, 500, 200, 500],
      );
    }
  }

  // 진동만 (알림 없이)
  static Future<void> vibrateOnly() async {
    await _vibrate();
  }

  // 백그라운드 타이머 완료 알림
  static Future<void> showBackgroundTimerNotification(String title, String body) async {
    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
      'pomodoro_background_channel',
      'Pomodoro Background Notifications',
      channelDescription: '백그라운드 포모도로 타이머 알림',
      importance: Importance.max,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
      ongoing: false,
      autoCancel: true,
    );

    const NotificationDetails platformChannelSpecifics = NotificationDetails(
      android: androidPlatformChannelSpecifics,
    );

    await _notificationsPlugin.show(
      2, // 알림 ID
      title,
      body,
      platformChannelSpecifics,
    );

    await _vibrate();
  }

  // 백그라운드 서비스 진행 중 알림 (지속적으로 표시)
  static Future<void> showOngoingNotification(String timeLeft, bool isWorkTime) async {
    final String title = isWorkTime ? '🔥 작업 시간 진행 중' : '😎 휴식 시간 진행 중';
    final String body = '남은 시간: $timeLeft';

    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
      'pomodoro_ongoing_channel',
      'Pomodoro Ongoing Timer',
      channelDescription: '진행 중인 포모도로 타이머',
      importance: Importance.low,
      priority: Priority.low,
      icon: '@mipmap/ic_launcher',
      ongoing: true, // 지속적으로 표시
      autoCancel: false,
      showWhen: false,
    );

    const NotificationDetails platformChannelSpecifics = NotificationDetails(
      android: androidPlatformChannelSpecifics,
    );

    await _notificationsPlugin.show(
      3, // 알림 ID
      title,
      body,
      platformChannelSpecifics,
    );
  }

  // 진행 중 알림 제거
  static Future<void> cancelOngoingNotification() async {
    await _notificationsPlugin.cancel(3);
  }

  // 모든 알림 제거
  static Future<void> cancelAllNotifications() async {
    await _notificationsPlugin.cancelAll();
  }
}