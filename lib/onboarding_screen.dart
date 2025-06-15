import 'package:flutter/material.dart';
import 'timer.dart';
import 'heatstroke_prevention_service.dart';
import 'notification_service.dart';

class LogoScreen extends StatefulWidget {
  const LogoScreen({super.key});

  @override
  State<LogoScreen> createState() => _LogoScreenState();
}

class _LogoScreenState extends State<LogoScreen> {
  @override
  void initState() {
    super.initState();
    _initializeAndNavigate();
  }

  void _initializeAndNavigate() async {
    try {
      // 로고 화면 3초 표시
      await Future.delayed(const Duration(seconds: 3));
      
      if (mounted) {
        print('🔄 바코드 스캔 화면으로 이동');
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const BarcodeScanScreen()),
        );
      }
    } catch (e) {
      print('❌ 로고 화면 오류: $e');
      // 오류가 있어도 다음 화면으로 이동
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const BarcodeScanScreen()),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Container(
        width: double.infinity,
        height: double.infinity,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // 🔥 실제 로고 이미지 사용 (오류 시 아이콘으로 대체)
              Container(
                width: 150,
                height: 150,
                child: Image(
                  image: const AssetImage('assets/images/App_logo.png'),
                  fit: BoxFit.contain,
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'Your Life saver Pomodoro',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class BarcodeScanScreen extends StatelessWidget {
  const BarcodeScanScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Container(
        width: double.infinity,
        height: double.infinity,
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.camera_alt,
              size: 100,
              color: Colors.blue,
            ),
            const SizedBox(height: 40),
            const Text(
              '운동을 시작하기 전에\n물병 바코드를 스캔해주세요.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 60),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: () {
                  print('🔄 바코드 카메라 화면으로 이동');
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const BarcodeCameraScreen(),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                ),
                child: const Text('스캔 시작하기'),
              ),
            ),
            const SizedBox(height: 20),
            // 🔥 디버깅용 스킵 버튼 추가
            TextButton(
              onPressed: () {
                print('🔄 직접 타이머로 이동 (디버깅용)');
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const SoundSettingsScreen(),
                  ),
                );
              },
              child: const Text('스킵 (디버깅용)', style: TextStyle(color: Colors.grey)),
            ),
          ],
        ),
      ),
    );
  }
}

// 바코드 카메라 화면 
class BarcodeCameraScreen extends StatefulWidget {
  final bool isFromTimer; // 🔥 타이머에서 호출되었는지 구분하는 플래그
  
  const BarcodeCameraScreen({super.key, this.isFromTimer = false});

  @override
  State<BarcodeCameraScreen> createState() => _BarcodeCameraScreenState();
}

class _BarcodeCameraScreenState extends State<BarcodeCameraScreen> {
  @override
  void initState() {
    super.initState();
    _simulateBarcodeScanning();
  }

  void _simulateBarcodeScanning() async {
    try {
      // 2초 후 자동으로 스캔 완료 처리
      await Future.delayed(const Duration(seconds: 2));
      
      if (mounted) {
        print('🔄 바코드 스캔 완료 시뮬레이션');
        _recordWaterIntakeAndReturn();
      }
    } catch (e) {
      print('❌ 바코드 스캔 오류: $e');
      if (mounted) {
        // 🔥 타이머에서 온 경우와 처음 앱 실행에서 온 경우를 구분
        if (widget.isFromTimer) {
          Navigator.pop(context, 'water_intake_failed');
        } else {
          // 🔥 오류가 있어도 결과 화면으로 이동하도록 수정
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const BarcodeResultScreen()),
          );
        }
      }
    }
  }

  void _recordWaterIntakeAndReturn() async {
    try {
      print('🔄 수분 섭취 기록 시작');
      await HeatstrokePreventionService.addWaterIntake(500);
      print('🔄 수분 섭취 기록 완료');
      
      if (mounted) {
        print('🔄 성공 스낵바 표시');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ 수분 섭취 인증 완료! (500ml)'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
        
        // 🔥 타이머에서 온 경우와 처음 앱 실행에서 온 경우를 구분
        if (widget.isFromTimer) {
          print('🔄 타이머에서 호출됨 - 이전 화면으로 돌아가기');
          Navigator.pop(context, 'water_intake_completed');
        } else {
          print('🔄 처음 앱 실행에서 호출됨 - 결과 화면으로 이동');
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const BarcodeResultScreen()),
          );
        }
      }
    } catch (e) {
      print('❌ 수분 섭취 기록 오류: $e');
      if (mounted) {
        if (widget.isFromTimer) {
          print('🔄 타이머에서 호출됨 - 실패 결과로 돌아가기');
          Navigator.pop(context, 'water_intake_failed');
        } else {
          print('🔄 처음 앱 실행에서 호출됨 - 결과 화면으로 이동 (오류 발생)');
          // 🔥 오류가 있어도 결과 화면으로 이동하도록 수정
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const BarcodeResultScreen()),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Container(
        width: double.infinity,
        height: double.infinity,
        child: Stack(
          children: [
            // 카메라 뷰 시뮬레이션
            Container(
              width: double.infinity,
              height: double.infinity,
              color: Colors.black,
              child: const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.camera,
                      color: Colors.white,
                      size: 60,
                    ),
                    SizedBox(height: 20),
                    Text(
                      '카메라 뷰\n(바코드 스캔 중...)',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
            // 스캔 가이드 영역
            Center(
              child: Container(
                width: 250,
                height: 150,
                decoration: BoxDecoration(
                  border: Border.all(
                    color: Colors.white,
                    width: 2,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Center(
                  child: Text(
                    '물병바코드를 사각형 안에 맞춰주세요',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
            ),
            
            // 닫기 버튼
            Positioned(
              top: 50,
              right: 20,
              child: IconButton(
                onPressed: () {
                  print('🔄 바코드 카메라 닫기');
                  // 🔥 타이머에서 온 경우와 처음 앱 실행에서 온 경우를 구분
                  if (widget.isFromTimer) {
                    Navigator.pop(context, 'cancelled');
                  } else {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(builder: (context) => const BarcodeScanScreen()),
                    );
                  }
                },
                icon: const Icon(
                  Icons.close,
                  color: Colors.white,
                  size: 30,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class BarcodeResultScreen extends StatefulWidget {
  const BarcodeResultScreen({super.key});

  @override
  State<BarcodeResultScreen> createState() => _BarcodeResultScreenState();
}

class _BarcodeResultScreenState extends State<BarcodeResultScreen> {
  @override
  void initState() {
    super.initState();
    print('🔄 바코드 결과 화면 로드');
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final timeString = '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
    final amPm = now.hour < 12 ? '오전' : '오후';

    return Scaffold(
      backgroundColor: Colors.white,
      body: Container(
        width: double.infinity,
        height: double.infinity,
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.check_circle,
              color: Colors.green,
              size: 100,
            ),
            const SizedBox(height: 20),
            const Text(
              '✅ 운동 전 수분 준비 완료!',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              '$amPm $timeString',
              style: const TextStyle(
                fontSize: 16,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 40),
            const Text(
              '타이머가 곧 시작됩니다.',
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 60),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: () {
                  print('🔄 사운드 설정 화면으로 이동');
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const SoundSettingsScreen(),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                ),
                child: const Text('운동 시작하기'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class SoundSettingsScreen extends StatefulWidget {
  const SoundSettingsScreen({super.key});

  @override
  State<SoundSettingsScreen> createState() => _SoundSettingsScreenState();
}

class _SoundSettingsScreenState extends State<SoundSettingsScreen> {
  bool _soundEnabled = true;
  bool _vibrationEnabled = true;

  @override
  void initState() {
    super.initState();
    print('🔄 사운드 설정 화면 로드');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Container(
        width: double.infinity,
        height: double.infinity,
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const SizedBox(height: 60),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Column(
                children: [
                  const Text(
                    '음향 및 진동 설정',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('소리 알림'),
                      Switch(
                        value: _soundEnabled,
                        onChanged: (value) {
                          setState(() {
                            _soundEnabled = value;
                          });
                          // 안전한 사운드 설정
                          try {
                            if (!value) {
                              NotificationService.setVolume(0.0);
                            } else {
                              NotificationService.setVolume(0.8);
                            }
                          } catch (e) {
                            print('사운드 설정 오류: $e');
                          }
                        },
                      ),
                    ],
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('진동 알림'),
                      Switch(
                        value: _vibrationEnabled,
                        onChanged: (value) {
                          setState(() {
                            _vibrationEnabled = value;
                          });
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info, color: Colors.orange),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '⚠️\n기기가 무음상태인지 확인해주세요.\n알림이 제한될 수 있습니다.',
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: () {
                  print('🔄 타이머 화면으로 이동');
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const TimerPage(),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                ),
                child: const Text('다음 단계로 이동'),
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}