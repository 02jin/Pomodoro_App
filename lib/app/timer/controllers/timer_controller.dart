import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pomodoro_timer/app/timer/constants/timer_stage.dart';
import 'package:pomodoro_timer/app/timer/services/timer_service.dart';
import 'package:pomodoro_timer/app/weather/constants/weather_constant.dart';
import 'package:pomodoro_timer/app/weather/services/weather_service.dart';

import '../constants/pomodoro_stage.dart';

class TimerController extends GetxController {
  static TimerController get to => Get.find<TimerController>();
  static TimerService get _timerService => Get.find<TimerService>();
  final WeatherService _weatherService = Get.find<WeatherService>();

  final String _exercisingTitle = "🏃🏻지금은 운동 시간입니다";
  final String _needRestTitle = "🚨곧 휴식이 필요합니다";
  final String _itIsRestTimeTitle = "🍹지금은 휴식 시간입니다";
  String get exercisingTitle => _exercisingTitle;
  String get needRestTitle => _needRestTitle;
  String get itIsRestTimeTitle => _itIsRestTimeTitle;

  final String _normalMessage = "☁️일반 더위 타이머가 적용됩니다.\n90분 운동 후 10분 휴식이 반복됩니다.\n\n지금처럼 나만의 속도로\n무리하지 않고 천천히 이어가보세요.";
  final String _cautionMessage = "🌤폭염 주의 타이머가 적용됩니다.\n60분 운동 후 10분 휴식이 반복됩니다.\n\n반드시 수분을 섭취하고\n햇빛을 피해 천천히 운동해주세요.";
  final String _warningMessage = "🔥폭염 경보 타이머가 적용됩니다.\n45분 운동 후 15분 휴식이 반복됩니다.\n\n지금은 폭염 경보 상태입니다.\n무리한 운동은 열사병 등 건강에 위협이 될 수 있어요.";
  final String _restMessage = "👏🏻고생하셨어요!\n잠시 재충전하고 갈까요?";
  String get normalMessage => _normalMessage;
  String get cautionMessage => _cautionMessage;
  String get warningMessage => _warningMessage;
  String get restMessage => _restMessage;

  final RxBool _isDrinking = RxBool(false);
  bool get isDrinking => _isDrinking.value;

  final Rx<TimerStage> _timerStage = Rx<TimerStage>(TimerStage.idle);
  TimerStage get timerStage => _timerStage.value;

  final Rx<PomodoroStage> _pomodoroStage = Rx<PomodoroStage>(PomodoroStage.normal);
  PomodoroStage get pomodoroStage => _pomodoroStage.value;


  final Rx<List<Color>> _backgroundColor = Rx([Color(0xFFEAF3FF), Color(0xFFB5D1FF)]);
  List<Color> get backgroundColor => _backgroundColor.value;

  Rxn<PomodoroStage> stage = Rxn(PomodoroStage.normal);

  void setIsDrinking(bool isDrinking) {
    _isDrinking.value = isDrinking;
  }

  void setTimerStage(TimerStage timerStage) {
    _timerStage.value = timerStage;
  }

  void setPomodoroStage(PomodoroStage pomodoroStage) {
    _pomodoroStage.value = pomodoroStage;
  }

  void mapToBackgroundColorStage(int leftMinute) {
    if(stage.value == PomodoroStage.rest) {
      _backgroundColor.value = [Color(0xFFB2F1E0), Color(0xFFE6FFFB)];
    } else {
      if (leftMinute < 15 && leftMinute >= 5) {
        stage.value = PomodoroStage.warning;
        _backgroundColor.value = [Color(0xFFFFF2CC), Color(0xFFFFE8D9)];
      } else if (leftMinute < 5 && leftMinute > 0) {
        stage.value = PomodoroStage.danger;
        _backgroundColor.value = [Color(0xFFFF6666), Color(0xFFFFB3B3)];
      } else if (leftMinute == 0) {
        stage.value = PomodoroStage.complete;
        _backgroundColor.value = [Color(0xFFB2F1E0), Color(0xFFE6FFFB)];
      } else {
        stage.value = PomodoroStage.normal;
        _backgroundColor.value = [Color(0xFFEAF3FF), Color(0xFFB5D1FF)];
      }
    }
  }

  void setLeftSecond(int leftSecond) {
    _timerService.setLeftSecond(leftSecond);
  }

  void setTargetDuration(int targetDuration) {
    _timerService.setTargetDuration(targetDuration);
  }

  int getTargetDuration() {
    return _timerService.getTargetDuration().value;
  }

  int getleftSecond() {
    return _timerService.getLeftSecond().value;
  }

  String displayTitle() {
    switch(_pomodoroStage.value) {
      case PomodoroStage.rest:
        return _itIsRestTimeTitle;
      case PomodoroStage.warning:
        return _needRestTitle;
      default:
        return _exercisingTitle;
    }
  }

  HeatLevel getHeatLevel() {
    return _weatherService.getRxWeather().value.heatLevel;
  }

  String displayMessage() {
    if(_pomodoroStage.value == PomodoroStage.rest) return _restMessage;
    HeatLevel heatLevel = _weatherService.getRxWeather().value.heatLevel;
    switch (heatLevel) {
      case HeatLevel.normal:
        return _normalMessage;
      case HeatLevel.caution:
        return _cautionMessage;
      case HeatLevel.warning:
        return _warningMessage;
    }
  }
}