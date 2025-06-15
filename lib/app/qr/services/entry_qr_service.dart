import 'package:get/get.dart';

class EntryQrService extends GetxService {
  RxString data = RxString("");

  String getData() {
    return data.value;
  }

  void setData(String value) {
    data.value = value;
  }
}