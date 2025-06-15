import 'package:get/get.dart';
import 'package:pomodoro_timer/app/test/controllers/test_controller.dart';
import 'package:pomodoro_timer/app/test/services/test_service.dart';
import 'package:pomodoro_timer/app/weather/controllers/weather_controller.dart';

class TestBinding extends Bindings {
  @override
  void dependencies() {
    Get.put(TestController());
    Get.put(WeatherController());
  }
}