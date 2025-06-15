import 'package:flutter/material.dart';
import 'dart:async';
import 'storage_service.dart';
import 'notification_service.dart';
import 'background_service.dart';
import 'environment_service.dart';
import 'heatstroke_prevention_service.dart';
import 'onboarding_screen.dart';

enum TimerState {
  work,
  break_,
  paused,
  stopped
}

class TimerPage extends StatefulWidget {
  const TimerPage({super.key});

  @override
  State<TimerPage> createState() => _TimerPageState();
}

class _TimerPageState extends State<TimerPage> with WidgetsBindingObserver {
  TimerState _currentState = TimerState.stopped;
  TimerState _previousState = TimerState.work;
  Timer? _timer;
  
  int _workMinutes = 90;
  int _breakMinutes = 10;
  int _currentMinutes = 90;
  int _currentSeconds = 0;
  
  int _totalSeconds = 0;
  int _remainingSeconds = 0;
  
  int _todayCompletedCycles = 0;
  int _totalCompletedCycles = 0;
  
  bool _isBackgroundMode = false;
  
  EnvironmentData? _currentEnvironmentData;
  String _lastAlert = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeApp();
    
    // 🔥 수분 섭취 상태 변화를 주기적으로 체크
    Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted && _currentState == TimerState.break_) {
        setState(() {
          // UI 주기적 업데이트로 수분 섭취 상태 반영
        });
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    BackgroundService.stopBackgroundTimer();
    EnvironmentService.dispose();
    HeatstrokePreventionService.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    
    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
        _handleAppGoingToBackground();
        break;
      case AppLifecycleState.resumed:
        _handleAppComingToForeground();
        break;
      default:
        break;
    }
  }

// timer.dart의 _initializeApp() 메서드를 이렇게 수정하세요

Future<void> _initializeApp() async {
  try {
    print('타이머 페이지 초기화 시작');
    
    print('환경 서비스 초기화 중...');
    await EnvironmentService.initialize().timeout(
      const Duration(seconds: 5),
      onTimeout: () {
        print('환경 서비스 초기화 타임아웃 - 기본값 사용');
      },
    );

    print('열사병 방지 서비스 초기화 중...');
    await HeatstrokePreventionService.initialize().timeout(
      const Duration(seconds: 3),
      onTimeout: () {
        print('열사병 방지 서비스 초기화 타임아웃');
      },
    );
    
    print('저장된 데이터 로드 중...');
    await _loadSavedData();

    print('백그라운드 서비스 리스너 설정 중...');
    _setupBackgroundServiceListeners();

    print('환경 리스너 설정 중...');
    _setupEnvironmentListeners();
    
    print('타이머 페이지 초기화 완료');
    
  } catch (e) {
    print('타이머 페이지 초기화 오류: $e');
    // 오류가 있어도 기본 설정으로 계속 진행
    await _loadSavedData();
    _setupBackgroundServiceListeners();
  }
}

  void _setupEnvironmentListeners() {
    EnvironmentService.environmentDataStream.listen((data) {
      if (mounted) {
        setState(() {
          _currentEnvironmentData = data;
        });
        
        if (_currentState == TimerState.stopped) {
          _applyEnvironmentBasedTimeAdjustment(data);
        }
        
        _checkForceBreak(data);
      }
    });

    HeatstrokePreventionService.alertStream.listen((alert) {
      setState(() {
        _lastAlert = alert;
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(alert),
            duration: const Duration(seconds: 4),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    });
  }

  void _applyEnvironmentBasedTimeAdjustment(EnvironmentData data) {
    final recommendedWork = data.getRecommendedWorkMinutes();
    final recommendedBreak = data.getRecommendedBreakMinutes();
    
    setState(() {
      _workMinutes = recommendedWork;
      _breakMinutes = recommendedBreak;
      _resetToWorkState();
    });
  }

  void _checkForceBreak(EnvironmentData data) {
    if (data.heatLevel == HeatLevel.warning && 
        (_currentState == TimerState.work || _currentState == TimerState.stopped)) {
      
      if (_currentState == TimerState.work) {
        _pauseTimer();
      }
      
      _showForceBreakDialog();
    }
  }

  void _showForceBreakDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('🚨 긴급 안전 알림'),
          content: Text(HeatstrokePreventionService.getForceBreakMessage()),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _startBreakTimer();
              },
              child: const Text('휴식하러 가기'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _loadSavedData() async {
    final workMinutes = await StorageService.getWorkMinutes();
    final breakMinutes = await StorageService.getBreakMinutes();
    final todayCompleted = await StorageService.getTodayCompletedCycles();
    final totalCompleted = await StorageService.getTotalCompletedCycles();

    setState(() {
      _workMinutes = workMinutes;
      _breakMinutes = breakMinutes;
      _todayCompletedCycles = todayCompleted;
      _totalCompletedCycles = totalCompleted;
      _resetToWorkState();
    });
  }

  void _setupBackgroundServiceListeners() {
    BackgroundService.listenToTimeUpdates((data) {
      if (mounted && _isBackgroundMode) {
        setState(() {
          _remainingSeconds = data['remainingSeconds'];
          _currentMinutes = data['minutes'];
          _currentSeconds = data['seconds'];
        });
      }
    });

    BackgroundService.listenToTimerCompletion((type) {
      if (mounted) {
        if (type == 'work') {
          _onWorkTimerComplete();
        } else if (type == 'break') {
          _onBreakTimerComplete();
        }
      }
    });
  }

  void _handleAppGoingToBackground() {
    if (_currentState == TimerState.work || _currentState == TimerState.break_) {
      _isBackgroundMode = true;
      
      _timer?.cancel();
      
      BackgroundService.startBackgroundTimer(
        totalSeconds: _remainingSeconds,
        isWorkTime: _currentState == TimerState.work,
        sessionType: _currentState == TimerState.work ? 'work' : 'break',
      );
    }
  }

  void _handleAppComingToForeground() {
    if (_isBackgroundMode) {
      _isBackgroundMode = false;
      
      BackgroundService.stopBackgroundTimer();
      NotificationService.cancelOngoingNotification();
      
      if (_currentState == TimerState.work || _currentState == TimerState.break_) {
        _startForegroundTimer();
      }
    }
  }

  void _resetToWorkState() {
    _currentMinutes = _workMinutes;
    _currentSeconds = 0;
    _totalSeconds = _workMinutes * 60;
    _remainingSeconds = _totalSeconds;
  }

  void _setBreakState() {
    _currentMinutes = _breakMinutes;
    _currentSeconds = 0;
    _totalSeconds = _breakMinutes * 60;
    _remainingSeconds = _totalSeconds;
  }

  double _getProgress() {
    if (_totalSeconds == 0) return 0.0;
    return (_totalSeconds - _remainingSeconds) / _totalSeconds;
  }

  String _formatTime(int minutes, int seconds) {
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  void _startTimer() {
    // 🔥 기존 타이머 먼저 정리
    _timer?.cancel();
    
    setState(() {
      if (_currentState == TimerState.stopped) {
        _currentState = TimerState.work;
        _previousState = TimerState.work;
        _resetToWorkState();
      } else if (_currentState == TimerState.paused) {
        _currentState = _previousState;
      }
    });

    _startForegroundTimer();
  }

  void _startBreakTimer() {
    // 🔥 기존 타이머 먼저 정리 - 이게 핵심 수정사항!
    _timer?.cancel();
    
    setState(() {
      _currentState = TimerState.break_;
      _previousState = TimerState.break_;
      _setBreakState();
    });

    _startForegroundTimer();
  }

  void _startForegroundTimer() {
    // 🔥 안전장치: 기존 타이머가 있으면 취소
    _timer?.cancel();
    
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted && (_currentState == TimerState.work || _currentState == TimerState.break_)) {
        setState(() {
          _remainingSeconds--;
          _currentMinutes = _remainingSeconds ~/ 60;
          _currentSeconds = _remainingSeconds % 60;

          if (_remainingSeconds <= 0) {
            _onTimerComplete();
          }
        });
      }
    });
  }

  void _pauseTimer() {
    // 🔥 확실하게 타이머 정지
    _timer?.cancel();
    _timer = null;
    
    if (_isBackgroundMode) {
      BackgroundService.stopBackgroundTimer();
      NotificationService.cancelOngoingNotification();
    }
    
    setState(() {
      _previousState = _currentState;
      _currentState = TimerState.paused;
    });
  }

  void _resetTimer() {
    _timer?.cancel();
    _timer = null;
    
    BackgroundService.stopBackgroundTimer();
    NotificationService.cancelOngoingNotification();
    
    setState(() {
      _currentState = TimerState.stopped;
      _isBackgroundMode = false;
      _resetToWorkState();
    });
    
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (context) => const LogoScreen()),
      (route) => false,
    );
  }

  void _onTimerComplete() {
    _timer?.cancel();
    _timer = null;
    
    setState(() {
      if (_currentState == TimerState.work) {
        _onWorkTimerComplete();
      } else if (_currentState == TimerState.break_) {
        _onBreakTimerComplete();
      }
    });
  }

  void _onWorkTimerComplete() async {
    _todayCompletedCycles++;
    _totalCompletedCycles++;
    
    await StorageService.saveTodayCompletedCycles(_todayCompletedCycles);
    await StorageService.saveTotalCompletedCycles(_totalCompletedCycles);
    
    await NotificationService.showWorkCompletedNotification();
    
    setState(() {
      _currentState = TimerState.break_;
      _previousState = TimerState.break_;
      _setBreakState();
    });
    
    _showCompletionDialog('work');
    _startForegroundTimer();
  }

  void _onBreakTimerComplete() async {
    await NotificationService.showBreakCompletedNotification();
    
    setState(() {
      _currentState = TimerState.stopped;
      _resetToWorkState();
    });
    
    _showCompletionDialog('break');
  }

  void _showCompletionDialog(String type) {
    String message;
    String title;
    
    if (type == 'work') {
      title = '🎉 운동 완료!';
      message = '${_workMinutes}분 운동이 완료되었습니다.\n${_breakMinutes}분 휴식을 시작합니다.';
    } else {
      title = '💪 휴식 완료!';
      message = '휴식이 끝났습니다.\n다음 운동을 시작할 준비가 되었나요?';
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [
            if (type == 'break')
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  _startTimer();
                },
                child: const Text('운동 시작하기'),
              ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text(type == 'work' ? '확인' : '나중에'),
            ),
          ],
        );
      },
    );
  }

void _showWaterIntakeDialog() {
  final suggestions = HeatstrokePreventionService.getWaterIntakeSuggestions();
  
  showDialog(
    context: context,
    builder: (BuildContext context) {
      return AlertDialog(
        title: const Text('수분 섭취 인증하기'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                '지금은 휴식시간입니다.\n물 한잔 마셔볼까요?\n아래 버튼을 눌러 인증해주세요.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () async {
                    Navigator.of(context).pop(); // 다이얼로그 닫기

                    // 🔥 여기가 핵심 수정사항! isFromTimer: true 추가
                    final result = await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const BarcodeCameraScreen(isFromTimer: true),
                      ),
                    );

                    if (result == 'water_intake_completed') {
                      setState(() {
                      });
                      
                      // 추가 성공 메시지
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('🎉 바코드 스캔으로 수분 섭취 인증 완료!'),
                            backgroundColor: Colors.green,
                            duration: Duration(seconds: 3),
                          ),
                        );
                      }
                    } else if (result == 'water_intake_failed') {
                      // 실패 시 메시지
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('❌ 수분 섭취 인증에 실패했습니다.'),
                            backgroundColor: Colors.red,
                            duration: Duration(seconds: 2),
                          ),
                        );
                      }
                    }
                    // cancelled의 경우 아무것도 하지 않음 (그냥 휴식 타이머 계속)
                  },
                  child: const Text('스캔 시작하기'),
                ),
              ),
              const SizedBox(height: 16),
              const Text('또는 직접 입력:'),
              const SizedBox(height: 8),
              // 🔥 버튼들을 세로로 배치하여 오버플로우 방지
              Column(
                children: suggestions.map((amount) {
                  return Container(
                    width: double.infinity,
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ElevatedButton(
                      onPressed: () {
                        HeatstrokePreventionService.addWaterIntake(amount);
                        Navigator.of(context).pop();
                        setState(() {});
                      },
                      child: Text('${amount}ml'),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('취소'),
          ),
        ],
      );
    },
  );
}
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              children: [
                // 환경 정보 카드
                if (_currentEnvironmentData != null)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    margin: const EdgeInsets.only(bottom: 20),
                    child: Column(
                      children: [
                        Text(
                          _currentEnvironmentData!.getHeatLevelText(),
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          _currentEnvironmentData!.getHeatLevelDescription(),
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 14),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          _currentEnvironmentData!.getAdviceMessage(),
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 12),
                        ),
                      ],
                    ),
                  ),

                const SizedBox(height: 40),
                
                // 타이머 원형 디스플레이
                Container(
                  width: 280,
                  height: 280,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white,
                  ),
                  child: Center(
                    child: Text(
                      _formatTime(_currentMinutes, _currentSeconds),
                      style: const TextStyle(
                        fontSize: 48,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ),
                ),
                
                const SizedBox(height: 40),

                // 상태별 버튼들
                if (_currentState == TimerState.stopped) ...[
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _startTimer,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.black,
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('운동 시작하기'),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _resetTimer,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.grey,
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('처음으로'),
                    ),
                  ),
                ] else if (_currentState == TimerState.work) ...[
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _startBreakTimer,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.black,
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('지금 쉬기'),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _pauseTimer,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange,
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('일시 정지'),
                    ),
                  ),
                ] else if (_currentState == TimerState.break_) ...[
                  if (HeatstrokePreventionService.getWaterIntakeProgress() < 0.8) ...[
                    Text(
                      HeatstrokePreventionService.getHealthStatusMessage(),
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 16),
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: _showWaterIntakeDialog,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          foregroundColor: Colors.white,
                        ),
                        child: const Text('수분 섭취 인증하기'),
                      ),
                    ),
                  ] else ...[
                    const Text(
                      '✅ 수분 섭취 인증 완료!\n참 잘했어요! 물을 마신 게 확인됐어요.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 16),
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: _startTimer,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                        ),
                        child: const Text('운동 시작하기'),
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _pauseTimer, // 🔥 휴식 중에도 일시정지 가능
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange,
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('일시 정지'),
                    ),
                  ),
                ] else if (_currentState == TimerState.paused) ...[
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _startTimer,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.black,
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('다시 시작'),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _resetTimer,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('완전 정지'),
                    ),
                  ),
                ],
                
                const SizedBox(height: 40),
                
                // 알림 메시지
                if (_lastAlert.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.all(12),
                    child: Text(
                      _lastAlert,
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    ); 
  }
}