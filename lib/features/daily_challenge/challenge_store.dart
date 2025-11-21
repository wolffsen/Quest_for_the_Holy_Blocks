import 'package:shared_preferences/shared_preferences.dart';

import 'daily_challenge.dart';

class ChallengeStore {
  const ChallengeStore();

  static String _keyFor(DailyChallenge challenge) =>
      'dc_${challenge.id}_claimed';

  Future<bool> isClaimed(DailyChallenge challenge) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyFor(challenge)) ?? false;
  }

  Future<void> setClaimed(DailyChallenge challenge) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyFor(challenge), true);
  }
}
