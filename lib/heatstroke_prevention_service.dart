import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'environment_service.dart';
import 'notification_service.dart';
import 'storage_service.dart';

// 수분 섭취 기록 모델
class WaterIntakeRecord {
  final DateTime timestamp;
  final int amount; // ml
  
  WaterIntakeRecord({
    required this.timestamp,
    required this.amount,
  });
  
  Map<String, dynamic> toJson() {
    return {
      'timestamp': timestamp.millisecondsSinceEpoch,
      'amount': amount,
    };
  }
  
  factory WaterIntakeRecord.fromJson(Map<String, dynamic> json) {
    return WaterIntakeRecord(
      timestamp: DateTime.fromMillisecondsSinceEpoch(json['timestamp']),
      amount: json['amount'],
    );
  }
}

class HeatstrokePreventionService {
  static Timer? _waterReminderTimer;
  static Timer? _environmentCheckTimer;
  static List<WaterIntakeRecord> _todayWaterIntake = [];
  static StreamController<List<WaterIntakeRecord>>? _waterIntakeController;
  static StreamController<String>? _alertController;
  
  // 알림 스트림
  static Stream<String> get alertStream {
    _alertController ??= StreamController<String>.broadcast();
    return _alertController!.stream;
  }

  // 수분 섭취 기록 스트림
  static Stream<List<WaterIntakeRecord>> get waterIntakeStream {
    _waterIntakeController ??= StreamController<List<WaterIntakeRecord>>.broadcast();
    return _waterIntakeController!.stream;
  }

  // 초기화
  static Future<void> initialize() async {
    await _loadTodayWaterIntake();
    _startWaterReminder();
    _startEnvironmentMonitoring();
    
    // 환경 데이터 변화 감지
    EnvironmentService.environmentDataStream.listen((data) {
      _handleEnvironmentChange(data);
    });
  }

  // 오늘의 수분 섭취 기록 로드
  static Future<void> _loadTodayWaterIntake() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final today = _getTodayString();
      final lastSavedDate = prefs.getString('water_intake_date') ?? '';
      
      if (lastSavedDate == today) {
        final recordsJson = prefs.getStringList('water_intake_records') ?? [];
        _todayWaterIntake = recordsJson.map((json) {
          return WaterIntakeRecord.fromJson(Map<String, dynamic>.from(jsonDecode(json)));
        }).toList();
      } else {
        _todayWaterIntake = [];
        await _saveTodayWaterIntake();
      }
      
      _waterIntakeController?.add(_todayWaterIntake);
    } catch (e) {
      print('수분 섭취 기록 로드 실패: $e');
      _todayWaterIntake = [];
    }
  }

  // 오늘의 수분 섭취 기록 저장
  static Future<void> _saveTodayWaterIntake() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final today = _getTodayString();
      
      final recordsJson = _todayWaterIntake.map((record) {
        return jsonEncode(record.toJson());
      }).toList();
      
      await prefs.setStringList('water_intake_records', recordsJson);
      await prefs.setString('water_intake_date', today);
    } catch (e) {
      print('수분 섭취 기록 저장 실패: $e');
    }
  }

  // 오늘 날짜 문자열
  static String _getTodayString() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  // 수분 섭취 기록 추가
  static Future<void> addWaterIntake(int amount) async {
    final record = WaterIntakeRecord(
      timestamp: DateTime.now(),
      amount: amount,
    );
    
    _todayWaterIntake.add(record);
    await _saveTodayWaterIntake();
    _waterIntakeController?.add(_todayWaterIntake);
    
    // 긍정적인 피드백 알림
    _showWaterIntakeConfirmation(amount);
  }

  // 수분 섭취 확인 알림
  static void _showWaterIntakeConfirmation(int amount) {
    final message = '💧 ${amount}ml 수분 섭취 기록 완료! 훌륭해요!';
    _alertController?.add(message);
  }

  // 오늘 총 수분 섭취량 계산
  static int getTodayTotalWaterIntake() {
    return _todayWaterIntake.fold(0, (sum, record) => sum + record.amount);
  }

  // 권장 수분 섭취량 계산 (하루 기준)
  static int getRecommendedDailyWaterIntake() {
    final hourlyIntake = EnvironmentService.getRecommendedWaterIntake();
    return hourlyIntake * 8; // 8시간 작업 기준
  }

  // 수분 섭취 달성률 계산
  static double getWaterIntakeProgress() {
    final total = getTodayTotalWaterIntake();
    final recommended = getRecommendedDailyWaterIntake();
    return total / recommended;
  }

  // 수분 섭취 리마인더 시작
  static void _startWaterReminder() {
    // 30분마다 수분 섭취 리마인더
    _waterReminderTimer = Timer.periodic(const Duration(minutes: 30), (timer) {
      _checkWaterIntakeReminder();
    });
  }

  // 수분 섭취 리마인더 확인
  static void _checkWaterIntakeReminder() {
    final now = DateTime.now();
    final workingHours = now.hour >= 8 && now.hour <= 18;
    
    if (!workingHours) return;

    // 마지막 수분 섭취로부터 시간 확인
    if (_todayWaterIntake.isNotEmpty) {
      final lastIntake = _todayWaterIntake.last.timestamp;
      final timeSinceLastIntake = now.difference(lastIntake);
      
      if (timeSinceLastIntake.inMinutes >= 45) {
        _sendWaterReminderNotification();
      }
    } else {
      // 오늘 아직 수분 섭취 기록이 없음
      _sendWaterReminderNotification();
    }
  }

  // 수분 섭취 리마인더 알림 전송
  static void _sendWaterReminderNotification() async {
    final environmentData = EnvironmentService.getCurrentEnvironmentData();
    String message = '💧 수분 섭취 시간입니다!';
    
    if (environmentData != null) {
      final recommended = EnvironmentService.getRecommendedWaterIntake();
      message += ' 현재 ${environmentData.temperature.toStringAsFixed(1)}°C, ${recommended}ml 권장';
    }

    await NotificationService.showCustomNotification(
      '🚰 수분 보충 알림',
      message,
      4, // 알림 ID
    );
    
    _alertController?.add(message);
  }

  // 환경 모니터링 시작
  static void _startEnvironmentMonitoring() {
    // 10분마다 환경 상태 확인
    _environmentCheckTimer = Timer.periodic(const Duration(minutes: 10), (timer) {
      _checkEnvironmentAlerts();
    });
  }

  // 환경 변화 처리
  static void _handleEnvironmentChange(EnvironmentData data) {
    switch (data.riskLevel) {
      case HeatRiskLevel.warning:
        _sendHeatWarningAlert(data);
        break;
      case HeatRiskLevel.danger:
        _sendHeatDangerAlert(data);
        break;
      default:
        break;
    }
  }

  // 환경 알림 확인
  static void _checkEnvironmentAlerts() {
    final environmentData = EnvironmentService.getCurrentEnvironmentData();
    if (environmentData == null) return;

    final now = DateTime.now();
    final isWorkingTime = now.hour >= 8 && now.hour <= 18;
    
    if (!isWorkingTime) return;

    switch (environmentData.riskLevel) {
      case HeatRiskLevel.warning:
        _sendPeriodicHeatWarning(environmentData);
        break;
      case HeatRiskLevel.danger:
        _sendPeriodicHeatDanger(environmentData);
        break;
      default:
        break;
    }
  }

  // 열 경고 알림
  static void _sendHeatWarningAlert(EnvironmentData data) async {
    final message = '⚠️ 열 경고! 체감온도 ${data.heatIndex.toStringAsFixed(1)}°C\n${data.getRiskLevelMessage()}';
    
    await NotificationService.showCustomNotification(
      '🌡️ 열사병 경고',
      message,
      5, // 알림 ID
    );
    
    _alertController?.add(message);
  }

  // 열 위험 알림
  static void _sendHeatDangerAlert(EnvironmentData data) async {
    final message = '🚨 열 위험! 체감온도 ${data.heatIndex.toStringAsFixed(1)}°C\n${data.getRiskLevelMessage()}';
    
    await NotificationService.showCustomNotification(
      '🚨 열사병 위험',
      message,
      6, // 알림 ID
    );
    
    // 진동도 함께
    await NotificationService.vibrateOnly();
    
    _alertController?.add(message);
  }

  // 주기적 열 경고
  static void _sendPeriodicHeatWarning(EnvironmentData data) async {
    final message = '계속된 고온 주의보! 현재 ${data.temperature.toStringAsFixed(1)}°C';
    _alertController?.add(message);
  }

  // 주기적 열 위험
  static void _sendPeriodicHeatDanger(EnvironmentData data) async {
    final message = '⚠️ 지속적인 고온 위험! 즉시 시원한 곳으로 이동하세요!';
    
    await NotificationService.showCustomNotification(
      '🚨 긴급 알림',
      message,
      7, // 알림 ID
    );
    
    _alertController?.add(message);
  }

  // 강제 휴식 권장 메시지
  static String getForceBreakMessage() {
    final environmentData = EnvironmentService.getCurrentEnvironmentData();
    if (environmentData == null) {
      return '고온 환경이 감지되었습니다. 안전을 위해 휴식을 취하세요.';
    }

    return '🚨 긴급! 체감온도 ${environmentData.heatIndex.toStringAsFixed(1)}°C\n'
           '작업을 중단하고 시원한 곳에서 충분히 휴식하세요.\n'
           '수분을 섭취하고 몸을 식히는 것이 중요합니다.';
  }

  // 수분 섭취 제안 생성
  static List<int> getWaterIntakeSuggestions() {
    final environmentData = EnvironmentService.getCurrentEnvironmentData();
    if (environmentData == null) return [200, 300, 500];

    switch (environmentData.riskLevel) {
      case HeatRiskLevel.safe:
        return [150, 200, 250];
      case HeatRiskLevel.caution:
        return [200, 300, 400];
      case HeatRiskLevel.warning:
        return [300, 400, 500];
      case HeatRiskLevel.danger:
        return [400, 500, 600];
    }
  }

  // 오늘의 열사병 위험 점수 계산 (0-100)
  static int getTodayHeatRiskScore() {
    final environmentData = EnvironmentService.getCurrentEnvironmentData();
    if (environmentData == null) return 0;

    final baseScore = switch (environmentData.riskLevel) {
      HeatRiskLevel.safe => 10,
      HeatRiskLevel.caution => 30,
      HeatRiskLevel.warning => 60,
      HeatRiskLevel.danger => 90,
    };

    // 수분 섭취 상태에 따른 점수 조정
    final waterProgress = getWaterIntakeProgress();
    final waterBonus = (waterProgress * 20).clamp(0, 20).toInt();

    return (baseScore - waterBonus).clamp(0, 100);
  }

  // 건강 상태 메시지 생성
  static String getHealthStatusMessage() {
    final riskScore = getTodayHeatRiskScore();
    final waterProgress = getWaterIntakeProgress();
    
    if (riskScore <= 20 && waterProgress >= 0.8) {
      return '😊 훌륭합니다! 안전하게 작업하고 계세요.';
    } else if (riskScore <= 40) {
      return '😐 주의하며 작업하세요. 수분 섭취를 잊지 마세요.';
    } else if (riskScore <= 60) {
      return '😰 경고! 휴식을 자주 취하고 충분히 수분을 섭취하세요.';
    } else {
      return '🚨 위험! 작업을 중단하고 즉시 안전한 곳으로 이동하세요.';
    }
  }

  // 리소스 정리
  static void dispose() {
    _waterReminderTimer?.cancel();
    _environmentCheckTimer?.cancel();
    _waterIntakeController?.close();
    _alertController?.close();
  }
}

