import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_background_service_android/flutter_background_service_android.dart';
import 'notification_service.dart';

class BackgroundService {
  static Future<void> initializeService() async {
    final service = FlutterBackgroundService();

    await service.configure(
      androidConfiguration: AndroidConfiguration(
        onStart: onStart,
        autoStart: true,
        isForegroundMode: false,
        notificationChannelId: 'pomodoro_background_service',
        initialNotificationTitle: '포모도로 타이머',
        initialNotificationContent: '백그라운드에서 실행 중...',
        foregroundServiceNotificationId: 888,
      ),
      iosConfiguration: IosConfiguration(
        autoStart: true,
        onForeground: onStart,
        onBackground: onIosBackground,
      ),
    );
  }

  @pragma('vm:entry-point')
  static void onStart(ServiceInstance service) async {
    DartPluginRegistrant.ensureInitialized();

    if (service is AndroidServiceInstance) {
      service.on('setAsForeground').listen((event) {
        service.setAsForegroundService();
      });

      service.on('setAsBackground').listen((event) {
        service.setAsBackgroundService();
      });
    }

    service.on('stopService').listen((event) {
      service.stopSelf();
    });

    // 타이머 시작 이벤트 리스너
    service.on('startTimer').listen((event) {
      final data = event!;
      final int totalSeconds = data['totalSeconds'];
      final bool isWorkTime = data['isWorkTime'];
      final String sessionType = data['sessionType'];
      
      _startBackgroundTimer(service, totalSeconds, isWorkTime, sessionType);
    });

    // 타이머 중지 이벤트 리스너
    service.on('stopTimer').listen((event) {
      NotificationService.cancelOngoingNotification();
    });
  }

  static Future<void> _startBackgroundTimer(
    ServiceInstance service,
    int totalSeconds,
    bool isWorkTime,
    String sessionType,
  ) async {
    int remainingSeconds = totalSeconds;

    Timer.periodic(const Duration(seconds: 1), (timer) async {
      if (remainingSeconds <= 0) {
        timer.cancel();
        
        // 타이머 완료 알림
        if (isWorkTime) {
          await NotificationService.showWorkCompletedNotification();
          service.invoke('timerCompleted', {'type': 'work'});
        } else {
          await NotificationService.showBreakCompletedNotification();
          service.invoke('timerCompleted', {'type': 'break'});
        }

        // 진행 중 알림 제거
        await NotificationService.cancelOngoingNotification();
        return;
      }

      remainingSeconds--;
      
      // 매 30초마다 또는 마지막 10초에 진행 상황 알림 업데이트
      if (remainingSeconds % 30 == 0 || remainingSeconds <= 10) {
        final minutes = remainingSeconds ~/ 60;
        final seconds = remainingSeconds % 60;
        final timeLeft = '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
        
        await NotificationService.showOngoingNotification(timeLeft, isWorkTime);
      }

      // UI에 시간 업데이트 전송
      service.invoke('timeUpdate', {
        'remainingSeconds': remainingSeconds,
        'minutes': remainingSeconds ~/ 60,
        'seconds': remainingSeconds % 60,
      });
    });
  }

  @pragma('vm:entry-point')
  static Future<bool> onIosBackground(ServiceInstance service) async {
    WidgetsFlutterBinding.ensureInitialized();
    DartPluginRegistrant.ensureInitialized();
    return true;
  }

  // 백그라운드 타이머 시작
  static Future<void> startBackgroundTimer({
    required int totalSeconds,
    required bool isWorkTime,
    required String sessionType,
  }) async {
    final service = FlutterBackgroundService();
    
    if (await service.isRunning()) {
      service.invoke('startTimer', {
        'totalSeconds': totalSeconds,
        'isWorkTime': isWorkTime,
        'sessionType': sessionType,
      });
    }
  }

  // 백그라운드 타이머 중지
  static Future<void> stopBackgroundTimer() async {
    final service = FlutterBackgroundService();
    
    if (await service.isRunning()) {
      service.invoke('stopTimer');
    }
  }

  // 백그라운드 서비스 중지
  static Future<void> stopService() async {
    final service = FlutterBackgroundService();
    service.invoke('stopService');
  }

  // 서비스 실행 상태 확인
  static Future<bool> isServiceRunning() async {
    final service = FlutterBackgroundService();
    return await service.isRunning();
  }

  // 시간 업데이트 리스너 등록
  static void listenToTimeUpdates(Function(Map<String, dynamic>) onTimeUpdate) {
    final service = FlutterBackgroundService();
    service.on('timeUpdate').listen((event) {
      if (event != null) {
        onTimeUpdate(event);
      }
    });
  }

  // 타이머 완료 리스너 등록
  static void listenToTimerCompletion(Function(String) onTimerCompleted) {
    final service = FlutterBackgroundService();
    service.on('timerCompleted').listen((event) {
      if (event != null && event['type'] != null) {
        onTimerCompleted(event['type']);
      }
    });
  }
}