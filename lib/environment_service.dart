import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:flutter/material.dart';
import 'dart:async';

// 환경 위험 레벨 enum
enum HeatRiskLevel {
  safe,      // 안전 (25도 미만)
  caution,   // 주의 (25-30도)
  warning,   // 경고 (30-35도)
  danger,    // 위험 (35도 이상)
}

// 환경 데이터 모델
class EnvironmentData {
  final double temperature;
  final double humidity;
  final double heatIndex;  // 체감온도
  final HeatRiskLevel riskLevel;
  final String location;
  final DateTime timestamp;
  final String weatherDescription;

  EnvironmentData({
    required this.temperature,
    required this.humidity,
    required this.heatIndex,
    required this.riskLevel,
    required this.location,
    required this.timestamp,
    required this.weatherDescription,
  });

  // 위험 레벨에 따른 권장 휴식 시간 (분)
  int getRecommendedBreakMinutes() {
    switch (riskLevel) {
      case HeatRiskLevel.safe:
        return 5;   // 기본 5분
      case HeatRiskLevel.caution:
        return 8;   // 8분으로 증가
      case HeatRiskLevel.warning:
        return 12;  // 12분으로 증가
      case HeatRiskLevel.danger:
        return 20;  // 20분으로 대폭 증가
    }
  }

  // 위험 레벨에 따른 권장 작업 시간 (분)
  int getRecommendedWorkMinutes() {
    switch (riskLevel) {
      case HeatRiskLevel.safe:
        return 25;  // 기본 25분
      case HeatRiskLevel.caution:
        return 20;  // 20분으로 감소
      case HeatRiskLevel.warning:
        return 15;  // 15분으로 감소
      case HeatRiskLevel.danger:
        return 10;  // 10분으로 대폭 감소
    }
  }

  // 위험 레벨 색상
  Color getRiskLevelColor() {
    switch (riskLevel) {
      case HeatRiskLevel.safe:
        return const Color(0xFF4CAF50);    // 초록색
      case HeatRiskLevel.caution:
        return const Color(0xFFFF9800);    // 주황색
      case HeatRiskLevel.warning:
        return const Color(0xFFFF5722);    // 빨간 주황색
      case HeatRiskLevel.danger:
        return const Color(0xFFD32F2F);    // 빨간색
    }
  }

  // 위험 레벨 메시지
  String getRiskLevelMessage() {
    switch (riskLevel) {
      case HeatRiskLevel.safe:
        return '안전한 환경입니다. 정상적으로 작업하세요.';
      case HeatRiskLevel.caution:
        return '주의가 필요합니다. 수분 섭취를 잊지 마세요.';
      case HeatRiskLevel.warning:
        return '경고! 휴식 시간을 늘리고 그늘에서 쉬세요.';
      case HeatRiskLevel.danger:
        return '위험! 작업을 중단하고 시원한 곳으로 피하세요.';
    }
  }

  // 이모지
  String getRiskLevelEmoji() {
    switch (riskLevel) {
      case HeatRiskLevel.safe:
        return '😊';
      case HeatRiskLevel.caution:
        return '😐';
      case HeatRiskLevel.warning:
        return '😰';
      case HeatRiskLevel.danger:
        return '🚨';
    }
  }
}

class EnvironmentService {
  static const String _openWeatherApiKey = 'YOUR_API_KEY_HERE'; // 실제 API 키로 교체 필요
  static const String _baseUrl = 'https://api.openweathermap.org/data/2.5/weather';
  
  static EnvironmentData? _lastEnvironmentData;
  static Timer? _updateTimer;
  static StreamController<EnvironmentData>? _dataStreamController;

  // 환경 데이터 스트림
  static Stream<EnvironmentData> get environmentDataStream {
    _dataStreamController ??= StreamController<EnvironmentData>.broadcast();
    return _dataStreamController!.stream;
  }

  // 초기화
  static Future<void> initialize() async {
    await _requestLocationPermission();
    await _startPeriodicUpdates();
  }

  // 위치 권한 요청
  static Future<bool> _requestLocationPermission() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return false;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return false;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      return false;
    }

    return true;
  }

  // 주기적 업데이트 시작 (5분마다)
  static Future<void> _startPeriodicUpdates() async {
    // 초기 데이터 로드
    await updateEnvironmentData();
    
    // 5분마다 업데이트
    _updateTimer = Timer.periodic(const Duration(minutes: 5), (timer) {
      updateEnvironmentData();
    });
  }

  // 환경 데이터 업데이트
  static Future<EnvironmentData?> updateEnvironmentData() async {
    try {
      // 현재 위치 가져오기
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.low,
      );

      // 날씨 데이터 가져오기
      final weatherData = await _fetchWeatherData(position.latitude, position.longitude);
      
      if (weatherData != null) {
        _lastEnvironmentData = weatherData;
        _dataStreamController?.add(weatherData);
        return weatherData;
      }
    } catch (e) {
      print('환경 데이터 업데이트 실패: $e');
      
      // 오프라인 모드 - 기본값 사용
      return await _createMockEnvironmentData();
    }
    
    return null;
  }

  // 날씨 API에서 데이터 가져오기
  static Future<EnvironmentData?> _fetchWeatherData(double lat, double lon) async {
    try {
      final url = '$_baseUrl?lat=$lat&lon=$lon&appid=$_openWeatherApiKey&units=metric&lang=kr';
      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        final temperature = data['main']['temp'].toDouble();
        final humidity = data['main']['humidity'].toDouble();
        final description = data['weather'][0]['description'] ?? '알 수 없음';
        
        // 지역명 가져오기
        List<Placemark> placemarks = await placemarkFromCoordinates(lat, lon);
        String location = '알 수 없는 위치';
        if (placemarks.isNotEmpty) {
          location = '${placemarks.first.locality ?? ''} ${placemarks.first.subLocality ?? ''}';
        }

        // 체감온도 계산 (열지수)
        final heatIndex = _calculateHeatIndex(temperature, humidity);
        
        // 위험 레벨 결정
        final riskLevel = _determineRiskLevel(heatIndex);

        return EnvironmentData(
          temperature: temperature,
          humidity: humidity,
          heatIndex: heatIndex,
          riskLevel: riskLevel,
          location: location,
          timestamp: DateTime.now(),
          weatherDescription: description,
        );
      }
    } catch (e) {
      print('날씨 API 호출 실패: $e');
    }
    
    return null;
  }

  // 오프라인 모드용 모의 환경 데이터 생성
  static Future<EnvironmentData> _createMockEnvironmentData() async {
    // 시간대에 따른 온도 시뮬레이션
    final hour = DateTime.now().hour;
    double baseTemp = 25.0;
    
    if (hour >= 10 && hour <= 16) {
      baseTemp = 30.0; // 낮 시간대
    } else if (hour >= 6 && hour <= 9) {
      baseTemp = 27.0; // 오전
    } else if (hour >= 17 && hour <= 20) {
      baseTemp = 28.0; // 저녁
    }

    final temperature = baseTemp + (DateTime.now().millisecond % 10 - 5); // ±5도 랜덤
    const humidity = 65.0;
    final heatIndex = _calculateHeatIndex(temperature, humidity);
    final riskLevel = _determineRiskLevel(heatIndex);

    return EnvironmentData(
      temperature: temperature,
      humidity: humidity,
      heatIndex: heatIndex,
      riskLevel: riskLevel,
      location: '부산, 부산진구', // 사용자 위치 정보 활용
      timestamp: DateTime.now(),
      weatherDescription: '시뮬레이션 데이터',
    );
  }

  // 체감온도(열지수) 계산
  static double _calculateHeatIndex(double temp, double humidity) {
    // 섭씨 온도를 화씨로 변환
    double fahrenheit = temp * 9/5 + 32;
    
    // 열지수 계산 공식 (Rothfusz equation)
    double hi = 0.5 * (fahrenheit + 61.0 + ((fahrenheit - 68.0) * 1.2) + (humidity * 0.094));
    
    if (hi >= 80) {
      // 더 정확한 공식 사용
      hi = -42.379 +
           2.04901523 * fahrenheit +
           10.14333127 * humidity -
           0.22475541 * fahrenheit * humidity -
           0.00683783 * fahrenheit * fahrenheit -
           0.05481717 * humidity * humidity +
           0.00122874 * fahrenheit * fahrenheit * humidity +
           0.00085282 * fahrenheit * humidity * humidity -
           0.00000199 * fahrenheit * fahrenheit * humidity * humidity;
    }
    
    // 화씨를 다시 섭씨로 변환
    return (hi - 32) * 5/9;
  }

  // 위험 레벨 결정
  static HeatRiskLevel _determineRiskLevel(double heatIndex) {
    if (heatIndex < 25) {
      return HeatRiskLevel.safe;
    } else if (heatIndex < 30) {
      return HeatRiskLevel.caution;
    } else if (heatIndex < 35) {
      return HeatRiskLevel.warning;
    } else {
      return HeatRiskLevel.danger;
    }
  }

  // 현재 환경 데이터 가져오기
  static EnvironmentData? getCurrentEnvironmentData() {
    return _lastEnvironmentData;
  }

  // 수분 섭취 권장량 계산 (ml/시간)
  static int getRecommendedWaterIntake() {
    final data = getCurrentEnvironmentData();
    if (data == null) return 250; // 기본값
    
    switch (data.riskLevel) {
      case HeatRiskLevel.safe:
        return 200;
      case HeatRiskLevel.caution:
        return 300;
      case HeatRiskLevel.warning:
        return 400;
      case HeatRiskLevel.danger:
        return 500;
    }
  }

  // 강제 휴식 필요 여부 확인
  static bool shouldForceBreak() {
    final data = getCurrentEnvironmentData();
    return data?.riskLevel == HeatRiskLevel.danger;
  }

  // 리소스 정리
  static void dispose() {
    _updateTimer?.cancel();
    _dataStreamController?.close();
  }
}
