import 'dart:async';

import '../game/models/power_up_type.dart';
import 'challenge_engine.dart';
import 'challenge_generator.dart';
import 'challenge_store.dart';
import 'daily_challenge.dart';
import 'seed_util.dart';

typedef RewardGranter = Future<void> Function(
  PowerUpType type,
  int amount,
);

class DailyChallengeController {
  DailyChallengeController({
    required RewardGranter rewardGranter,
    DateTime? dateOverrideUtc,
    OnChallengeUpdate? onProgress,
    void Function(ChallengeProgress progress)? onCompleted,
    ChallengeGenerator generator = const ChallengeGenerator(),
    ChallengeStore store = const ChallengeStore(),
  })  : _rewardGranter = rewardGranter,
        _externalProgress = onProgress,
        _onCompleted = onCompleted,
        _generator = generator,
        _store = store {
    final targetDate = normalizeUtcMidnight(
      (dateOverrideUtc ?? todayUtcMidnight()).toUtc(),
    );
    _challenge = _generator.forDate(targetDate);
    _engine = ChallengeEngine(
      _challenge,
      onUpdate: _handleProgress,
    );
    _ready = _loadStatus();
  }

  final RewardGranter _rewardGranter;
  final OnChallengeUpdate? _externalProgress;
  final void Function(ChallengeProgress progress)? _onCompleted;
  final ChallengeGenerator _generator;
  final ChallengeStore _store;

  late final DailyChallenge _challenge;
  late final ChallengeEngine _engine;
  late final Future<void> _ready;

  bool _claimed = false;

  DailyChallenge get challenge => _challenge;
  ChallengeEngine get engine => _engine;
  ChallengeProgress get progress => _engine.progress;
  Future<void> get ready => _ready;
  bool get claimed => _claimed;

  Future<void> _loadStatus() async {
    _claimed = await _store.isClaimed(_challenge);
  }

  void _handleProgress(ChallengeProgress progress) {
    _externalProgress?.call(progress);
    if (progress.completed && !_claimed) {
      _onCompleted?.call(progress);
    }
  }

  Future<void> claimIfCompleted() async {
    await _ready;
    if (!progress.completed || _claimed) return;
    await _rewardGranter(_challenge.rewardType, _challenge.rewardAmount);
    await _store.setClaimed(_challenge);
    _claimed = true;
  }

  void onScoreChanged(int score) {
    _engine.onEvent(EScoreChanged(score));
  }

  void onLineCleared(int lines, {bool containsHighlightColor = false}) {
    engine.onEvent(
      ELineCleared(
        lines,
        containsHighlightColor: containsHighlightColor,
        highlightLines: containsHighlightColor ? lines : 0,
      ),
    );
  }

  void onTurnAdvanced({required bool clearedThisTurn}) {
    _engine.onEvent(ETurnAdvanced(clearedThisTurn: clearedThisTurn));
  }

  void onPiecePlaced() {
    _engine.onEvent(EPiecePlaced());
  }

  void onRotationUsed() {
    _engine.onEvent(ERotationUsed());
  }

  void onGameOver() {
    _engine.onEvent(EGameOver());
  }
}
