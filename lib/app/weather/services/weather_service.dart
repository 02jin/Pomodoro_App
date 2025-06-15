import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:pomodoro_timer/app/weather/constants/weather_constant.dart';
import 'package:pomodoro_timer/app/weather/models/weather_model.dart' as MyModel;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:pomodoro_timer/core/utils/weather_util.dart';

class WeatherService extends GetxService{
  final Rx<Timer?> updateTimer = Rx<Timer?>(null);
  final RxBool isPermissionAllowed = RxBool(false);
  final StreamController<MyModel.WeatherModel> _dataStreamController = StreamController<MyModel.WeatherModel>.broadcast();
  final Rx<MyModel.WeatherModel> _weather = Rx<MyModel.WeatherModel>(MyModel.WeatherModel(
    temperature: 25.0,                    // 기본 온도 (쾌적한 날씨)
    humidity: 60.0,                       // 기본 습도
    heatIndex: 25.0,                      // 기본 체감온도
    heatLevel: HeatLevel.normal,          // 일반 레벨 (90분 타이머)
    location: '위치 정보 없음',
    timestamp: DateTime.now(),
    iconCode: null,
    weatherDescription: '기본 설정',
  ));

  Stream<MyModel.WeatherModel> get weatherStream => _dataStreamController.stream;

  final MyModel.WeatherModel defaultWeatherModel = MyModel.WeatherModel(
    temperature: 25.0,                    // 기본 온도 (쾌적한 날씨)
    humidity: 60.0,                       // 기본 습도
    heatIndex: 25.0,                      // 기본 체감온도
    heatLevel: HeatLevel.normal,          // 일반 레벨 (90분 타이머)
    location: '위치 정보 없음',
    timestamp: DateTime.now(),
    iconCode: null,
    weatherDescription: '기본 설정',
  );

  @override
  void onReady() async {
    super.onReady();
    debugPrint("날씨 서비스 onReady Called");
    _weather.value = defaultWeatherModel;
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw Exception("위치 정보 서비스 초기화 실패");
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission != LocationPermission.always && permission != LocationPermission.whileInUse) {
      debugPrint("위치 권한 확인");
      permission = await Geolocator.requestPermission();
      if (permission != LocationPermission.always && permission != LocationPermission.whileInUse) {
        debugPrint("유저가 위치 권한 허용 안 함");
        isPermissionAllowed.value = false;
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      isPermissionAllowed.value = false;
      return;
    }

    isPermissionAllowed.value = true;
    startPeriodicUpdates();
    updateWeatherData();
  }

  Rx<MyModel.WeatherModel> getRxWeather() {
    return _weather;
  }

  void applyLatestWeatherData(MyModel.WeatherModel weather) {
    _weather.value = weather;
    _dataStreamController.add(weather);
  }

  /// 날씨 데이터 5분 마다 가져오는 함수
  Future startPeriodicUpdates() async {
    updateTimer.value = Timer.periodic(const Duration(minutes: 5), (timer) {
      updateWeatherData();
    });
  }
  
  /// 날씨 데이터 받아오는 함수, API 요청 실패시 기본 데이터 활용
  Future<MyModel.WeatherModel?> fetchWeatherData(double lat, double lon) async {
    try {
      const String baseUrl = 'https://api.openweathermap.org/data/2.5/weather';
      final url = '$baseUrl?lat=$lat&lon=$lon&appid=${dotenv.env["WEATHER_API_KEY"]}&units=metric&lang=kr';
      debugPrint('날씨 API 호출: ${Uri.parse(url).host}');
      
      final response = await http.get(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 10));

      debugPrint('API 응답 상태: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        final temperature = data['main']['temp'].toDouble();
        final humidity = data['main']['humidity'].toDouble();
        final iconCode = data['weather'][0]['icon'];
        final description = data['weather'][0]['description'] ?? '알 수 없음';
        
        // 위치 정보 가져오기
        String location = '현재 위치';
        try {
          List<Placemark> placemarks = await placemarkFromCoordinates(
            lat, 
            lon,
          );
          if (placemarks.isNotEmpty) {
            debugPrint("Place Mark 확인됨");
            final place = placemarks.first;
            final city = place.administrativeArea ?? '';
            final district = place.subLocality ?? place.subAdministrativeArea ?? '';
            location = '$city $district'.trim();
            if (location.isEmpty) location = '현재 위치';
          }
        } catch (e) {
          debugPrint('위치 정보 변환 실패: $e');
        }

        final heatIndex = WeatherUtil.calculateHeatIndex(temperature, humidity);
        final heatLevel = WeatherUtil.determineHeatLevel(heatIndex);

        debugPrint('날씨 데이터: $location, ${temperature}°C, 습도: ${humidity}%, 체감: ${heatIndex.toStringAsFixed(1)}°C');
        MyModel.WeatherModel result = MyModel.WeatherModel(
          temperature: temperature,
          humidity: humidity,
          heatIndex: heatIndex,
          heatLevel: heatLevel,
          location: location,
          iconCode: iconCode,
          timestamp: DateTime.now(),
          weatherDescription: description,
        );
        applyLatestWeatherData(result);
        return result;
      } else {
        debugPrint('날씨 API 오류: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      debugPrint('날씨 API 호출 실패: $e');
    }
    
    return null;
  }

  /// 
  Future<MyModel.WeatherModel?> updateWeatherData() async {
    try {
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.low,
        timeLimit: const Duration(seconds: 30),
      );

      debugPrint('위치 확인: ${position.latitude}, ${position.longitude}');

      final weatherData = await fetchWeatherData(position.latitude, position.longitude);
      
      if (weatherData != null) {
        debugPrint('실제 날씨 데이터 로드 완료: ${weatherData.location} ${weatherData.temperature}°C');
        applyLatestWeatherData(weatherData);
        return weatherData;
      }
    } catch (e) {
      debugPrint('환경 데이터 업데이트 실패: $e');
    }
    
    debugPrint('⚠️ 실제 날씨 데이터 실패. 기본값으로 대체');
    return defaultWeatherModel;
  }

  void dispose() {
    updateTimer.value?.cancel();
    _dataStreamController.close();
  }

}

