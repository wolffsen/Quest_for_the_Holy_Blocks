import 'dart:math';

import '../game/models/power_up_type.dart';
import 'daily_challenge.dart';
import 'seed_util.dart';

class ChallengeGenerator {
  const ChallengeGenerator();

  static const _salt = 'HOLY_BLOCKS_V1';

  DailyChallenge forDate(DateTime dateUtc) {
    final normalized = normalizeUtcMidnight(dateUtc);
    final key =
        '${normalized.year}${normalized.month.toString().padLeft(2, '0')}${normalized.day.toString().padLeft(2, '0')}$_salt';
    final seed = fnv1a32(key);
    final rng = Random(seed);

    final difficulty = _rollDifficulty(rng.nextDouble());
    final type = _pickType(rng);
    final params = _buildParams(type, difficulty, rng);
    final rewardType = PowerUpType.values[seed % PowerUpType.values.length];
    final rewardAmount = switch (difficulty) {
      Difficulty.easy => 1,
      Difficulty.medium => 2,
      Difficulty.hard => 3,
    };

    return DailyChallenge(
      dateUtc: normalized,
      difficulty: difficulty,
      type: type,
      params: params,
      rewardType: rewardType,
      rewardAmount: rewardAmount,
    );
  }

  Difficulty _rollDifficulty(double roll) {
    if (roll < 0.25) return Difficulty.easy;
    if (roll < 0.8) return Difficulty.medium;
    return Difficulty.hard;
  }

  ChallengeType _pickType(Random rng) {
    const allowed = <ChallengeType>[
      ChallengeType.earlyBlessing,
      ChallengeType.colorOfTheDay,
      ChallengeType.perfectTen,
      ChallengeType.comboCrusade,
      ChallengeType.holyStreak,
      ChallengeType.puzzleOfPatience,
      ChallengeType.featherTouch,
      ChallengeType.tripleBlessing,
    ];
    return allowed[rng.nextInt(allowed.length)];
  }

  Map<String, int> _buildParams(
    ChallengeType type,
    Difficulty difficulty,
    Random rng,
  ) {
    return switch (type) {
      ChallengeType.earlyBlessing =>
        _earlyBlessingParams(difficulty),
      ChallengeType.colorOfTheDay =>
        _colorOfTheDayParams(difficulty, rng),
      ChallengeType.perfectTen => const {'targetLines': 10},
      ChallengeType.comboCrusade => _comboParams(difficulty),
      ChallengeType.holyStreak => _streakParams(difficulty),
      ChallengeType.puzzleOfPatience => _patienceParams(difficulty),
      ChallengeType.featherTouch => _featherTouchParams(difficulty),
      ChallengeType.tripleBlessing => const {'minLines': 3},
    };
  }

  Map<String, int> _earlyBlessingParams(Difficulty difficulty) {
    return switch (difficulty) {
      Difficulty.easy => {'score': 1200, 'movesCap': 48},
      Difficulty.medium => {'score': 1800, 'movesCap': 44},
      Difficulty.hard => {'score': 2400, 'movesCap': 40},
    };
  }

  Map<String, int> _comboParams(Difficulty difficulty) => switch (difficulty) {
        Difficulty.easy => {'minCombos': 2},
        Difficulty.medium => {'minCombos': 3},
        Difficulty.hard => {'minCombos': 4},
      };

  Map<String, int> _streakParams(Difficulty difficulty) =>
      switch (difficulty) {
        Difficulty.easy => {'streak': 3},
        Difficulty.medium => {'streak': 5},
        Difficulty.hard => {'streak': 7},
      };

  Map<String, int> _patienceParams(Difficulty difficulty) =>
      switch (difficulty) {
        Difficulty.easy => {'rounds': 18},
        Difficulty.medium => {'rounds': 24},
        Difficulty.hard => {'rounds': 30},
      };

  Map<String, int> _featherTouchParams(Difficulty difficulty) =>
      switch (difficulty) {
        Difficulty.easy => {'score': 1000},
        Difficulty.medium => {'score': 1600},
        Difficulty.hard => {'score': 2200},
      };

  Map<String, int> _colorOfTheDayParams(Difficulty difficulty, Random rng) {
    final highlightColor = rng.nextInt(5);
    final targetLines = switch (difficulty) {
      Difficulty.easy => 6,
      Difficulty.medium => 8,
      Difficulty.hard => 10,
    };
    return {
      'highlightColor': highlightColor,
      'lines': targetLines,
    };
  }
}
