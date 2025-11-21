import 'dart:math' as math;

import 'daily_challenge.dart';

sealed class GameEvent {}

class EScoreChanged extends GameEvent {
  EScoreChanged(this.score);
  final int score;
}

class ELineCleared extends GameEvent {
  ELineCleared(
    this.linesSimultaneous, {
    this.containsHighlightColor = false,
    this.highlightLines = 0,
  });
  final int linesSimultaneous;
  final bool containsHighlightColor;
  final int highlightLines;
}

class ETurnAdvanced extends GameEvent {
  ETurnAdvanced({required this.clearedThisTurn});
  final bool clearedThisTurn;
}

class EPiecePlaced extends GameEvent {}

class ERotationUsed extends GameEvent {}

class EGameOver extends GameEvent {}

class ChallengeProgress {
  bool completed = false;
  int piecesPlaced = 0;
  int turnsSurvived = 0;
  int currentStreak = 0;
  int maxStreak = 0;
  int combosAchieved = 0;
  int linesClearedTotal = 0;
  int highlightColorLines = 0;
  bool usedRotation = false;
  bool tripleBlessingAchieved = false;
}

typedef OnChallengeUpdate = void Function(ChallengeProgress progress);

class ChallengeEngine {
  ChallengeEngine(this.challenge, {this.onUpdate});

  final DailyChallenge challenge;
  final OnChallengeUpdate? onUpdate;

  final ChallengeProgress _progress = ChallengeProgress();
  int _score = 0;

  ChallengeProgress get progress => _progress;

  void onEvent(GameEvent event) {
    if (_progress.completed) return;

    switch (event) {
      case EScoreChanged(:final score):
        _score = score;
      case ELineCleared(
        :final linesSimultaneous,
        :final containsHighlightColor,
        :final highlightLines,
      ):
        _progress.linesClearedTotal += linesSimultaneous;
        if (linesSimultaneous >= 2) {
          _progress.combosAchieved++;
        }
        if (challenge.type == ChallengeType.tripleBlessing &&
            linesSimultaneous >= (challenge.params['minLines'] ?? 3)) {
          _progress.tripleBlessingAchieved = true;
        }
        if (highlightLines > 0) {
          _progress.highlightColorLines += highlightLines;
        } else if (containsHighlightColor) {
          _progress.highlightColorLines += linesSimultaneous;
        }
        _progress.currentStreak++;
        _progress.maxStreak =
            math.max(_progress.maxStreak, _progress.currentStreak);
      case ETurnAdvanced(:final clearedThisTurn):
        _progress.turnsSurvived++;
        if (!clearedThisTurn) {
          _progress.currentStreak = 0;
        }
      case EPiecePlaced():
        _progress.piecesPlaced++;
      case ERotationUsed():
        _progress.usedRotation = true;
      case EGameOver():
        // No-op; evaluation still happens below.
    }

    _progress.completed = _evaluate();
    onUpdate?.call(_progress);
  }

  bool _evaluate() {
    final params = challenge.params;
    final p = _progress;

    switch (challenge.type) {
      case ChallengeType.earlyBlessing:
        final scoreTarget = params['score'] ?? 0;
        final movesCap = params['movesCap'] ?? 0;
        if (p.piecesPlaced > movesCap && _score < scoreTarget) return false;
        return _score >= scoreTarget && p.piecesPlaced <= movesCap;
      case ChallengeType.colorOfTheDay:
        final targetLines = params['lines'] ?? 0;
        return p.highlightColorLines >= targetLines;
      case ChallengeType.perfectTen:
        final targetLines = params['targetLines'] ?? 10;
        return p.linesClearedTotal >= targetLines;
      case ChallengeType.comboCrusade:
        final minCombos = params['minCombos'] ?? 0;
        return p.combosAchieved >= minCombos;
      case ChallengeType.holyStreak:
        final streak = params['streak'] ?? 0;
        return p.maxStreak >= streak;
      case ChallengeType.puzzleOfPatience:
        final rounds = params['rounds'] ?? 0;
        return p.turnsSurvived >= rounds;
      case ChallengeType.featherTouch:
        final scoreTarget = params['score'] ?? 0;
        return !p.usedRotation && _score >= scoreTarget;
      case ChallengeType.tripleBlessing:
        return p.tripleBlessingAchieved;
    }
  }
}
