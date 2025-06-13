import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'environment_service.dart';
import 'notification_service.dart';
import 'storage_service.dart';

class WaterIntakeRecord {
  final DateTime timestamp;
  final int amount;
  
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
  
  static Stream<String> get alertStream {
    _alertController ??= StreamController<String>.broadcast();
    return _alertController!.stream;
  }

  static Stream<List<WaterIntakeRecord>> get waterIntakeStream {
    _waterIntakeController ??= StreamController<List<WaterIntakeRecord>>.broadcast();
    return _waterIntakeController!.stream;
  }

  static Future<void> initialize() async {
    await _loadTodayWaterIntake();
    _startWaterReminder();
    _startEnvironmentMonitoring();
    
    EnvironmentService.environmentDataStream.listen((data) {
      _handleEnvironmentChange(data);
    });
  }

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
      _todayWaterIntake = [];
    }
  }

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

  static String _getTodayString() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  static Future<void> addWaterIntake(int amount) async {
    final record = WaterIntakeRecord(
      timestamp: DateTime.now(),
      amount: amount,
    );
    
    _todayWaterIntake.add(record);
    await _saveTodayWaterIntake();
    _waterIntakeController?.add(_todayWaterIntake);
    
    _showWaterIntakeConfirmation(amount);
  }

  static void _showWaterIntakeConfirmation(int amount) {
    final message = '💧 ${amount}ml 수분 섭취 완료! 훌륭해요!';
    _alertController?.add(message);
  }

  static int getTodayTotalWaterIntake() {
    return _todayWaterIntake.fold(0, (sum, record) => sum + record.amount);
  }

  static int getRecommendedDailyWaterIntake() {
    final hourlyIntake = EnvironmentService.getRecommendedWaterIntake();
    return hourlyIntake * 8;
  }

  static double getWaterIntakeProgress() {
    final total = getTodayTotalWaterIntake();
    final recommended = getRecommendedDailyWaterIntake();
    return total / recommended;
  }

  static void _startWaterReminder() {
    _waterReminderTimer = Timer.periodic(const Duration(minutes: 30), (timer) {
      _checkWaterIntakeReminder();
    });
  }

  static void _checkWaterIntakeReminder() {
    final now = DateTime.now();
    final workingHours = now.hour >= 8 && now.hour <= 18;
    
    if (!workingHours) return;

    if (_todayWaterIntake.isNotEmpty) {
      final lastIntake = _todayWaterIntake.last.timestamp;
      final timeSinceLastIntake = now.difference(lastIntake);
      
      if (timeSinceLastIntake.inMinutes >= 45) {
        _sendWaterReminderNotification();
      }
    } else {
      _sendWaterReminderNotification();
    }
  }

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
      4,
    );
    
    _alertController?.add(message);
  }

  static void _startEnvironmentMonitoring() {
    _environmentCheckTimer = Timer.periodic(const Duration(minutes: 10), (timer) {
      _checkEnvironmentAlerts();
    });
  }

  static void _handleEnvironmentChange(EnvironmentData data) {
    switch (data.heatLevel) {
      case HeatLevel.caution:
        _sendHeatCautionAlert(data);
        break;
      case HeatLevel.warning:
        _sendHeatWarningAlert(data);
        break;
      default:
        break;
    }
  }

  static void _checkEnvironmentAlerts() {
    final environmentData = EnvironmentService.getCurrentEnvironmentData();
    if (environmentData == null) return;

    final now = DateTime.now();
    final isWorkingTime = now.hour >= 8 && now.hour <= 18;
    
    if (!isWorkingTime) return;

    switch (environmentData.heatLevel) {
      case HeatLevel.caution:
        _sendPeriodicHeatCaution(environmentData);
        break;
      case HeatLevel.warning:
        _sendPeriodicHeatWarning(environmentData);
        break;
      default:
        break;
    }
  }

  static void _sendHeatCautionAlert(EnvironmentData data) async {
    final message = '⚠️ 중간정도 온도입니다! 체감온도 ${data.heatIndex.toStringAsFixed(1)}°C\n${data.getHeatLevelDescription()}';
    
    await NotificationService.showCustomNotification(
      '🌡️ 온도 주의',
      message,
      5,
    );
    
    _alertController?.add(message);
  }

  static void _sendHeatWarningAlert(EnvironmentData data) async {
    final message = '🚨 폭염 위험! 체감온도 ${data.heatIndex.toStringAsFixed(1)}°C\n${data.getHeatLevelDescription()}';
    
    await NotificationService.showCustomNotification(
      '🚨 폭염 경보',
      message,
      6,
    );
    
    await NotificationService.vibrateOnly();
    
    _alertController?.add(message);
  }

  static void _sendPeriodicHeatCaution(EnvironmentData data) async {
    final message = '계속된 고온 주의! 현재 ${data.temperature.toStringAsFixed(1)}°C';
    _alertController?.add(message);
  }

  static void _sendPeriodicHeatWarning(EnvironmentData data) async {
    final message = '⚠️ 지속적인 폭염 위험! 즉시 시원한 곳으로 이동하세요!';
    
    await NotificationService.showCustomNotification(
      '🚨 긴급 알림',
      message,
      7,
    );
    
    _alertController?.add(message);
  }

  static String getForceBreakMessage() {
    final environmentData = EnvironmentService.getCurrentEnvironmentData();
    if (environmentData == null) {
      return '고온 환경이 감지되었습니다. 안전을 위해 휴식을 취하세요.';
    }

    return '🚨 긴급! 체감온도 ${environmentData.heatIndex.toStringAsFixed(1)}°C\n'
           '작업을 중단하고 시원한 곳에서 충분히 휴식하세요.\n'
           '수분을 섭취하고 몸을 식히는 것이 중요합니다.';
  }

  static List<int> getWaterIntakeSuggestions() {
    final environmentData = EnvironmentService.getCurrentEnvironmentData();
    if (environmentData == null) return [200, 300, 500];

    switch (environmentData.heatLevel) {
      case HeatLevel.normal:
        return [150, 200, 250];
      case HeatLevel.caution:
        return [200, 300, 400];
      case HeatLevel.warning:
        return [300, 400, 500];
    }
  }

  static int getTodayHeatRiskScore() {
    final environmentData = EnvironmentService.getCurrentEnvironmentData();
    if (environmentData == null) return 0;

    final baseScore = switch (environmentData.heatLevel) {
      HeatLevel.normal => 10,
      HeatLevel.caution => 40,
      HeatLevel.warning => 80,
    };

    final waterProgress = getWaterIntakeProgress();
    final waterBonus = (waterProgress * 20).clamp(0, 20).toInt();

    return (baseScore - waterBonus).clamp(0, 100);
  }

  static String getHealthStatusMessage() {
    final riskScore = getTodayHeatRiskScore();
    final waterProgress = getWaterIntakeProgress();
    
    if (riskScore <= 20 && waterProgress >= 0.8) {
      return '✅ 수분 섭취 인증 완료!\n참 잘했어요! 물을 마신 게 확인했어요.';
    } else if (riskScore <= 40) {
      return '😐 물 한잔 마셔볼까요?\n아래 버튼을 눌러 인증해주세요.';
    } else if (riskScore <= 60) {
      return '😰 그늘에 머무르며 열을 식혀보아요.';
    } else {
      return '🚨 타이머가 곧 시작됩니다.\n지금은 휴식시간입니다.\n물 한잔 마셔볼까요?\n아래 버튼을 눌러 인증해주세요.';
    }
  }

  static void dispose() {
    _waterReminderTimer?.cancel();
    _environmentCheckTimer?.cancel();
    _waterIntakeController?.close();
    _alertController?.close();
  }
}
