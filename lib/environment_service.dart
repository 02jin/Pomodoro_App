import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:flutter/material.dart';
import 'dart:async';

enum HeatLevel {
  normal,     // 일반더위 (90분 운동)
  caution,    // 폭염주의 (60분 운동)
  warning,    // 폭염경보 (45분 운동)
}

// HeatRiskLevel enum 추가 (heatstroke_prevention_service.dart에서 사용)
enum HeatRiskLevel {
  safe,
  caution,
  warning,
  danger,
}

class EnvironmentData {
  final double temperature;
  final double humidity;
  final double heatIndex;
  final HeatLevel heatLevel;
  final String location;
  final DateTime timestamp;
  final String weatherDescription;

  EnvironmentData({
    required this.temperature,
    required this.humidity,
    required this.heatIndex,
    required this.heatLevel,
    required this.location,
    required this.timestamp,
    required this.weatherDescription,
  });

  int getRecommendedWorkMinutes() {
    switch (heatLevel) {
      case HeatLevel.normal:
        return 90;  // 일반더위 - 90분 운동
      case HeatLevel.caution:
        return 60;  // 폭염주의 - 60분 운동
      case HeatLevel.warning:
        return 45;  // 폭염경보 - 45분 운동
    }
  }

  int getRecommendedBreakMinutes() {
    return 10;  // 모든 상황에서 10분 휴식 (기획 요구사항)
  }

  String getHeatLevelText() {
    return '지금은 운동시간입니다.';
  }

  String getHeatLevelDescription() {
    switch (heatLevel) {
      case HeatLevel.normal:
        return '현재 기온: ${temperature.toStringAsFixed(1)}°C\n☁️ 일반 더위 타이머가 적용됩니다.\n90분 운동 후 10분 휴식이 반복됩니다.';
      case HeatLevel.caution:
        return '현재 기온: ${temperature.toStringAsFixed(1)}°C\n🌤 폭염 주의 타이머가 적용됩니다.\n60분 운동 후 10분 휴식이 반복됩니다.';
      case HeatLevel.warning:
        return '현재 기온: ${temperature.toStringAsFixed(1)}°C\n🔥 폭염 경보 타이머가 적용됩니다.\n45분 운동 후 10분 휴식이 반복됩니다.';
    }
  }

  String getAdviceMessage() {
    switch (heatLevel) {
      case HeatLevel.normal:
        return '지금처럼 나만의 속도로,\n무리하지 않고 천천히 이어가보세요.';
      case HeatLevel.caution:
        return '반드시 수분을 섭취하고,\n햇빛을 피해 천천히 운동해주세요.';
      case HeatLevel.warning:
        return '지금은 폭염 경보 상태입니다.\n무리한 운동은 열사병 등 건강에 위협이 될 수 있어요.';
    }
  }

  // HeatRiskLevel 매핑 (기존 코드 호환성)
  HeatRiskLevel get riskLevel {
    switch (heatLevel) {
      case HeatLevel.normal:
        return HeatRiskLevel.safe;
      case HeatLevel.caution:
        return HeatRiskLevel.caution;
      case HeatLevel.warning:
        return HeatRiskLevel.warning;
    }
  }

  String getRiskLevelMessage() {
    return getAdviceMessage();
  }
}

class EnvironmentService {
  // 실제 OpenWeatherMap API 키 적용
  static const String _openWeatherApiKey = '68336ae6c49eeffb01de79e18757435f';
  static const String _baseUrl = 'https://api.openweathermap.org/data/2.5/weather';
  
  static EnvironmentData? _lastEnvironmentData;
  static Timer? _updateTimer;
  static StreamController<EnvironmentData>? _dataStreamController;

  static Stream<EnvironmentData> get environmentDataStream {
    _dataStreamController ??= StreamController<EnvironmentData>.broadcast();
    return _dataStreamController!.stream;
  }

  static Future<void> initialize() async {
    await _requestLocationPermission();
    await _startPeriodicUpdates();
  }

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

  static Future<void> _startPeriodicUpdates() async {
    await updateEnvironmentData();
    _updateTimer = Timer.periodic(const Duration(minutes: 5), (timer) {
      updateEnvironmentData();
    });
  }

  static Future<EnvironmentData?> updateEnvironmentData() async {
    try {
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.low,
        timeLimit: const Duration(seconds: 10),
      );

      print('위치 확인: ${position.latitude}, ${position.longitude}');

      final weatherData = await _fetchWeatherData(position.latitude, position.longitude);
      
      if (weatherData != null) {
        print('실제 날씨 데이터 로드 완료: ${weatherData.location} ${weatherData.temperature}°C');
        _lastEnvironmentData = weatherData;
        _dataStreamController?.add(weatherData);
        return weatherData;
      }
    } catch (e) {
      print('환경 데이터 업데이트 실패: $e');
    }
    
    print('⚠️ 실제 날씨 데이터 실패. 기본값으로 대체');
    final defaultData = _createDefaultEnvironmentData();
    _lastEnvironmentData = defaultData;
    _dataStreamController?.add(defaultData);
    return defaultData;
  }

  static Future<EnvironmentData?> _fetchWeatherData(double lat, double lon) async {
    try {
      final url = '$_baseUrl?lat=$lat&lon=$lon&appid=$_openWeatherApiKey&units=metric&lang=kr';
      print('날씨 API 호출: ${Uri.parse(url).host}');
      
      final response = await http.get(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 10));

      print('API 응답 상태: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        final temperature = data['main']['temp'].toDouble();
        final humidity = data['main']['humidity'].toDouble();
        final description = data['weather'][0]['description'] ?? '알 수 없음';
        
        // 위치 정보 가져오기
        String location = '현재 위치';
        try {
          List<Placemark> placemarks = await placemarkFromCoordinates(
            lat, 
            lon,
            localeIdentifier: 'ko_KR',
          );
          if (placemarks.isNotEmpty) {
            final place = placemarks.first;
            final city = place.locality ?? place.administrativeArea ?? '';
            final district = place.subLocality ?? place.subAdministrativeArea ?? '';
            location = '$city $district'.trim();
            if (location.isEmpty) location = '현재 위치';
          }
        } catch (e) {
          print('위치 정보 변환 실패: $e');
        }

        final heatIndex = _calculateHeatIndex(temperature, humidity);
        final heatLevel = _determineHeatLevel(heatIndex);

        print('날씨 데이터: $location, ${temperature}°C, 습도: ${humidity}%, 체감: ${heatIndex.toStringAsFixed(1)}°C');

        return EnvironmentData(
          temperature: temperature,
          humidity: humidity,
          heatIndex: heatIndex,
          heatLevel: heatLevel,
          location: location,
          timestamp: DateTime.now(),
          weatherDescription: description,
        );
      } else {
        print('날씨 API 오류: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      print('날씨 API 호출 실패: $e');
    }
    
    return null;
  }

  static EnvironmentData _createDefaultEnvironmentData() {
    return EnvironmentData(
      temperature: 25.0,                    // 기본 온도 (쾌적한 날씨)
      humidity: 60.0,                       // 기본 습도
      heatIndex: 25.0,                      // 기본 체감온도
      heatLevel: HeatLevel.normal,          // 일반 레벨 (90분 타이머)
      location: '위치 정보 없음',
      timestamp: DateTime.now(),
      weatherDescription: '기본 설정',
    );
  }


  static double _calculateHeatIndex(double temp, double humidity) {
    double fahrenheit = temp * 9/5 + 32;
    
    double hi = 0.5 * (fahrenheit + 61.0 + ((fahrenheit - 68.0) * 1.2) + (humidity * 0.094));
    
    if (hi >= 80) {
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
    
    return (hi - 32) * 5/9;
  }

  static HeatLevel _determineHeatLevel(double heatIndex) {
    if (heatIndex < 27) {
      return HeatLevel.normal;
    } else if (heatIndex < 31) {
      return HeatLevel.caution;
    } else {
      return HeatLevel.warning;
    }
  }

  static EnvironmentData? getCurrentEnvironmentData() {
    return _lastEnvironmentData;
  }

  static int getRecommendedWaterIntake() {
    final data = getCurrentEnvironmentData();
    if (data == null) return 250;
    
    switch (data.heatLevel) {
      case HeatLevel.normal:
        return 200;
      case HeatLevel.caution:
        return 300;
      case HeatLevel.warning:
        return 400;
    }
  }

  static bool shouldForceBreak() {
    final data = getCurrentEnvironmentData();
    return data?.heatLevel == HeatLevel.warning;
  }

  static void dispose() {
    _updateTimer?.cancel();
    _dataStreamController?.close();
  }
}