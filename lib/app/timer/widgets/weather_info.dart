import 'package:flutter/material.dart';
import 'package:pomodoro_timer/app/weather/controllers/weather_controller.dart';

class WeatherInfo extends StatelessWidget {
  final String location;
  final double temperature;
  final String? iconCode;
  final DateTime time = DateTime.now();
  double iconWidth = 132;
  double iconHeight = 132;

  WeatherInfo({
    super.key,
    required this.location,
    required this.temperature,
    required this.iconCode
  });

  bool isDay(DateTime time) {
    int hour = time.hour;
    // 6시 이후 ~ 18시 이전이면 아침으로 판단
    return hour < 18 && hour > 6;
  }

  Widget defaultIcon(bool isDay) {
    return isDay ? 
    CircleAvatar(
      backgroundColor: Colors.blue.shade200,
      radius: 40,
      child: Image.network(
        "https://openweathermap.org/img/wn/02d@2x.png",
        width: iconWidth,
        height: iconHeight
      )
    ) :
    CircleAvatar(
      backgroundColor: Colors.blue.shade200,
      radius: 40,
      child: Image.network(
      "https://openweathermap.org/img/wn/02n@2x.png",
        width: iconWidth,
        height: iconHeight
      )
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsetsGeometry.all(16),
      child: Column(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              spacing: 12,
              children: [
                iconCode == null ? defaultIcon(isDay(time)) :
                CircleAvatar(
                  backgroundColor: Colors.blue.shade200,
                  radius: 40,
                  child: Image.network(
                  "https://openweathermap.org/img/wn/$iconCode@2x.png",
                    width: iconWidth,
                    height: iconHeight
                  )
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          temperature.toString(),
                          style: TextStyle(
                            fontSize: 48,
                            fontWeight: FontWeight.bold,
                            height: 1
                          )
                        ),
                        Text(
                          "°C",
                          style: TextStyle(
                            fontSize: 24,
                            height: 1,
                            fontWeight: FontWeight.w600
                          )
                        )
                      ],
                    ),
                    Text(
                      location,
                      style: TextStyle(
                        fontWeight: FontWeight.w600
                      )
                    ),
                  ]
                )
              ],
            ),
          ],
        ),
    );
  }
}