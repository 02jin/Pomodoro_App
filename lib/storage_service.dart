import 'package:shared_preferences/shared_preferences.dart';

class StorageService {
  static const String _todayCompletedCyclesKey = 'today_completed_cycles';
  static const String _lastSavedDateKey = 'last_saved_date';
  static const String _totalCompletedCyclesKey = 'total_completed_cycles';
  static const String _workMinutesKey = 'work_minutes';
  static const String _breakMinutesKey = 'break_minutes';

  static Future<SharedPreferences> _getPrefs() async {
    return await SharedPreferences.getInstance();
  }

  static String _getTodayString() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  static Future<void> saveTodayCompletedCycles(int cycles) async {
    final prefs = await _getPrefs();
    final today = _getTodayString();
    
    await prefs.setInt(_todayCompletedCyclesKey, cycles);
    await prefs.setString(_lastSavedDateKey, today);
  }

  static Future<int> getTodayCompletedCycles() async {
    final prefs = await _getPrefs();
    final today = _getTodayString();
    final lastSavedDate = prefs.getString(_lastSavedDateKey) ?? '';
    
    if (lastSavedDate != today) {
      await saveTodayCompletedCycles(0);
      return 0;
    }
    
    return prefs.getInt(_todayCompletedCyclesKey) ?? 0;
  }

  static Future<void> saveTotalCompletedCycles(int cycles) async {
    final prefs = await _getPrefs();
    await prefs.setInt(_totalCompletedCyclesKey, cycles);
  }

  static Future<int> getTotalCompletedCycles() async {
    final prefs = await _getPrefs();
    return prefs.getInt(_totalCompletedCyclesKey) ?? 0;
  }

  static Future<void> saveWorkMinutes(int minutes) async {
    final prefs = await _getPrefs();
    await prefs.setInt(_workMinutesKey, minutes);
  }

  static Future<int> getWorkMinutes() async {
    final prefs = await _getPrefs();
    return prefs.getInt(_workMinutesKey) ?? 90; // 기본값 90분
  }

  static Future<void> saveBreakMinutes(int minutes) async {
    final prefs = await _getPrefs();
    await prefs.setInt(_breakMinutesKey, minutes);
  }

  static Future<int> getBreakMinutes() async {
    final prefs = await _getPrefs();
    return prefs.getInt(_breakMinutesKey) ?? 10; // 기본값 10분
  }

  static Future<void> clearAllData() async {
    final prefs = await _getPrefs();
    await prefs.clear();
  }
}