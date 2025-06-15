import 'package:get/get.dart';
import 'package:pomodoro_timer/app/weather/constants/weather_constant.dart';
import 'package:pomodoro_timer/app/weather/services/weather_service.dart';

class WeatherController extends GetxController{
  static get to => Get.find<WeatherController>();
  final WeatherService _weatherService = Get.find<WeatherService>();

  @override
  void onInit() {
    super.onInit();
  }

  double getTemperature() {
    return _weatherService.getRxWeather().value.temperature;
  }

  HeatLevel getHeatLevel() {
    return _weatherService.getRxWeather().value.heatLevel;
  }

  String? getIconCode() {
    return _weatherService.getRxWeather().value.iconCode;
  }

  String getLocation() {
    return _weatherService.getRxWeather().value.location;
  }

  bool isDefaultData() {
    return _weatherService.getRxWeather().value.weatherDescription.isEmpty || _weatherService.getRxWeather().value.weatherDescription == "알 수 없음";
  }

  Future updateWeather() async {
    await _weatherService.updateWeatherData();
  }
  
}