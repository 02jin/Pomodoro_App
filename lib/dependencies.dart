import 'package:get/get.dart';
import 'package:pomodoro_timer/app/notification/controllers/notification_controller.dart';
import 'package:pomodoro_timer/app/qr/services/entry_qr_service.dart';
import 'package:pomodoro_timer/app/test/services/test_service.dart';
import 'package:pomodoro_timer/app/timer/controllers/timer_controller.dart';
import 'package:pomodoro_timer/app/timer/services/timer_service.dart';
import 'package:pomodoro_timer/app/weather/services/weather_service.dart';

class Dependencies {
  static void init() {
    Get.put(EntryQrService());
    Get.put(WeatherService(), permanent: true);
    Get.put(TimerService(), permanent: true);
    Get.put(TestService(), permanent: true);
    Get.put(NotificationController(), permanent: true);
    Get.put(TimerController(), permanent: true);
  }
}