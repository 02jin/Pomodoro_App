import 'package:get/get.dart';
import 'package:pomodoro_timer/app/notification/bindings/notification_binding.dart';
import 'package:pomodoro_timer/app/qr/bindings/entry_qr_binding.dart';
import 'package:pomodoro_timer/app/qr/screens/entry_qr_screen.dart';
import 'package:pomodoro_timer/app/test/bindings/test_binding.dart';
import 'package:pomodoro_timer/app/test/screens/test_screen.dart';
import 'package:pomodoro_timer/app/timer/bindings/timer_binding.dart';
import 'package:pomodoro_timer/app/timer/screens/timer_screen.dart';

class Pages {
  static List<GetPage> pages = [
    GetPage(
      name: "/",
      page: () => EntryQrScreen(),
      bindings: [
        EntryQrBinding()
      ]
    ),
    GetPage(
      name: "/timer",
      page: () => TimerScreen(),
      bindings: [
        TimerBinding(),
        NotificationBinding()
      ]
    ),
    GetPage(
      name: "/test",
      page: () => TestScreen(),
      bindings: [
        TestBinding()
      ]
    )
  ];
}