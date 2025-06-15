import 'package:pomodoro_timer/app/weather/constants/weather_constant.dart';

class WeatherModel {
  final double temperature;
  final double humidity;
  final double heatIndex;
  final HeatLevel heatLevel;
  final String location;
  final DateTime timestamp;
  final String weatherDescription;
  final String? iconCode;

  WeatherModel({
    required this.temperature,
    required this.humidity,
    required this.heatIndex,
    required this.heatLevel,
    required this.location,
    required this.timestamp,
    required this.weatherDescription,
    required this.iconCode,
  });

  @override
  String toString() {
    return 'WeatherModel{'
      'location: $location, '
      'temperature: ${temperature.toStringAsFixed(1)}°C, '
      'humidity: ${humidity.toStringAsFixed(1)}%, '
      'heatIndex: ${heatIndex.toStringAsFixed(1)}°C, '
      'heatLevel: $heatLevel, '
      'description: $weatherDescription, '
      'iconCode: $iconCode, '
      'timestamp: ${timestamp.toString().substring(0, 19)}'
      '}';
  }
}