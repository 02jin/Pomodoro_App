import 'package:flutter/material.dart';
import 'package:pomodoro_timer/core/themes/color_theme.dart';

enum ButtonVariant {
  primary,
  accept,
  muted,
  destructive;
}

class TimerButton extends StatelessWidget {
  final VoidCallback onPressed;
  final String text;
  ButtonVariant variant;
  final double padding;

  TimerButton({
    super.key,
    required this.onPressed,
    required this.text,
    required this.variant,
    this.padding = 60
  });

  Color classifyVariant(ButtonVariant variant) {
    switch (variant) {
      case ButtonVariant.primary:
        return ColorTheme.primary;
      case ButtonVariant.accept:
        return ColorTheme.accept;
      case ButtonVariant.destructive:
        return ColorTheme.destructive;
      case ButtonVariant.muted:
        return ColorTheme.muted;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(padding, 0, padding, 0),
      child: SizedBox(
        width: double.infinity,
        height: 48,
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: classifyVariant(variant),
            disabledBackgroundColor: ColorTheme.muted,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            )
          ),
          onPressed: onPressed,
          child: Text(
            text,
            style: TextStyle(
              color:  Colors.white,
              fontFamily: "Pretendard",
              letterSpacing: 1,
              fontWeight: FontWeight.w600,
              fontSize: 18,
            )
          )
        )
      ),
    );
  }
}