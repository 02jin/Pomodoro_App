import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:vibration/vibration.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:audioplayers/audioplayers.dart';  

class NotificationService {
  static final FlutterLocalNotificationsPlugin _notificationsPlugin = 
      FlutterLocalNotificationsPlugin();
  
  // MP3 파일 재생을 위한 AudioPlayer 인스턴스
  static final AudioPlayer _audioPlayer = AudioPlayer();

  // 초기화
  static Future<void> initialize() async {
    try {
      print('🔧 알림 서비스 초기화 시작');
      
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
      print('✅ 알림 플러그인 초기화 완료');
      
      // 알림 권한 요청 (오류가 있어도 계속 진행)
      try {
        await _requestNotificationPermissions();
        print('✅ 알림 권한 요청 완료');
      } catch (e) {
        print('⚠️ 알림 권한 요청 실패: $e');
      }
      
      // AudioPlayer 설정 (오류가 있어도 계속 진행)
      try {
        await _setupAudioPlayer();
        print('✅ 오디오 플레이어 설정 완료');
      } catch (e) {
        print('⚠️ 오디오 플레이어 설정 실패: $e');
      }
      
      print('✅ 알림 서비스 초기화 완료');
    } catch (e) {
      print('❌ 알림 서비스 초기화 실패: $e');
      // 실패해도 앱이 중단되지 않도록 함
    }
  }

  // AudioPlayer 초기 설정
  static Future<void> _setupAudioPlayer() async {
    try {
      // 볼륨 설정 (0.0 ~ 1.0)
      await _audioPlayer.setVolume(0.8);
      
      // 재생 모드 설정 (한 번만 재생)
      await _audioPlayer.setReleaseMode(ReleaseMode.stop);
      
      print('✅ AudioPlayer 설정 성공');
    } catch (e) {
      print('⚠️ AudioPlayer 설정 실패: $e');
      // 실패해도 계속 진행
    }
  }

  // 알림 권한 요청
  static Future<void> _requestNotificationPermissions() async {
    try {
      // 안드로이드 13 이상에서 알림 권한 요청
      if (await Permission.notification.isDenied) {
        await Permission.notification.request();
      }
    } catch (e) {
      print('⚠️ 알림 권한 요청 중 오류: $e');
    }
  }

  // 🎵 MP3 사운드 재생 함수들
  
  // 작업 완료 사운드 (성취감 있는 소리)
  static Future<void> _playWorkCompleteSound() async {
    try {
      await _audioPlayer.stop(); // 기존 재생 중단
      await _audioPlayer.play(AssetSource('sound/work_complete.mp3'));
    } catch (e) {
      print('작업 완료 사운드 재생 실패: $e');
      // 실패 시 시스템 기본 알림음으로 대체
      await _playFallbackSound();
    }
  }

  // 휴식 완료 사운드 (부드러운 차임벨)
  static Future<void> _playBreakCompleteSound() async {
    try {
      await _audioPlayer.stop();
      await _audioPlayer.play(AssetSource('sound/break_complete.mp3'));
    } catch (e) {
      print('휴식 완료 사운드 재생 실패: $e');
      await _playFallbackSound();
    }
  }

  // 일반 알림 사운드 (짧고 명확한 소리)
  static Future<void> _playNotificationSound() async {
    try {
      await _audioPlayer.stop();
      await _audioPlayer.play(AssetSource('sound/notification.mp3'));
    } catch (e) {
      print('알림 사운드 재생 실패: $e');
      await _playFallbackSound();
    }
  }

  // 긴급 알림 사운드 (경고음)
  static Future<void> _playEmergencySound() async {
    try {
      await _audioPlayer.stop();
      await _audioPlayer.play(AssetSource('sound/emergency.mp3'));
    } catch (e) {
      print('긴급 알림 사운드 재생 실패: $e');
      await _playFallbackSound();
    }
  }

  // 폴백 사운드 (MP3 파일 재생 실패 시 시스템 알림음)
  static Future<void> _playFallbackSound() async {
    try {
      // SystemSound는 import 'package:flutter/services.dart'; 필요
      // await SystemSound.play(SystemSoundType.alert);
      print('시스템 기본 알림음 사용');
    } catch (e) {
      print('폴백 사운드도 실패: $e');
    }
  }

  // 작업 완료 알림
  static Future<void> showWorkCompletedNotification() async {
    try {
      const AndroidNotificationDetails androidPlatformChannelSpecifics =
          AndroidNotificationDetails(
        'pomodoro_channel',
        'Pomodoro Notifications',
        channelDescription: '포모도로 타이머 알림',
        importance: Importance.high,
        priority: Priority.high,
        icon: '@mipmap/ic_launcher',
        // 커스텀 MP3를 사용하므로 시스템 사운드 제거
      );

      const DarwinNotificationDetails iOSPlatformChannelSpecifics =
          DarwinNotificationDetails(
        // 커스텀 MP3를 사용하므로 시스템 사운드 제거
      );

      const NotificationDetails platformChannelSpecifics = NotificationDetails(
        android: androidPlatformChannelSpecifics,
        iOS: iOSPlatformChannelSpecifics,
      );

      await _notificationsPlugin.show(
        0, // 알림 ID
        '🎉 작업 완료!',
        '운동이 완료되었습니다. 휴식을 시작하세요!',
        platformChannelSpecifics,
      );

      // 커스텀 MP3 사운드 재생
      await _playWorkCompleteSound();
      
      // 진동
      await _vibrate();
    } catch (e) {
      print('작업 완료 알림 표시 실패: $e');
    }
  }

  // 휴식 완료 알림
  static Future<void> showBreakCompletedNotification() async {
    try {
      const AndroidNotificationDetails androidPlatformChannelSpecifics =
          AndroidNotificationDetails(
        'pomodoro_channel',
        'Pomodoro Notifications',
        channelDescription: '포모도로 타이머 알림',
        importance: Importance.high,
        priority: Priority.high,
        icon: '@mipmap/ic_launcher',
      );

      const DarwinNotificationDetails iOSPlatformChannelSpecifics =
          DarwinNotificationDetails();

      const NotificationDetails platformChannelSpecifics = NotificationDetails(
        android: androidPlatformChannelSpecifics,
        iOS: iOSPlatformChannelSpecifics,
      );

      await _notificationsPlugin.show(
        1, // 알림 ID
        '💪 휴식 완료!',
        '휴식이 끝났습니다. 다음 운동을 시작할 준비가 되셨나요?',
        platformChannelSpecifics,
      );

      // 커스텀 MP3 사운드 재생
      await _playBreakCompleteSound();
      
      // 진동
      await _vibrate();
    } catch (e) {
      print('휴식 완료 알림 표시 실패: $e');
    }
  }

  // 진동 기능
  static Future<void> _vibrate() async {
    try {
      // 진동 지원 여부 확인
      if (await Vibration.hasVibrator() ?? false) {
        // 패턴 진동 (0.5초 진동, 0.2초 멈춤, 0.5초 진동)
        await Vibration.vibrate(
          pattern: [0, 500, 200, 500],
        );
      }
    } catch (e) {
      print('진동 실행 실패: $e');
    }
  }

  // 진동만 (알림 없이)
  static Future<void> vibrateOnly() async {
    await _vibrate();
  }

  // 백그라운드 타이머 완료 알림
  static Future<void> showBackgroundTimerNotification(String title, String body) async {
    try {
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

      // 상황에 따른 사운드 재생
      if (title.contains('작업')) {
        await _playWorkCompleteSound();
      } else if (title.contains('휴식')) {
        await _playBreakCompleteSound();
      } else {
        await _playNotificationSound();
      }

      await _vibrate();
    } catch (e) {
      print('백그라운드 타이머 알림 표시 실패: $e');
    }
  }

  // 백그라운드 서비스 진행 중 알림 (지속적으로 표시)
  static Future<void> showOngoingNotification(String timeLeft, bool isWorkTime) async {
    try {
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
      
      // 진행 중 알림은 사운드 없음 (너무 시끄러워질 수 있음)
    } catch (e) {
      print('진행 중 알림 표시 실패: $e');
    }
  }

  // 진행 중 알림 제거
  static Future<void> cancelOngoingNotification() async {
    try {
      await _notificationsPlugin.cancel(3);
    } catch (e) {
      print('진행 중 알림 제거 실패: $e');
    }
  }

  // 커스텀 알림 (열사병 방지 등)
  static Future<void> showCustomNotification(String title, String body, int notificationId) async {
    try {
      const AndroidNotificationDetails androidPlatformChannelSpecifics =
          AndroidNotificationDetails(
        'heatstroke_prevention_channel',
        'Heatstroke Prevention Notifications',
        channelDescription: '열사병 방지 특화 알림',
        importance: Importance.high,
        priority: Priority.high,
        icon: '@mipmap/ic_launcher',
        color: Color.fromARGB(255, 255, 87, 34), // 주황빨강 색상
      );

      const DarwinNotificationDetails iOSPlatformChannelSpecifics =
          DarwinNotificationDetails();

      const NotificationDetails platformChannelSpecifics = NotificationDetails(
        android: androidPlatformChannelSpecifics,
        iOS: iOSPlatformChannelSpecifics,
      );

      await _notificationsPlugin.show(
        notificationId,
        title,
        body,
        platformChannelSpecifics,
      );

      // 상황에 따른 사운드 재생
      if (title.contains('🚨') || body.contains('위험') || body.contains('긴급')) {
        await _playEmergencySound();  // 긴급 상황 - 경고음
      } else if (title.contains('💧') || body.contains('수분') || body.contains('물')) {
        await _playNotificationSound();  // 수분 섭취 알림 - 일반 알림음
      } else {
        await _playNotificationSound();  // 기타 알림 - 일반 알림음
      }
      
      // 진동도 함께
      await _vibrate();
    } catch (e) {
      print('커스텀 알림 표시 실패: $e');
    }
  }

  // 🎵 볼륨 조절 기능
  static Future<void> setVolume(double volume) async {
    try {
      // volume: 0.0 (무음) ~ 1.0 (최대)
      await _audioPlayer.setVolume(volume.clamp(0.0, 1.0));
    } catch (e) {
      print('볼륨 설정 실패: $e');
    }
  }

  // 🔇 사운드 중지
  static Future<void> stopAllSounds() async {
    try {
      await _audioPlayer.stop();
    } catch (e) {
      print('사운드 중지 실패: $e');
    }
  }

  // 모든 알림 제거
  static Future<void> cancelAllNotifications() async {
    try {
      await _notificationsPlugin.cancelAll();
    } catch (e) {
      print('모든 알림 제거 실패: $e');
    }
  }

  // 리소스 정리 (앱 종료 시 호출)
  static Future<void> dispose() async {
    try {
      await _audioPlayer.dispose();
    } catch (e) {
      print('AudioPlayer 정리 실패: $e');
    }
  }
}