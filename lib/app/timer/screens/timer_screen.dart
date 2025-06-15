import 'package:circular_countdown_timer/circular_countdown_timer.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pomodoro_timer/app/notification/controllers/notification_controller.dart';
import 'package:pomodoro_timer/app/timer/constants/pomodoro_stage.dart';
import 'package:pomodoro_timer/app/timer/constants/timer_stage.dart';
import 'package:pomodoro_timer/app/timer/controllers/timer_controller.dart';
import 'package:pomodoro_timer/app/timer/widgets/timer_button.dart';
import 'package:pomodoro_timer/app/timer/widgets/weather_info.dart';
import 'package:pomodoro_timer/app/weather/constants/weather_constant.dart';
import 'package:pomodoro_timer/app/weather/controllers/weather_controller.dart';

class TimerScreen extends StatelessWidget {
  TimerScreen({super.key}); 
  final CountDownController countDownController = CountDownController();
  final TimerController timerController = TimerController.to;
  final WeatherController weatherController = WeatherController.to;
  final NotificationController notificationController = NotificationController.to;

  @override
  Widget build(BuildContext context) {
    return Obx(() =>
      Scaffold(
        body: Container(
          // 전체 배경 그라데이션
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: timerController.backgroundColor,
            ),
          ),
          child: SafeArea(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  WeatherInfo(
                    location: weatherController.getLocation(),
                    temperature: weatherController.getTemperature(),
                    iconCode: weatherController.getIconCode(),
                  ),
                  SizedBox(height: 24),
                  Material(
                    elevation: 4,
                    shape: CircleBorder(),
                    child: CircularCountDownTimer(
                      key: ValueKey(timerController.getTargetDuration()),
                      controller: countDownController,
                      // duration: 10,
                      duration: timerController.getTargetDuration(),
                      initialDuration: 0,
                      width: 220,
                      height: 220,
                      ringColor: Colors.transparent,
                      backgroundColor: Colors.transparent,
                      fillColor: Color.fromARGB(180, 42, 107, 204),
                      strokeCap: StrokeCap.round,
                      strokeWidth: 4.0,
                      textStyle: const TextStyle(
                        fontSize: 48.0,
                        color: Colors.black,
                        fontWeight: FontWeight.bold,
                        fontFeatures: [
                          FontFeature.tabularFigures()
                        ]
                      ),
                      isReverse: true,
                      isReverseAnimation: true,
                      isTimerTextShown: true,
                      timeFormatterFunction: (_, time) {
                        int minute = time.inMinutes;
                        int second = (time.inSeconds % 60);
                        String minuteString = minute.toString();
                        String secondString = second.toString();
                            
                        if(minute < 10) {
                          minuteString = "0$minute";
                        }
                        if(second < 10) {
                          secondString = "0$second";
                        }
                        return "$minuteString:$secondString";
                      },
                      autoStart: false,
                      onStart: () {
                        debugPrint("실행");
                        // timerController.setLeftDuration(leftDuration)
                      },
                      onComplete: () {
                        debugPrint("onComplete 호출");
                        // Reset 동작으로 인한 onComplete 이벤트 필터링
                        if(timerController.timerStage == TimerStage.reset) {
                          timerController.setTimerStage(TimerStage.idle);
                          timerController.setPomodoroStage(PomodoroStage.normal);
                          return;
                        }
                        if(timerController.pomodoroStage == PomodoroStage.rest) {
                          // 휴식 카운트 완료되었을 때
                          if(timerController.isDrinking) {
                            timerController.setPomodoroStage(PomodoroStage.normal);
                            countDownController.reset();
                          } else {
                            Get.offAllNamed("/qr");
                          }
                        } else {
                          // 운동 카운트 완료되었을 때
                          timerController.setPomodoroStage(PomodoroStage.rest);
                          // 폭염경보면 15분, 이외에는 10분
                          int breakTime = timerController.getHeatLevel() == HeatLevel.caution ? 60 * 15 : 60 * 10;
                          timerController.setTargetDuration(breakTime);
                        }
                        timerController.setTimerStage(TimerStage.idle);
                      },
                      onChange: (time) {
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          List<String> timeText = time.split(":");
                          int minute = int.parse(timeText[0]);
                          int second = int.parse(timeText[1]);
                          timerController.setLeftSecond(60 * minute + second);
                          timerController.mapToBackgroundColorStage(minute);
                        });
                      },
                    ),
                  ),
                  SizedBox(height: 32),
                  Text(
                    timerController.displayTitle(),
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold
                    )
                  ),
                  SizedBox(height: 8),
                  Text(
                    timerController.displayMessage(),
                    style: TextStyle(
                      fontSize: 16,
                      height: 1.2,
                      fontWeight: FontWeight.w600,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  Spacer(),
                  if (timerController.pomodoroStage == PomodoroStage.rest && timerController.isDrinking == false) TimerButton(
                    onPressed: () {
                      Get.offAllNamed("/qr");
                    },
                    text: "수분 섭취 인증하기",
                    variant: ButtonVariant.accept,
                  ),
                  SizedBox(height: 8),
                  if (timerController.timerStage == TimerStage.start && timerController.pomodoroStage != PomodoroStage.rest) TimerButton(
                    onPressed: () {
                      timerController.setTimerStage(TimerStage.reset);
                      countDownController.reset();
                      notificationController.cancelNotification();
                    },
                    text: "초기화",
                    variant: ButtonVariant.destructive,
                  ),
                  if (timerController.timerStage == TimerStage.idle && timerController.pomodoroStage != PomodoroStage.rest) TimerButton(
                    onPressed: () {
                      int leftDuration = timerController.getleftSecond();
                      debugPrint(leftDuration.toString());
                      String nowActivity = timerController.pomodoroStage != PomodoroStage.rest ? "운동" : "휴식";
                      String message = timerController.pomodoroStage != PomodoroStage.rest ? "🍹물을 마시고 적절한 휴식을 취하세요!" : "🔥잘 쉬었나요? 우리 다시 달려볼까요?";
                      timerController.setIsDrinking(false);
                      countDownController.start();
                      timerController.setTimerStage(TimerStage.start);
                      notificationController.cancelNotification();
                      notificationController.scheduleNotification(
                        leftDuration,
                        "$nowActivity 종료",
                        message,
                      );
                    },
                    text: "시작하기",
                    variant: ButtonVariant.primary,
                  ),
                  if (timerController.timerStage == TimerStage.idle && timerController.pomodoroStage == PomodoroStage.rest && timerController.isDrinking) TimerButton(
                    onPressed: () {
                      int leftDuration = timerController.getleftSecond();
                      debugPrint(leftDuration.toString());
                      String nowActivity = timerController.pomodoroStage != PomodoroStage.rest ? "운동" : "휴식";
                      String message = timerController.pomodoroStage != PomodoroStage.rest ? "🍹물을 마시고 적절한 휴식을 취하세요!" : "🔥잘 쉬었나요? 우리 다시 달려볼까요?";
                      countDownController.start();
                      timerController.setTimerStage(TimerStage.start);
                      notificationController.cancelNotification();
                      notificationController.scheduleNotification(
                        leftDuration,
                        "$nowActivity 종료",
                        message,
                      );
                    },
                    text: "시작하기",
                    variant: ButtonVariant.primary,
                  ),
                  SizedBox(height: 16),
                  if(timerController.timerStage == TimerStage.start) TimerButton(
                    onPressed: () {
                      countDownController.pause();
                      timerController.setTimerStage(TimerStage.pause);
                      notificationController.cancelNotification();
                    },
                    text: "일시 정지",
                    variant: ButtonVariant.primary,
                  ),
                  // 이어하기
                  if(timerController.timerStage == TimerStage.pause) TimerButton(
                    onPressed: () {
                      int leftDuration = timerController.getleftSecond();
                      debugPrint(leftDuration.toString());
                      String nowActivity = timerController.pomodoroStage != PomodoroStage.rest ? "운동" : "휴식";
                      String message = timerController.pomodoroStage != PomodoroStage.rest ? "🍹물을 마시고 적절한 휴식을 취하세요!" : "🔥잘 쉬었나요? 우리 다시 달려볼까요?";
                      countDownController.resume();
                      timerController.setTimerStage(TimerStage.start);
                      notificationController.scheduleNotification(
                        leftDuration,
                        "$nowActivity 종료",
                        message,
                      );
                    },
                    text: "이어하기",
                    variant: ButtonVariant.primary,
                  ),
                  SizedBox(height: 48)
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}