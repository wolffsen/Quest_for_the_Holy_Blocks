import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/random/xorshift.dart';
import '../data/block_shapes.dart';
import '../data/daily_challenge_repository.dart';
import '../models/block_piece.dart';
import '../models/game_state.dart';
import '../models/game_theme.dart';
import '../models/power_up_type.dart';
import '../../../core/ads/ad_service.dart';
import '../../../core/ads/ad_unit_ids.dart';
import '../../daily_challenge/challenge_generator.dart';
import '../../daily_challenge/daily_challenge.dart';
import '../../daily_challenge/challenge_engine.dart';

const _maxUndoSnapshots = 10;
const _pointsPerFilledCell = 10;
const _prefsUndoKey = 'powerups_undo';
const _prefsSkipKey = 'powerups_skip';
const _prefsHintKey = 'powerups_hint';
const _prefsGameStateKey = 'persisted_game_state';
const _allowedDifficulties = {'easy', 'medium', 'hard'};
const _gameOverBonusPoints = 500;
const _legacyDefaultThemeIds = {'neon_glow'};
const _prefsHolyCircusMigrated = 'holy_circus_theme_migrated';

class _BatchResult {
  final List<BlockPiece> pieces;
  final int rngState;
  const _BatchResult(this.pieces, this.rngState);
}

class _ClearResult {
  final int linesCleared;
  final int highlightLines;
  const _ClearResult(this.linesCleared, this.highlightLines);
}

class _TrayResult {
  final List<BlockPiece> pieces;
  final int rngState;
  final int batchCounter;
  const _TrayResult(this.pieces, this.rngState, this.batchCounter);
}

final gameControllerProvider =
    StateNotifierProvider<GameController, GameState>((ref) {
  final challenges = ref.read(dailyChallengeRepositoryProvider);
  final ads = ref.read(adServiceProvider);
  final controller = GameController(challenges, ads);
  controller.bootstrap();
  return controller;
});

class GameController extends StateNotifier<GameState> {
  GameController(this._challenges, this._ads)
      : _challengeGenerator = const ChallengeGenerator(),
        _blockColorPalette = _buildBlockColorPalette(),
        super(GameState.initial());

  final DailyChallengeRepository _challenges;
  final AdService _ads;
  final ChallengeGenerator _challengeGenerator;
  final List<int> _blockColorPalette;
  DailyChallenge? _activeChallenge;
  ChallengeEngine? _challengeEngine;
  int _pieceSerial = 0;

  Future<void> bootstrap() async {
    unawaited(_ads.initialize());
    final seed = _dailySeed();
    final base = GameState.initial(
      seed: seed,
      rotationEnabled: state.rotationEnabled,
      themeId: state.themeId,
      soundEnabled: state.soundEnabled,
      hapticsEnabled: state.hapticsEnabled,
      musicEnabled: state.musicEnabled,
      difficulty: state.difficulty,
    ).copyWith(
      bestScore: state.bestScore,
      undoPowerUps: state.undoPowerUps,
      skipPowerUps: state.skipPowerUps,
      hintPowerUps: state.hintPowerUps,
      totalGamesPlayed: state.totalGamesPlayed,
      totalScoreAccumulated: state.totalScoreAccumulated,
      totalLinesCleared: state.totalLinesCleared,
      bestComboStreak: state.bestComboStreak,
      unlockedAchievements: state.unlockedAchievements,
    );
    final batch = _drawBatch(seed);
    final todayId = DailyChallengeRepository.formatId(DateTime.now().toUtc());
    final todayEntry =
        await _challenges.ensureEntry(todayId, _seedForId(todayId));
    final initialState = base.copyWith(
      activePieces: batch.pieces,
      rngState: batch.rngState,
      batchCounter: 1,
      isDailyChallenge: false,
      dailyChallengeId: todayId,
      dailyChallengeSeed: todayEntry.seed,
      dailyChallengeCompleted: todayEntry.completed,
      dailyChallengeBestScore: todayEntry.bestScore,
      gameOverBonusClaimed: false,
      isPaused: false,
    );
    state = _applyStateMigrations(initialState);
    await _loadSavedGameState();
    await _loadPowerUps();
    await _syncChallengeMeta();
    _resetPieceSerial();
    unawaited(_persistState());
  }

  void startNewGame({int? seed}) {
    final startSeed = seed ?? _dailySeed();
    final base = GameState.initial(
      seed: startSeed,
      rotationEnabled: state.rotationEnabled,
      themeId: state.themeId,
      soundEnabled: state.soundEnabled,
      hapticsEnabled: state.hapticsEnabled,
      musicEnabled: state.musicEnabled,
      difficulty: state.difficulty,
    ).copyWith(
      bestScore: state.bestScore,
      undoPowerUps: state.undoPowerUps,
      skipPowerUps: state.skipPowerUps,
      hintPowerUps: state.hintPowerUps,
      isDailyChallenge: false,
      hint: null,
      gameOverBonusClaimed: false,
      isPaused: false,
      dailyChallengeTitle: null,
      dailyChallengeInstruction: null,
      dailyChallengeHighlightColor: null,
      dailyChallengeProgress: 0,
      dailyChallengeTarget: 0,
      totalGamesPlayed: state.totalGamesPlayed,
      totalScoreAccumulated: state.totalScoreAccumulated,
      totalLinesCleared: state.totalLinesCleared,
      bestComboStreak: state.bestComboStreak,
      unlockedAchievements: state.unlockedAchievements,
    );
    final batch = _drawBatch(startSeed);
    state = base.copyWith(
      activePieces: batch.pieces,
      rngState: batch.rngState,
      batchCounter: 1,
      hint: null,
      gameOverBonusClaimed: false,
      isPaused: false,
    );
    state = _applyStateMigrations(state);
    _resetPieceSerial();
    unawaited(_persistState());
    unawaited(_syncChallengeMeta());
    _activeChallenge = null;
    _challengeEngine = null;
  }

  Future<void> startDailyChallenge() async {
    final today = DateTime.now().toUtc();
    final id = DailyChallengeRepository.formatId(today);
    final entry = await _challenges.ensureEntry(id, _seedForId(id));
    final challenge = _challengeGenerator.forDate(today);
    final highlightColor = _resolveChallengeHighlightColor(challenge);
    final challengeTarget = _challengeTargetFor(challenge);
    final (title, instruction) = _describeChallenge(challenge);
    final base = GameState.initial(
      seed: entry.seed,
      rotationEnabled: state.rotationEnabled,
      themeId: state.themeId,
      soundEnabled: state.soundEnabled,
      hapticsEnabled: state.hapticsEnabled,
      musicEnabled: state.musicEnabled,
      difficulty: state.difficulty,
    ).copyWith(
      bestScore: state.bestScore,
      isDailyChallenge: true,
      dailyChallengeId: id,
      dailyChallengeSeed: entry.seed,
      dailyChallengeCompleted: entry.completed,
      dailyChallengeBestScore: entry.bestScore,
      undoPowerUps: state.undoPowerUps,
      skipPowerUps: state.skipPowerUps,
      hintPowerUps: state.hintPowerUps,
      hint: null,
      gameOverBonusClaimed: false,
      isPaused: false,
      dailyChallengeTitle: title,
      dailyChallengeInstruction: instruction,
      dailyChallengeHighlightColor: highlightColor,
      dailyChallengeProgress: 0,
      dailyChallengeTarget: challengeTarget,
      totalGamesPlayed: state.totalGamesPlayed,
      totalScoreAccumulated: state.totalScoreAccumulated,
      totalLinesCleared: state.totalLinesCleared,
      bestComboStreak: state.bestComboStreak,
      unlockedAchievements: state.unlockedAchievements,
    );
    final batch = _drawBatch(entry.seed);
    final challengeState = base.copyWith(
      activePieces: batch.pieces,
      rngState: batch.rngState,
      batchCounter: 1,
    );
    state = _applyStateMigrations(challengeState);
    _resetPieceSerial();
    unawaited(_persistState());
    unawaited(_syncChallengeMeta());
    _activeChallenge = challenge;
    _challengeEngine = ChallengeEngine(
      challenge,
      onUpdate: _handleChallengeUpdate,
    );
    _challengeEngine?.onEvent(EScoreChanged(state.score));
  }

  void placePiece(String pieceId, int targetRow, int targetCol) {
    if (state.isGameOver || state.isPaused) return;
    final wasGameOver = state.isGameOver;
    final piece = _findPiece(pieceId);
    if (piece == null) return;
    if (!_canPlace(piece, targetRow, targetCol, state.board)) return;

    final snapshot = GameSnapshot(
      board: cloneBoard(state.board),
      activePieces: state.activePieces,
      score: state.score,
      comboStreak: state.comboStreak,
      rngState: state.rngState,
      batchCounter: state.batchCounter,
    );

    final updatedHistory =
        _trimmedHistory([...state.history, snapshot]);

    final board = cloneBoard(state.board);
    for (var y = 0; y < piece.height; y++) {
      for (var x = 0; x < piece.width; x++) {
        if (piece.cells[y][x] == 1) {
          board[targetRow + y][targetCol + x] = piece.colorValue;
        }
      }
    }

    final cleared = _clearCompletedLines(
      board,
      highlightColor: state.dailyChallengeHighlightColor,
    );
    final cellPoints = _pointsForPiece(piece);
    final linePoints = _scoreForLines(cleared.linesCleared, state.comboStreak);
    final totalGain = cellPoints + linePoints;
    final nextCombo =
        cleared.linesCleared > 0 ? state.comboStreak + 1 : 0;
    final score = state.score + totalGain;
    final best = max(state.bestScore, score);
    final nextEffectId =
        cleared.linesCleared > 1 ? state.comboEffectId + 1 : state.comboEffectId;

    final remainingPieces = [
      for (final p in state.activePieces)
        if (p.id != piece.id) p,
    ];

    final tray = _maybeRefillTray(
      remainingPieces,
      board,
      state.rngState,
      state.batchCounter,
    );
    final gameOver = tray.pieces.isEmpty
        ? true
        : !_hasAnyValidMoves(board, tray.pieces);

    if (state.soundEnabled) {
      final tone =
          cleared.linesCleared > 0 ? SystemSoundType.alert : SystemSoundType.click;
      unawaited(SystemSound.play(tone));
    }
    if (state.hapticsEnabled) {
      if (cleared.linesCleared > 1) {
        HapticFeedback.heavyImpact();
      } else if (cleared.linesCleared == 1) {
        HapticFeedback.mediumImpact();
      } else {
        HapticFeedback.lightImpact();
      }
    }

    final totalLinesCleared = state.totalLinesCleared + cleared.linesCleared;
    final bestComboStreak = max(state.bestComboStreak, nextCombo);
    var totalGames = state.totalGamesPlayed;
    var totalScore = state.totalScoreAccumulated;
    if (gameOver && !wasGameOver) {
      totalGames += 1;
      totalScore += score;
    }
    final unlocked = _unlockAchievements(
      current: state.unlockedAchievements,
      score: score,
      bestCombo: bestComboStreak,
      totalLines: totalLinesCleared,
      totalGames: totalGames,
      challengeStreak: state.challengeStreak,
      dailyChallengeCompleted:
          state.dailyChallengeCompleted || (gameOver && state.isDailyChallenge),
    );

    state = state.copyWith(
      board: board,
      activePieces: tray.pieces,
      score: score,
      bestScore: best,
      comboStreak: nextCombo,
      rngState: tray.rngState,
      batchCounter: tray.batchCounter,
      history: updatedHistory,
      isGameOver: gameOver,
      lastPlacementScore: totalGain,
      lastLinesCleared: cleared.linesCleared,
      comboEffectId: nextEffectId,
      hint: null,
      totalLinesCleared: totalLinesCleared,
      bestComboStreak: bestComboStreak,
      totalGamesPlayed: totalGames,
      totalScoreAccumulated: totalScore,
      unlockedAchievements: unlocked,
    );
    _challengeEngine?.onEvent(EPiecePlaced());
    if (cleared.linesCleared > 0) {
      _challengeEngine?.onEvent(
        ELineCleared(
          cleared.linesCleared,
          highlightLines: cleared.highlightLines,
          containsHighlightColor: cleared.highlightLines > 0,
        ),
      );
    }
    _challengeEngine?.onEvent(
      ETurnAdvanced(clearedThisTurn: cleared.linesCleared > 0),
    );
    _challengeEngine?.onEvent(EScoreChanged(score));
    unawaited(_persistState());
    if (gameOver) {
      unawaited(_ads.recordGameCompleted());
      _challengeEngine?.onEvent(EGameOver());
    }
    if (gameOver && state.isDailyChallenge && !state.dailyChallengeCompleted) {
      unawaited(_completeDailyChallenge(score));
    }
  }

  void rotatePiece(String pieceId) {
    if (!state.rotationEnabled || state.isGameOver || state.isPaused) return;
    final rotated = [
      for (final piece in state.activePieces)
        piece.id == pieceId ? piece.rotateClockwise() : piece,
    ];
    state = state.copyWith(activePieces: rotated);
    _challengeEngine?.onEvent(ERotationUsed());
    unawaited(_persistState());
  }

  void undo() {
    if (state.undoPowerUps <= 0 || state.history.isEmpty || state.isPaused) {
      return;
    }
    final snapshot = state.history.last;
    final remainingHistory = state.history.sublist(0, state.history.length - 1);
    final board = cloneBoard(snapshot.board);
    final isGameOver =
        snapshot.activePieces.isEmpty ? true : !_hasAnyValidMoves(board, snapshot.activePieces);
    state = state.copyWith(
      board: board,
      activePieces: snapshot.activePieces,
      score: snapshot.score,
      comboStreak: snapshot.comboStreak,
      rngState: snapshot.rngState,
      batchCounter: snapshot.batchCounter,
      history: remainingHistory,
      isGameOver: isGameOver,
      lastPlacementScore: 0,
      lastLinesCleared: 0,
      undoPowerUps: state.undoPowerUps - 1,
    );
    unawaited(_persistState());
  }

  void toggleRotation([bool? value]) {
    state = state.copyWith(
      rotationEnabled: value ?? !state.rotationEnabled,
    );
    unawaited(_persistState());
  }

  void toggleSound([bool? value]) {
    state = state.copyWith(soundEnabled: value ?? !state.soundEnabled);
    unawaited(_persistState());
  }

  void toggleMusic([bool? value]) {
    state = state.copyWith(musicEnabled: value ?? !state.musicEnabled);
    unawaited(_persistState());
  }

  void toggleHaptics([bool? value]) {
    state = state.copyWith(hapticsEnabled: value ?? !state.hapticsEnabled);
    unawaited(_persistState());
  }

  bool canPlace(String pieceId, int row, int col) {
    if (state.isPaused || state.isGameOver) return false;
    final piece = _findPiece(pieceId);
    if (piece == null) return false;
    return _canPlace(piece, row, col, state.board);
  }

  bool get canUndo =>
      state.history.isNotEmpty && state.undoPowerUps > 0;

  List<GameSnapshot> _trimmedHistory(List<GameSnapshot> history) {
    if (history.length <= _maxUndoSnapshots) {
      return history;
    }
    return history.sublist(history.length - _maxUndoSnapshots);
  }

  _TrayResult _maybeRefillTray(
    List<BlockPiece> pieces,
    List<List<int?>> board,
    int rngState,
    int batchCounter,
  ) {
    if (pieces.isNotEmpty) {
      return _TrayResult(pieces, rngState, batchCounter);
    }
    final batch = _drawBatch(rngState);
    return _TrayResult(batch.pieces, batch.rngState, batchCounter + 1);
  }

  _BatchResult _drawBatch(int seed) {
    var nextState = seed == 0 ? _dailySeed() : seed;
    final difficultyScale = switch (state.difficulty) {
      'easy' => 0.85,
      'hard' => 1.15,
      _ => 1.0,
    };
    final piecesToGenerate = (3 * difficultyScale).round().clamp(3, 5);
    final pieces = <BlockPiece>[];
    while (pieces.length < piecesToGenerate) {
      nextState = XorShift32.step(nextState);
      final index =
          (nextState & 0x7FFFFFFF) % blockPrototypes.length;
      final proto = blockPrototypes[index];
      pieces.add(
        BlockPiece(
          id: '${proto.id}_${_pieceSerial++}',
          cells: cloneShape(proto.shape),
          colorValue: proto.colorValue,
        ),
      );
    }
    return _BatchResult(pieces, nextState);
  }

  _ClearResult _clearCompletedLines(
    List<List<int?>> board, {
    int? highlightColor,
  }) {
    final size = board.length;
    final rowsToClear = <int>[];
    final colsToClear = <int>[];
    final highlightRows = <int>{};
    final highlightCols = <int>{};
    for (var y = 0; y < size; y++) {
      final row = board[y];
      if (!row.every((cell) => cell != null)) continue;
      rowsToClear.add(y);
      if (highlightColor != null &&
          row.any((cell) => cell == highlightColor)) {
        highlightRows.add(y);
      }
    }
    for (var x = 0; x < size; x++) {
      var full = true;
      var containsHighlight = false;
      for (var y = 0; y < size; y++) {
        final cell = board[y][x];
        if (cell == null) {
          full = false;
          break;
        }
        if (!containsHighlight &&
            highlightColor != null &&
            cell == highlightColor) {
          containsHighlight = true;
        }
      }
      if (!full) continue;
      colsToClear.add(x);
      if (containsHighlight) {
        highlightCols.add(x);
      }
    }
    for (final row in rowsToClear) {
      for (var x = 0; x < size; x++) {
        board[row][x] = null;
      }
    }
    for (final col in colsToClear) {
      for (var y = 0; y < size; y++) {
        board[y][col] = null;
      }
    }
    final linesCleared = rowsToClear.length + colsToClear.length;
    final highlightLines = highlightRows.length + highlightCols.length;
    return _ClearResult(linesCleared, highlightLines);
  }

  int _scoreForLines(int linesCleared, int comboBefore) {
    if (linesCleared == 0) return 0;
    final base = linesCleared * 120;
    final comboBonus = comboBefore + 1;
    final chainBonus = linesCleared > 1 ? (linesCleared - 1) * 50 : 0;
    final difficultyMultiplier = switch (state.difficulty) {
      'easy' => 0.8,
      'hard' => 1.25,
      _ => 1.0,
    };
    return ((base * comboBonus + chainBonus) * difficultyMultiplier).round();
  }

  bool _hasAnyValidMoves(
    List<List<int?>> board,
    List<BlockPiece> pieces,
  ) {
    for (final piece in pieces) {
      for (var row = 0; row <= board.length - piece.height; row++) {
        for (var col = 0; col <= board[row].length - piece.width; col++) {
          if (_canPlace(piece, row, col, board)) {
            return true;
          }
        }
      }
    }
    return false;
  }

  bool _canPlace(
    BlockPiece piece,
    int row,
    int col,
    List<List<int?>> board,
  ) {
    if (row < 0 ||
        col < 0 ||
        row + piece.height > board.length ||
        col + piece.width > board.first.length) {
      return false;
    }
    for (var y = 0; y < piece.height; y++) {
      for (var x = 0; x < piece.width; x++) {
        if (piece.cells[y][x] == 1 && board[row + y][col + x] != null) {
          return false;
        }
      }
    }
    return true;
  }

  int _pointsForPiece(BlockPiece piece) {
    var filled = 0;
    for (final row in piece.cells) {
      for (final cell in row) {
        if (cell == 1) filled++;
      }
    }
    return filled * _pointsPerFilledCell;
  }

  Future<void> _completeDailyChallenge(int score) async {
    final id = state.dailyChallengeId;
    if (id == null) return;
    final existing = await _challenges.getEntry(id) ??
        DailyChallengeEntry(id: id, seed: state.dailyChallengeSeed ?? _seedForId(id));
    if (existing.completed) return;
    final updated = existing.copyWith(
      completed: true,
      bestScore: score,
      completedAt: DateTime.now().toUtc(),
    );
    await _challenges.saveEntry(updated);
    await _syncChallengeMeta();
    final rewardChallenge = _currentDailyChallenge();
    if (rewardChallenge != null && rewardChallenge.rewardAmount > 0) {
      _applyPowerUpReward(
        rewardChallenge.rewardType,
        amount: rewardChallenge.rewardAmount,
      );
    }
    final target = state.dailyChallengeTarget;
    state = state.copyWith(
      dailyChallengeCompleted: true,
      dailyChallengeBestScore: updated.bestScore,
      dailyChallengeProgress: target,
      unlockedAchievements: _unlockAchievements(
        current: state.unlockedAchievements,
        score: state.score,
        bestCombo: state.bestComboStreak,
        totalLines: state.totalLinesCleared,
        totalGames: state.totalGamesPlayed,
        challengeStreak: state.challengeStreak,
        dailyChallengeCompleted: true,
      ),
    );
  }

  DailyChallenge? _currentDailyChallenge() {
    if (_activeChallenge != null) return _activeChallenge;
    final id = state.dailyChallengeId;
    if (id == null) return null;
    final date = DailyChallengeRepository.parseId(id);
    return _challengeGenerator.forDate(date);
  }

  void _handleChallengeUpdate(ChallengeProgress progress) {
    final challenge = _activeChallenge;
    if (challenge == null || !state.isDailyChallenge) return;
    final value = _challengeProgressValue(progress);
    if (value != null && value != state.dailyChallengeProgress) {
      state = state.copyWith(dailyChallengeProgress: value);
    }
    if (!state.dailyChallengeCompleted && progress.completed) {
      state = state.copyWith(
        dailyChallengeProgress: state.dailyChallengeTarget,
      );
      unawaited(_completeDailyChallenge(state.score));
    }
  }

  static List<int> _buildBlockColorPalette() {
    final unique = <int>{};
    for (final proto in blockPrototypes) {
      unique.add(proto.colorValue);
    }
    final palette = unique.toList()..sort();
    return palette;
  }

  int? _resolveChallengeHighlightColor(DailyChallenge challenge) {
    if (challenge.type != ChallengeType.colorOfTheDay ||
        _blockColorPalette.isEmpty) {
      return null;
    }
    final index = challenge.params['highlightColor'] ?? 0;
    return _blockColorPalette[index % _blockColorPalette.length];
  }

  int _challengeTargetFor(DailyChallenge challenge) {
    return switch (challenge.type) {
      ChallengeType.colorOfTheDay => challenge.params['lines'] ?? 0,
      _ => 0,
    };
  }

  int? _challengeProgressValue(ChallengeProgress progress) {
    if (_activeChallenge?.type != ChallengeType.colorOfTheDay) return null;
    return progress.highlightColorLines;
  }

  Future<void> _syncChallengeMeta() async {
    final entries = await _challenges.getRecentEntries();
    final streak = _challenges.calculateStreak(entries);
    state = state.copyWith(
      challengeStreak: streak,
      challengeHistory: _summariesFrom(entries),
      unlockedAchievements: _unlockAchievements(
        current: state.unlockedAchievements,
        score: state.score,
        bestCombo: state.bestComboStreak,
        totalLines: state.totalLinesCleared,
        totalGames: state.totalGamesPlayed,
        challengeStreak: streak,
        dailyChallengeCompleted: state.dailyChallengeCompleted,
      ),
    );
  }

  List<DailyChallengeSummary> _summariesFrom(
    List<DailyChallengeEntry> entries,
  ) {
    return [
      for (final entry in entries)
        DailyChallengeSummary(
          id: entry.id,
          seed: entry.seed,
          completed: entry.completed,
          bestScore: entry.bestScore,
          completedAt: entry.completedAt,
        ),
    ];
  }

  int _seedForId(String id) {
    final date = DailyChallengeRepository.parseId(id);
    return _seedForDate(date);
  }

  int _dailySeed() => _seedForDate(DateTime.now().toUtc());

  int _seedForDate(DateTime date) {
    final normalized = DateTime.utc(date.year, date.month, date.day);
    final key =
        normalized.year ^ (normalized.month << 8) ^ (normalized.day << 16);
    return XorShift32.normalizeSeed(key ^ 0xC1A0C5);
  }

  BlockPiece? _findPiece(String pieceId) {
    for (final piece in state.activePieces) {
      if (piece.id == pieceId) {
        return piece;
      }
    }
    return null;
  }

  void resetBestScore() {
    state = state.copyWith(bestScore: 0);
  }

  void setTheme(String themeId) {
    if (!gameThemes.containsKey(themeId)) return;
    state = state.copyWith(themeId: themeId);
    unawaited(_persistState());
  }

  void setDifficulty(String difficulty) {
    if (!_allowedDifficulties.contains(difficulty) ||
        state.difficulty == difficulty) {
      return;
    }
    state = state.copyWith(difficulty: difficulty);
    unawaited(_persistState());
  }

  void skipTrayPowerUp() {
    if (state.skipPowerUps == 0 || state.isGameOver || state.isPaused) return;
    final tray = _maybeRefillTray(
      const [],
      state.board,
      state.rngState,
      state.batchCounter,
    );
    state = state.copyWith(
      activePieces: tray.pieces,
      rngState: tray.rngState,
      batchCounter: tray.batchCounter,
      skipPowerUps: state.skipPowerUps - 1,
      hint: null,
    );
    unawaited(_persistState());
  }

  void useHintPowerUp() {
    if (state.hintPowerUps == 0 || state.isGameOver || state.isPaused) return;
    final suggestion = _findHint(state.activePieces, state.board);
    if (suggestion == null) return;
    state = state.copyWith(
      hintPowerUps: state.hintPowerUps - 1,
      hint: suggestion,
    );
    unawaited(_persistState());
  }

  Future<void> watchAdForPowerUp(PowerUpType type) async {
    if (state.isPaused) return;
    final placement = switch (type) {
      PowerUpType.undo => AdPlacement.rewardedUndo,
      PowerUpType.skip => AdPlacement.rewardedSkip,
      PowerUpType.hint => AdPlacement.rewardedHint,
    };
    String normalizeRewardLabel(String label) =>
        label.toLowerCase().replaceAll(RegExp(r'[^a-z]'), '');
    final rewardAliases = switch (type) {
      PowerUpType.undo => const {'undo', 'undos'},
      PowerUpType.skip => const {'skip', 'skips'},
      PowerUpType.hint => const {'hint', 'hints'},
    };
    final rewarded = await _ads.showRewarded(
      placement: placement,
      onReward: (amount, rewardType) {
        final creditAmount = amount > 0 ? amount : 1;
        final normalized = normalizeRewardLabel(rewardType);
        final matches =
            normalized.isEmpty || rewardAliases.contains(normalized);
        if (!matches) {
          debugPrint(
            'Reward label mismatch for $type: "$rewardType" (giving credit anyway).',
          );
        }
        _applyPowerUpReward(type, amount: creditAmount);
      },
    );
    if (!rewarded) return;
  }

  void _applyPowerUpReward(PowerUpType type, {int amount = 1}) {
    final delta = amount <= 0 ? 1 : amount;
    switch (type) {
      case PowerUpType.undo:
        state = state.copyWith(undoPowerUps: state.undoPowerUps + delta);
        break;
      case PowerUpType.skip:
        state = state.copyWith(skipPowerUps: state.skipPowerUps + delta);
        break;
      case PowerUpType.hint:
        state = state.copyWith(hintPowerUps: state.hintPowerUps + delta);
        break;
    }
    unawaited(_persistState());
  }

  Future<bool> watchAdForBonus() async {
    if (!state.isGameOver || state.gameOverBonusClaimed) return false;
    final rewarded = await _ads.showRewarded(
      placement: AdPlacement.rewardedGameOverBonus,
      onReward: (amount, rewardType) {
        final normalized =
            rewardType.toLowerCase().replaceAll(RegExp(r'[^a-z]'), '');
        if (normalized.isNotEmpty && normalized != 'gameoverbonus') {
          debugPrint(
            'Reward label mismatch for game over bonus: "$rewardType" (using reward anyway).',
          );
        }
        final bonusPoints = amount >= _gameOverBonusPoints
            ? amount
            : _gameOverBonusPoints;
        if (amount < _gameOverBonusPoints) {
          debugPrint(
            'Rewarded amount $amount is below bonus floor; granting $_gameOverBonusPoints instead.',
          );
        }
        _applyGameOverBonus(bonusPoints);
      },
    );
    return rewarded;
  }

  void _applyGameOverBonus(int bonusPoints) {
    final current = state;
    final bonusScore = current.score + bonusPoints;
    final updatedTotalScore = current.totalScoreAccumulated + bonusPoints;
    final updatedDailyBest = max(current.dailyChallengeBestScore, bonusScore);
    final updatedBestScore = max(current.bestScore, bonusScore);
    final updatedAchievements = _unlockAchievements(
      current: current.unlockedAchievements,
      score: bonusScore,
      bestCombo: current.bestComboStreak,
      totalLines: current.totalLinesCleared,
      totalGames: current.totalGamesPlayed,
      challengeStreak: current.challengeStreak,
      dailyChallengeCompleted: current.dailyChallengeCompleted,
    );
    state = current.copyWith(
      score: bonusScore,
      bestScore: updatedBestScore,
      gameOverBonusClaimed: true,
      totalScoreAccumulated: updatedTotalScore,
      dailyChallengeBestScore: updatedDailyBest,
      unlockedAchievements: updatedAchievements,
    );
    if (current.isDailyChallenge &&
        current.dailyChallengeId != null &&
        bonusScore > current.dailyChallengeBestScore) {
      unawaited(_updateDailyChallengeBest(current.dailyChallengeId!, bonusScore));
    }
    unawaited(_persistState());
  }

  Future<void> _updateDailyChallengeBest(String id, int score) async {
    final entry = await _challenges.getEntry(id);
    if (entry == null) return;
    if (score <= entry.bestScore) return;
    await _challenges.saveEntry(entry.copyWith(bestScore: score));
    await _syncChallengeMeta();
  }

  void pause() {
    if (state.isPaused || state.isGameOver) return;
    state = state.copyWith(isPaused: true);
    unawaited(_persistState());
  }

  void resume() {
    if (!state.isPaused) return;
    state = state.copyWith(isPaused: false);
    unawaited(_persistState());
  }

  HintSuggestion? _findHint(
    List<BlockPiece> pieces,
    List<List<int?>> board,
  ) {
    for (final piece in pieces) {
      for (var row = 0; row <= board.length - piece.height; row++) {
        for (var col = 0; col <= board[row].length - piece.width; col++) {
          if (_canPlace(piece, row, col, board)) {
            return HintSuggestion(pieceId: piece.id, row: row, col: col);
          }
        }
      }
    }
    return null;
  }

  Future<void> _loadSavedGameState() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefsGameStateKey);
    if (raw == null || raw.isEmpty) return;
    try {
      final data = jsonDecode(raw) as Map<String, dynamic>;
      var loaded = GameState.fromJson(data);
      final migratedAlready = prefs.getBool(_prefsHolyCircusMigrated) ?? false;
      if (!migratedAlready) {
        loaded = loaded.copyWith(themeId: defaultThemeId);
        await prefs.setBool(_prefsHolyCircusMigrated, true);
      }
      final migrated = _applyStateMigrations(loaded);
      state = migrated.copyWith(isPaused: true);
    } catch (_) {
      await prefs.remove(_prefsGameStateKey);
    }
  }

  Future<void> _saveGameState() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsGameStateKey, jsonEncode(state.toJson()));
  }

  Future<void> _persistState() async {
    await _saveGameState();
    await _savePowerUps();
  }

  void _resetPieceSerial() {
    var maxSerial = 0;
    void inspect(List<BlockPiece> pieces) {
      for (final piece in pieces) {
        final parts = piece.id.split('_');
        final parsed = parts.isNotEmpty ? int.tryParse(parts.last) ?? 0 : 0;
        if (parsed > maxSerial) maxSerial = parsed;
      }
    }

    inspect(state.activePieces);
    for (final snapshot in state.history) {
      inspect(snapshot.activePieces);
    }
    _pieceSerial = maxSerial + 1;
  }

  Future<void> _loadPowerUps() async {
    final prefs = await SharedPreferences.getInstance();
    final storedUndo = prefs.getInt(_prefsUndoKey);
    final storedSkip = prefs.getInt(_prefsSkipKey);
    final storedHint = prefs.getInt(_prefsHintKey);

    state = state.copyWith(
      undoPowerUps:
          storedUndo ?? (state.undoPowerUps == 0 ? 3 : state.undoPowerUps),
      skipPowerUps:
          storedSkip ?? (state.skipPowerUps == 0 ? 3 : state.skipPowerUps),
      hintPowerUps:
          storedHint ?? (state.hintPowerUps == 0 ? 3 : state.hintPowerUps),
    );
    await _savePowerUps();
  }

  Future<void> _savePowerUps() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_prefsUndoKey, state.undoPowerUps);
    await prefs.setInt(_prefsSkipKey, state.skipPowerUps);
    await prefs.setInt(_prefsHintKey, state.hintPowerUps);
  }

  List<String> _unlockAchievements({
    required List<String> current,
    required int score,
    required int bestCombo,
    required int totalLines,
    required int totalGames,
    required int challengeStreak,
    required bool dailyChallengeCompleted,
  }) {
    final unlocked = {...current};
    if (totalGames >= 1) unlocked.add('first_game');
    if (totalGames >= 10) unlocked.add('ten_games');
    if (score >= 1000) unlocked.add('score_1000');
    if (score >= 5000) unlocked.add('score_5000');
    if (bestCombo >= 5) unlocked.add('combo_5');
    if (bestCombo >= 10) unlocked.add('combo_10');
    if (totalLines >= 100) unlocked.add('lines_100');
    if (totalLines >= 500) unlocked.add('lines_500');
    if (dailyChallengeCompleted) unlocked.add('daily_complete');
    if (challengeStreak >= 5) unlocked.add('streak_5');
    final sorted = unlocked.toList()..sort();
    return sorted;
  }

  GameState _applyStateMigrations(GameState incoming) {
    var migrated = incoming;
    if (!gameThemes.containsKey(migrated.themeId)) {
      migrated = migrated.copyWith(themeId: defaultThemeId);
    } else if (_legacyDefaultThemeIds.contains(migrated.themeId)) {
      migrated = migrated.copyWith(themeId: defaultThemeId);
    }
    return migrated;
  }

  (String title, String instruction) _describeChallenge(DailyChallenge challenge) {
    return switch (challenge.type) {
      ChallengeType.earlyBlessing => (
        'Early Blessing',
        'Score at least ${challenge.params['score']} points within ${challenge.params['movesCap']} pieces.',
      ),
      ChallengeType.colorOfTheDay => (
        'Color of the Day',
        'Clear ${challenge.params['lines']} lines that include the highlighted color.',
      ),
      ChallengeType.perfectTen => (
        'Perfect Ten',
        'Clear exactly ${challenge.params['targetLines']} lines before the game ends.',
      ),
      ChallengeType.comboCrusade => (
        'Combo Crusade',
        'Trigger at least ${challenge.params['minCombos']} multi-line clears.',
      ),
      ChallengeType.holyStreak => (
        'Holy Streak',
        'Chain ${challenge.params['streak']} consecutive turns with a line clear.',
      ),
      ChallengeType.puzzleOfPatience => (
        'Puzzle of Patience',
        'Survive ${challenge.params['rounds']} tray refreshes without busting.',
      ),
      ChallengeType.featherTouch => (
        'Feather Touch',
        'Reach ${challenge.params['score']} points without rotating any piece.',
      ),
      ChallengeType.tripleBlessing => (
        'Triple Blessing',
        'Clear at least ${challenge.params['minLines']} lines in a single move.',
      ),
    };
  }
}
