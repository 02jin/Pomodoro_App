import 'package:get/get.dart';
import 'package:pomodoro_timer/app/qr/services/entry_qr_service.dart';

class EntryQrController extends GetxController {
  static EntryQrController get to => Get.find<EntryQrController>();
  final EntryQrService _entryQrService = Get.find<EntryQrService>();

  String getData() {
    return _entryQrService.getData();
  }

  void setData(String value) {
    _entryQrService.setData(value);
  }
  
}