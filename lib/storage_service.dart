import 'package:shared_preferences/shared_preferences.dart';

class StorageService {
  static const String _todayCompletedCyclesKey = 'today_completed_cycles';
  static const String _lastSavedDateKey = 'last_saved_date';
  static const String _totalCompletedCyclesKey = 'total_completed_cycles';
  static const String _workMinutesKey = 'work_minutes';
  static const String _breakMinutesKey = 'break_minutes';

  // SharedPreferences 인스턴스 가져오기
  static Future<SharedPreferences> _getPrefs() async {
    return await SharedPreferences.getInstance();
  }

  // 오늘 날짜 문자열 생성 (yyyy-MM-dd 형식)
  static String _getTodayString() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  // 오늘의 완료된 사이클 수 저장
  static Future<void> saveTodayCompletedCycles(int cycles) async {
    final prefs = await _getPrefs();
    final today = _getTodayString();
    
    await prefs.setInt(_todayCompletedCyclesKey, cycles);
    await prefs.setString(_lastSavedDateKey, today);
  }

  // 오늘의 완료된 사이클 수 불러오기
  static Future<int> getTodayCompletedCycles() async {
    final prefs = await _getPrefs();
    final today = _getTodayString();
    final lastSavedDate = prefs.getString(_lastSavedDateKey) ?? '';
    
    // 날짜가 바뀌었으면 오늘의 사이클 수를 0으로 초기화
    if (lastSavedDate != today) {
      await saveTodayCompletedCycles(0);
      return 0;
    }
    
    return prefs.getInt(_todayCompletedCyclesKey) ?? 0;
  }

  // 총 완료된 사이클 수 저장
  static Future<void> saveTotalCompletedCycles(int cycles) async {
    final prefs = await _getPrefs();
    await prefs.setInt(_totalCompletedCyclesKey, cycles);
  }

  // 총 완료된 사이클 수 불러오기
  static Future<int> getTotalCompletedCycles() async {
    final prefs = await _getPrefs();
    return prefs.getInt(_totalCompletedCyclesKey) ?? 0;
  }

  // 작업 시간 설정 저장
  static Future<void> saveWorkMinutes(int minutes) async {
    final prefs = await _getPrefs();
    await prefs.setInt(_workMinutesKey, minutes);
  }

  // 작업 시간 설정 불러오기
  static Future<int> getWorkMinutes() async {
    final prefs = await _getPrefs();
    return prefs.getInt(_workMinutesKey) ?? 25; // 기본값 25분
  }

  // 휴식 시간 설정 저장
  static Future<void> saveBreakMinutes(int minutes) async {
    final prefs = await _getPrefs();
    await prefs.setInt(_breakMinutesKey, minutes);
  }

  // 휴식 시간 설정 불러오기
  static Future<int> getBreakMinutes() async {
    final prefs = await _getPrefs();
    return prefs.getInt(_breakMinutesKey) ?? 5; // 기본값 5분
  }

  // 모든 데이터 초기화 (개발/테스트용)
  static Future<void> clearAllData() async {
    final prefs = await _getPrefs();
    await prefs.clear();
  }
}