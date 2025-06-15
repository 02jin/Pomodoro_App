import 'package:get/get.dart';
import 'package:pomodoro_timer/app/timer/controllers/timer_controller.dart';
import 'package:pomodoro_timer/app/weather/controllers/weather_controller.dart';

class TimerBinding extends Bindings {
  @override
  void dependencies() {
    // Get.put(TimerController());
    Get.put(WeatherController(), permanent: true);
  }
}