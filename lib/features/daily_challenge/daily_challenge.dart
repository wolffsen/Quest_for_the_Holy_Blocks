import '../game/models/power_up_type.dart';

enum Difficulty { easy, medium, hard }

enum ChallengeType {
  earlyBlessing,
  colorOfTheDay,
  perfectTen,
  comboCrusade,
  holyStreak,
  puzzleOfPatience,
  featherTouch,
  tripleBlessing,
}

class DailyChallenge {
  const DailyChallenge({
    required this.dateUtc,
    required this.difficulty,
    required this.type,
    required this.params,
    required this.rewardType,
    required this.rewardAmount,
  });

  final DateTime dateUtc;
  final Difficulty difficulty;
  final ChallengeType type;
  final Map<String, int> params;
  final PowerUpType rewardType;
  final int rewardAmount;

  String get id =>
      '${dateUtc.year.toString().padLeft(4, '0')}${dateUtc.month.toString().padLeft(2, '0')}${dateUtc.day.toString().padLeft(2, '0')}';

  DailyChallenge copyWith({
    DateTime? dateUtc,
    Difficulty? difficulty,
    ChallengeType? type,
    Map<String, int>? params,
    PowerUpType? rewardType,
    int? rewardAmount,
  }) {
    return DailyChallenge(
      dateUtc: dateUtc ?? this.dateUtc,
      difficulty: difficulty ?? this.difficulty,
      type: type ?? this.type,
      params: params ?? this.params,
      rewardType: rewardType ?? this.rewardType,
      rewardAmount: rewardAmount ?? this.rewardAmount,
    );
  }
}
