import 'package:get/get.dart';
import 'package:pomodoro_timer/app/qr/controllers/entry_qr_controller.dart';
import 'package:pomodoro_timer/app/qr/services/entry_qr_service.dart';

class EntryQrBinding extends Bindings{
  @override
  void dependencies() {
    Get.put(EntryQrController());
  }
}