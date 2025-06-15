
import 'package:flutter/cupertino.dart';
import 'package:get/get.dart';
import 'package:pomodoro_timer/app/weather/constants/weather_constant.dart';
import 'package:pomodoro_timer/app/weather/services/weather_service.dart';

class TimerService extends GetxService {
  final RxInt _targetDuration = RxInt(60 * 90);
  // 분
  final RxInt _leftSecond = RxInt(60 * 90);
  final WeatherService _weatherService = Get.find<WeatherService>();


  @override
  void onReady() async {
    super.onReady();
    _weatherService.weatherStream.listen((weather) {
      switch(weather.heatLevel) {
        case HeatLevel.warning:
          // 60초 * 90 = 90분
          _targetDuration.value = 60 * 45;
          break;
        case HeatLevel.caution:
          _targetDuration.value = 60 * 60;
          break;
        case HeatLevel.normal:
          _targetDuration.value = 60 * 90;
      }
    });
  }

  RxInt getTargetDuration() {
    return _targetDuration;
  }

  void setTargetDuration(int targetDuration) {
    _targetDuration.value = targetDuration;
  }

  RxInt getLeftSecond() {
    debugPrint("getLeftDuration: $_leftSecond");
    return _leftSecond;
  }

  void setLeftSecond(int leftSecond) {
    _leftSecond.value = leftSecond;
  }

}