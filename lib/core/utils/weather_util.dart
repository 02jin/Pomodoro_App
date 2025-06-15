import 'package:pomodoro_timer/app/weather/constants/weather_constant.dart';

class WeatherUtil {

  // 체감온도 반환하는 함수수
  static double calculateHeatIndex(double temp, double humidity) {
    double fahrenheit = temp * 9/5 + 32;
    
    double hi = 0.5 * (fahrenheit + 61.0 + ((fahrenheit - 68.0) * 1.2) + (humidity * 0.094));
    
    if (hi >= 80) {
      hi = -42.379 +
            2.04901523 * fahrenheit +
            10.14333127 * humidity -
            0.22475541 * fahrenheit * humidity -
            0.00683783 * fahrenheit * fahrenheit -
            0.05481717 * humidity * humidity +
            0.00122874 * fahrenheit * fahrenheit * humidity +
            0.00085282 * fahrenheit * humidity * humidity -
            0.00000199 * fahrenheit * fahrenheit * humidity * humidity;
    }
    return (hi - 32) * 5/9;
  }

  // 더위 레벨 결정하는 함수
  static HeatLevel determineHeatLevel(double heatIndex) {
    if (heatIndex < 27) {
      return HeatLevel.normal;
    } else if (heatIndex < 31) {
      return HeatLevel.caution;
    } else {
      return HeatLevel.warning;
    }
  }
}