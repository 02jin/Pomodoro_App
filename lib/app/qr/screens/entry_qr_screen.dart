import 'dart:math';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:pomodoro_timer/app/qr/controllers/entry_qr_controller.dart';
import 'package:pomodoro_timer/app/timer/constants/pomodoro_stage.dart';
import 'package:pomodoro_timer/app/timer/constants/timer_stage.dart';
import 'package:pomodoro_timer/app/timer/controllers/timer_controller.dart';
import 'package:pomodoro_timer/app/timer/widgets/timer_button.dart';
import 'package:pomodoro_timer/core/routes/routes.dart';
import 'package:pomodoro_timer/app/weather/services/weather_service.dart';
class EntryQrScreen extends StatelessWidget {
  EntryQrScreen({super.key});
  final EntryQrController entryQrController = EntryQrController.to;
  final TimerController timerController = TimerController.to;
  @override
  Widget build(BuildContext context) {

  
  final double width = MediaQuery.of(context).size.width;
  final double height = MediaQuery.of(context).size.height;
    return Scaffold(
      appBar: AppBar(
        title: const Text("Scan QR Code"),
        centerTitle: true,
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(height: 64),
          Center(
            child: Material(
              elevation: 8,
              shape: BeveledRectangleBorder(
                borderRadius: BorderRadius.circular(8)
              ),
              child: Container(
                width: min<double>(width * 0.8, 360),
                height: min<double>(width * 0.8, 360),
                decoration: BoxDecoration(
                  border: Border.all(
                    color: Color(0xFF00C3FF),
                    width: 3,
                  ),
                  borderRadius: BorderRadius.circular(8)
                ),
                child: MobileScanner(
                  fit: BoxFit.fill,
                  onDetect: (result) {
                    if(result.barcodes.first.rawValue == null) {
                      debugPrint("No barcode found");
                      return;
                    } else if (result.barcodes.first.rawValue == "8808244201014"){
                      Get.offAllNamed(Routes.timer.path);
                      timerController.setIsDrinking(true);
                      if(timerController.getleftSecond() == 0) {
                        timerController.setPomodoroStage(PomodoroStage.normal);
                        timerController.setTimerStage(TimerStage.idle);
                      }
                    }
                    entryQrController.setData(result.barcodes.first.rawValue!);
                  },
                )
              ),
            ),
          ),
          Obx(() {
            return Text(entryQrController.getData());
          }),
          const Text(
            "생수병에 붙은 라벨을 스캔해주세요!",
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600
            )
          ),
          // TimerButton(onPressed: (){
          //   Get.offAllNamed("/timer");
          //   timerController.setIsDrinking(true);
          //   if(timerController.getleftSecond() == 0) {
          //     timerController.setPomodoroStage(PomodoroStage.normal);
          //     timerController.setTimerStage(TimerStage.idle);
          //   }
          // }, text: "강제이동", variant: ButtonVariant.accept)
        ]
      )
    );
  }
}