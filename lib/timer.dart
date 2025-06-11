import 'package:flutter/material.dart';
import 'dart:async';
import 'storage_service.dart';
import 'notification_service.dart';
import 'background_service.dart';

// 타이머의 현재 상태를 나타내는 enum
enum TimerState {
  work,    // 작업 시간
  break_,  // 휴식 시간 (break는 Dart 예약어라서 break_로 사용)
  paused,  // 일시정지
  stopped  // 정지
}

class TimerPage extends StatefulWidget {
  const TimerPage({super.key});

  @override
  State<TimerPage> createState() => _TimerPageState();
}

class _TimerPageState extends State<TimerPage> with WidgetsBindingObserver {
  // === 타이머 상태 변수들 ===
  TimerState _currentState = TimerState.stopped;  // 현재 타이머 상태
  TimerState _previousState = TimerState.work;    // 일시정지 이전 상태 기억용
  Timer? _timer;  // Dart의 Timer 객체 (null일 수 있으므로 ?를 붙임)
  
  // === 시간 관련 변수들 ===
  int _workMinutes = 25;      // 작업 시간 (분) - 설정 가능
  int _breakMinutes = 5;      // 휴식 시간 (분) - 설정 가능
  int _currentMinutes = 25;   // 현재 표시되는 분
  int _currentSeconds = 0;    // 현재 표시되는 초
  
  // === 진행률 계산용 변수들 ===
  int _totalSeconds = 0;      // 현재 세션의 총 시간 (초)
  int _remainingSeconds = 0;  // 남은 시간 (초)
  
  // === 사이클 관리 변수들 ===
  int _completedCycles = 0;       // 완료된 작업 사이클 수
  int _todayCompletedCycles = 0;  // 오늘 완료된 사이클 수
  int _totalCompletedCycles = 0;  // 총 완료된 사이클 수
  
  // === 백그라운드 관리 변수들 ===
  bool _isBackgroundMode = false;  // 백그라운드 모드 여부

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeApp();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    // 위젯이 삭제될 때 타이머를 정리해줌 (메모리 누수 방지)
    _timer?.cancel();
    BackgroundService.stopBackgroundTimer();
    super.dispose();
  }

  // === 앱 라이프사이클 관리 ===
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    
    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
        // 앱이 백그라운드로 갈 때
        _handleAppGoingToBackground();
        break;
      case AppLifecycleState.resumed:
        // 앱이 포그라운드로 올 때
        _handleAppComingToForeground();
        break;
      default:
        break;
    }
  }

  // === 앱 초기화 ===
  Future<void> _initializeApp() async {
    // 알림 서비스 초기화
    await NotificationService.initialize();
    
    // 백그라운드 서비스 초기화
    await BackgroundService.initializeService();
    
    // 저장된 설정 및 데이터 불러오기
    await _loadSavedData();
    
    // 백그라운드 서비스 리스너 등록
    _setupBackgroundServiceListeners();
  }

  // === 저장된 데이터 불러오기 ===
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

  // === 백그라운드 서비스 리스너 설정 ===
  void _setupBackgroundServiceListeners() {
    // 시간 업데이트 리스너
    BackgroundService.listenToTimeUpdates((data) {
      if (mounted && _isBackgroundMode) {
        setState(() {
          _remainingSeconds = data['remainingSeconds'];
          _currentMinutes = data['minutes'];
          _currentSeconds = data['seconds'];
        });
      }
    });

    // 타이머 완료 리스너
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

  // === 앱이 백그라운드로 갈 때 ===
  void _handleAppGoingToBackground() {
    if (_currentState == TimerState.work || _currentState == TimerState.break_) {
      _isBackgroundMode = true;
      
      // 포그라운드 타이머 중지
      _timer?.cancel();
      
      // 백그라운드 타이머 시작
      BackgroundService.startBackgroundTimer(
        totalSeconds: _remainingSeconds,
        isWorkTime: _currentState == TimerState.work,
        sessionType: _currentState == TimerState.work ? 'work' : 'break',
      );
    }
  }

  // === 앱이 포그라운드로 올 때 ===
  void _handleAppComingToForeground() {
    if (_isBackgroundMode) {
      _isBackgroundMode = false;
      
      // 백그라운드 타이머 중지
      BackgroundService.stopBackgroundTimer();
      
      // 진행 중 알림 제거
      NotificationService.cancelOngoingNotification();
      
      // 포그라운드 타이머 재시작 (현재 상태가 진행 중이라면)
      if (_currentState == TimerState.work || _currentState == TimerState.break_) {
        _startForegroundTimer();
      }
    }
  }

  // === 작업 상태로 초기화하는 함수 ===
  void _resetToWorkState() {
    _currentMinutes = _workMinutes;
    _currentSeconds = 0;
    _totalSeconds = _workMinutes * 60;
    _remainingSeconds = _totalSeconds;
  }

  // === 휴식 상태로 설정하는 함수 ===
  void _setBreakState() {
    _currentMinutes = _breakMinutes;
    _currentSeconds = 0;
    _totalSeconds = _breakMinutes * 60;
    _remainingSeconds = _totalSeconds;
  }

  // === 진행률 계산 함수 (0.0 ~ 1.0) ===
  double _getProgress() {
    if (_totalSeconds == 0) return 0.0;
    return (_totalSeconds - _remainingSeconds) / _totalSeconds;
  }

  // === 시간을 문자열로 포맷하는 함수 ===
  String _formatTime(int minutes, int seconds) {
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  // === 타이머 시작 함수 ===
  void _startTimer() {
    setState(() {
      if (_currentState == TimerState.stopped) {
        // 처음 시작할 때는 작업 시간으로 설정
        _currentState = TimerState.work;
        _previousState = TimerState.work;
        _resetToWorkState();
      } else if (_currentState == TimerState.paused) {
        // 일시정지 상태에서는 이전 상태로 복귀
        _currentState = _previousState;
      }
    });

    _startForegroundTimer();
  }

  // === 포그라운드 타이머 시작 ===
  void _startForegroundTimer() {
    // 1초마다 실행되는 타이머 시작
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        _remainingSeconds--;
        _currentMinutes = _remainingSeconds ~/ 60;  // ~/ 는 정수 나눗셈
        _currentSeconds = _remainingSeconds % 60;

        if (_remainingSeconds <= 0) {
          // 시간이 모두 끝났을 때
          _onTimerComplete();
        }
      });
    });
  }

  // === 타이머 일시정지 함수 ===
  void _pauseTimer() {
    _timer?.cancel();
    
    // 백그라운드 타이머도 중지
    if (_isBackgroundMode) {
      BackgroundService.stopBackgroundTimer();
      NotificationService.cancelOngoingNotification();
    }
    
    setState(() {
      _previousState = _currentState;  // 현재 상태를 기억
      _currentState = TimerState.paused;
    });
  }

  // === 타이머 재설정 함수 ===
  void _resetTimer() {
    _timer?.cancel();
    
    // 백그라운드 타이머도 중지
    BackgroundService.stopBackgroundTimer();
    NotificationService.cancelOngoingNotification();
    
    setState(() {
      _currentState = TimerState.stopped;
      _resetToWorkState();
    });
  }

  // === 타이머 완료 시 호출되는 함수 ===
  void _onTimerComplete() {
    _timer?.cancel();
    
    setState(() {
      if (_currentState == TimerState.work) {
        // 작업 시간이 끝났으면 휴식 시간으로 자동 전환
        _onWorkTimerComplete();
      } else if (_currentState == TimerState.break_) {
        // 휴식 시간이 끝났으면 다음 작업 대기 상태로
        _onBreakTimerComplete();
      }
    });
  }

  // === 작업 타이머 완료 처리 ===
  void _onWorkTimerComplete() async {
    _completedCycles++;
    _todayCompletedCycles++;
    _totalCompletedCycles++;
    
    // 데이터 저장
    await StorageService.saveTodayCompletedCycles(_todayCompletedCycles);
    await StorageService.saveTotalCompletedCycles(_totalCompletedCycles);
    
    // 알림 및 진동
    await NotificationService.showWorkCompletedNotification();
    
    setState(() {
      _currentState = TimerState.break_;
      _previousState = TimerState.break_;
      _setBreakState();
    });
    
    // 완료 알림 다이얼로그
    _showCompletionDialog('work');
    
    // 휴식 시간 자동 시작
    _startForegroundTimer();
  }

  // === 휴식 타이머 완료 처리 ===
  void _onBreakTimerComplete() async {
    // 알림 및 진동
    await NotificationService.showBreakCompletedNotification();
    
    setState(() {
      _currentState = TimerState.stopped;
      _resetToWorkState();
    });
    
    // 완료 알림 다이얼로그
    _showCompletionDialog('break');
  }

  // === 완료 알림 다이얼로그 ===
  void _showCompletionDialog(String type) {
    String message;
    String title;
    
    if (type == 'work') {
      title = '작업 완료! 🎉';
      message = '${_workMinutes}분 작업이 완료되었습니다.\n${_breakMinutes}분 휴식을 시작합니다.';
    } else {
      title = '휴식 완료! 💪';
      message = '휴식이 끝났습니다.\n다음 작업을 시작할 준비가 되었나요?';
    }

    showDialog(
      context: context,
      barrierDismissible: false,  // 바깥 클릭으로 닫기 방지
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [
            if (type == 'break') // 휴식 완료 후에만 버튼 표시
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  _startTimer();  // 바로 다음 작업 시작
                },
                child: const Text('바로 시작'),
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

  // === 시간 설정 다이얼로그 ===
  void _showSettingsDialog() {
    int tempWorkMinutes = _workMinutes;
    int tempBreakMinutes = _breakMinutes;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('⚙️ 시간 설정'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 작업 시간 설정
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('작업 시간:'),
                      Row(
                        children: [
                          IconButton(
                            onPressed: tempWorkMinutes > 1 ? () {
                              setDialogState(() {
                                tempWorkMinutes--;
                              });
                            } : null,
                            icon: const Icon(Icons.remove),
                          ),
                          Text('$tempWorkMinutes분'),
                          IconButton(
                            onPressed: tempWorkMinutes < 60 ? () {
                              setDialogState(() {
                                tempWorkMinutes++;
                              });
                            } : null,
                            icon: const Icon(Icons.add),
                          ),
                        ],
                      ),
                    ],
                  ),
                  // 휴식 시간 설정
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('휴식 시간:'),
                      Row(
                        children: [
                          IconButton(
                            onPressed: tempBreakMinutes > 1 ? () {
                              setDialogState(() {
                                tempBreakMinutes--;
                              });
                            } : null,
                            icon: const Icon(Icons.remove),
                          ),
                          Text('$tempBreakMinutes분'),
                          IconButton(
                            onPressed: tempBreakMinutes < 30 ? () {
                              setDialogState(() {
                                tempBreakMinutes++;
                              });
                            } : null,
                            icon: const Icon(Icons.add),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('취소'),
                ),
                TextButton(
                  onPressed: () async {
                    setState(() {
                      _workMinutes = tempWorkMinutes;
                      _breakMinutes = tempBreakMinutes;
                      
                      // 현재 정지 상태라면 새 설정 적용
                      if (_currentState == TimerState.stopped) {
                        _resetToWorkState();
                      }
                    });
                    
                    // 설정 저장
                    await StorageService.saveWorkMinutes(tempWorkMinutes);
                    await StorageService.saveBreakMinutes(tempBreakMinutes);
                    
                    Navigator.of(context).pop();
                  },
                  child: const Text('적용'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // === 통계 다이얼로그 ===
  void _showStatsDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('📊 통계'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('오늘 완료된 사이클: $_todayCompletedCycles개'),
              const SizedBox(height: 8),
              Text('총 완료된 사이클: $_totalCompletedCycles개'),
              const SizedBox(height: 8),
              Text('오늘 작업 시간: ${_todayCompletedCycles * _workMinutes}분'),
              const SizedBox(height: 8),
              Text('총 작업 시간: ${_totalCompletedCycles * _workMinutes}분'),
              const SizedBox(height: 16),
              const Text('💡 팁: 열사병 방지를 위해 규칙적인 휴식을 취하세요!'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('확인'),
            ),
            TextButton(
              onPressed: () async {
                await StorageService.clearAllData();
                await _loadSavedData();
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('모든 데이터가 초기화되었습니다.')),
                );
              },
              child: const Text('데이터 초기화'),
            ),
          ],
        );
      },
    );
  }

  // === UI 빌드 함수 ===
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _currentState == TimerState.work 
        ? Colors.red.shade50    // 작업 시간은 따뜻한 색
        : Colors.blue.shade50,  // 휴식 시간은 시원한 색
      
      appBar: AppBar(
        title: const Text('🍅 열사병 방지 포모도로'),
        backgroundColor: _currentState == TimerState.work 
          ? Colors.red.shade100 
          : Colors.blue.shade100,
        elevation: 0,
        actions: [
          // 통계 버튼
          IconButton(
            onPressed: _showStatsDialog,
            icon: const Icon(Icons.bar_chart),
            tooltip: '통계',
          ),
          // 설정 버튼
          IconButton(
            onPressed: _currentState == TimerState.stopped ? _showSettingsDialog : null,
            icon: const Icon(Icons.settings),
            tooltip: '설정',
          ),
        ],
      ),

      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            children: [
              // === 현재 상태 표시 ===
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                decoration: BoxDecoration(
                  color: _currentState == TimerState.work 
                    ? Colors.red.shade100 
                    : Colors.blue.shade100,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  _getStateText(),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              
              const SizedBox(height: 40),
              
              // === 타이머 표시 (진행률 포함) ===
              Stack(
                alignment: Alignment.center,
                children: [
                  // 진행률 원형 표시
                  SizedBox(
                    width: 280,
                    height: 280,
                    child: CircularProgressIndicator(
                      value: _getProgress(),
                      strokeWidth: 8,
                      backgroundColor: Colors.grey.shade300,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        _currentState == TimerState.work 
                          ? Colors.red.shade400 
                          : Colors.blue.shade400,
                      ),
                    ),
                  ),
                  // 시간 표시
                  Container(
                    width: 250,
                    height: 250,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey.withValues(alpha: 0.3),
                          spreadRadius: 5,
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            _formatTime(_currentMinutes, _currentSeconds),
                            style: const TextStyle(
                              fontSize: 48,
                              fontWeight: FontWeight.bold,
                              fontFamily: 'monospace',
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '${(_getProgress() * 100).toInt()}%',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 40),
              
              // === 오늘의 진행 상황 표시 ===
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withValues(alpha: 0.2),
                      spreadRadius: 2,
                      blurRadius: 5,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Text(
                      '오늘의 진행 상황',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey.shade700,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _buildStatItem('🔥', '완료 사이클', '$_todayCompletedCycles개'),
                        _buildStatItem('⏱️', '작업 시간', '${_todayCompletedCycles * _workMinutes}분'),
                        _buildStatItem('😎', '휴식 시간', '${_todayCompletedCycles * _breakMinutes}분'),
                      ],
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 20),
              
              // === 설정 정보 표시 ===
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withValues(alpha: 0.2),
                      spreadRadius: 2,
                      blurRadius: 5,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('작업 시간:', style: TextStyle(fontWeight: FontWeight.w500)),
                        Text('$_workMinutes분'),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('휴식 시간:', style: TextStyle(fontWeight: FontWeight.w500)),
                        Text('$_breakMinutes분'),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('총 완료 사이클:', style: TextStyle(fontWeight: FontWeight.w500)),
                        Text('$_totalCompletedCycles개'),
                      ],
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 40),
              
              // === 제어 버튼들 ===
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  // 시작/일시정지 버튼
                  ElevatedButton.icon(
                    onPressed: _currentState == TimerState.stopped || _currentState == TimerState.paused
                      ? _startTimer 
                      : _pauseTimer,
                    icon: Icon(_currentState == TimerState.stopped || _currentState == TimerState.paused
                      ? Icons.play_arrow 
                      : Icons.pause),
                    label: Text(_currentState == TimerState.stopped || _currentState == TimerState.paused
                      ? '시작' 
                      : '일시정지'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    ),
                  ),
                  
                  // 리셋 버튼
                  ElevatedButton.icon(
                    onPressed: _resetTimer,
                    icon: const Icon(Icons.refresh),
                    label: const Text('리셋'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.grey,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 20),
              
              // === 백그라운드 모드 표시 ===
              if (_isBackgroundMode)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.smartphone, color: Colors.orange.shade700),
                      const SizedBox(width: 8),
                      Text(
                        '백그라운드에서 실행 중',
                        style: TextStyle(
                          color: Colors.orange.shade700,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  // === 통계 아이템 위젯 빌더 ===
  Widget _buildStatItem(String emoji, String label, String value) {
    return Column(
      children: [
        Text(
          emoji,
          style: const TextStyle(fontSize: 24),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey.shade600,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  // === 현재 상태를 텍스트로 반환하는 함수 ===
  String _getStateText() {
    switch (_currentState) {
      case TimerState.work:
        return '🔥 작업 시간';
      case TimerState.break_:
        return '😎 휴식 시간';
      case TimerState.paused:
        return '⏸️ 일시정지';
      case TimerState.stopped:
        return '⏹️ 준비 상태';
    }
  }
}