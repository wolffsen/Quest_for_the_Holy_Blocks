import 'block_piece.dart';
import 'game_theme.dart';

const int kBoardSize = 10;
const difficultyLevels = ['easy', 'medium', 'hard'];

List<List<int?>> createEmptyBoard([int size = kBoardSize]) =>
    List.generate(size, (_) => List<int?>.filled(size, null, growable: false),
        growable: false);

List<List<int?>> cloneBoard(List<List<int?>> source) => [
      for (final row in source) List<int?>.from(row, growable: false),
    ];

List<BlockPiece> clonePieces(List<BlockPiece> source) => [
      for (final piece in source)
        BlockPiece(
          id: piece.id,
          cells: piece.cells,
          colorValue: piece.colorValue,
        ),
    ];

class HintSuggestion {
  const HintSuggestion({
    required this.pieceId,
    required this.row,
    required this.col,
  });

  final String pieceId;
  final int row;
  final int col;

  bool covers(BlockPiece piece, int boardRow, int boardCol) {
    if (piece.id != pieceId) return false;
    final localRow = boardRow - row;
    final localCol = boardCol - col;
    if (localRow < 0 || localCol < 0) return false;
    if (localRow >= piece.height || localCol >= piece.width) return false;
    return piece.cells[localRow][localCol] == 1;
  }

  factory HintSuggestion.fromJson(Map<String, dynamic> json) => HintSuggestion(
        pieceId: json['pieceId'] as String,
        row: json['row'] as int,
        col: json['col'] as int,
      );

  Map<String, dynamic> toJson() => {
        'pieceId': pieceId,
        'row': row,
        'col': col,
      };
}

class GameSnapshot {
  GameSnapshot({
    required List<List<int?>> board,
    required List<BlockPiece> activePieces,
    required this.score,
    required this.comboStreak,
    required this.rngState,
    required this.batchCounter,
  })  : board = cloneBoard(board),
        activePieces = List<BlockPiece>.unmodifiable(clonePieces(activePieces));

  final List<List<int?>> board;
  final List<BlockPiece> activePieces;
  final int score;
  final int comboStreak;
  final int rngState;
  final int batchCounter;

  factory GameSnapshot.fromJson(Map<String, dynamic> json) => GameSnapshot(
        board: (json['board'] as List<dynamic>? ?? const [])
            .map<List<int?>>(
              (row) => (row as List<dynamic>)
                  .map((cell) => cell as int?)
                  .toList(growable: false),
            )
            .toList(growable: false),
        activePieces: (json['activePieces'] as List<dynamic>? ?? const [])
            .map((item) => BlockPiece.fromJson(item as Map<String, dynamic>))
            .toList(growable: false),
        score: json['score'] as int? ?? 0,
        comboStreak: json['comboStreak'] as int? ?? 0,
        rngState: json['rngState'] as int? ?? 0,
        batchCounter: json['batchCounter'] as int? ?? 0,
      );

  Map<String, dynamic> toJson() => {
        'board': board.map((row) => List<int?>.from(row)).toList(growable: false),
        'activePieces':
            activePieces.map((piece) => piece.toJson()).toList(growable: false),
        'score': score,
        'comboStreak': comboStreak,
        'rngState': rngState,
        'batchCounter': batchCounter,
      };
}

class DailyChallengeSummary {
  DailyChallengeSummary({
    required this.id,
    required this.seed,
    required this.completed,
    required this.bestScore,
    this.completedAt,
  });

  final String id;
  final int seed;
  final bool completed;
  final int bestScore;
  final DateTime? completedAt;

  factory DailyChallengeSummary.fromJson(Map<String, dynamic> json) {
    return DailyChallengeSummary(
      id: json['id'] as String,
      seed: json['seed'] as int,
      completed: json['completed'] as bool? ?? false,
      bestScore: json['bestScore'] as int? ?? 0,
      completedAt: json['completedAt'] != null
          ? DateTime.tryParse(json['completedAt'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'seed': seed,
        'completed': completed,
        'bestScore': bestScore,
        'completedAt': completedAt?.toIso8601String(),
      };
}

class GameState {
  GameState({
    required List<List<int?>> board,
    required List<BlockPiece> activePieces,
    this.score = 0,
    this.bestScore = 0,
    this.comboStreak = 0,
    this.isGameOver = false,
    this.rotationEnabled = true,
    List<GameSnapshot> history = const [],
    this.rngState = 0,
    this.batchCounter = 0,
    this.lastPlacementScore = 0,
    this.lastLinesCleared = 0,
    this.comboEffectId = 0,
    this.isDailyChallenge = false,
    this.dailyChallengeId,
    this.dailyChallengeSeed,
    this.dailyChallengeCompleted = false,
    this.dailyChallengeBestScore = 0,
    this.dailyChallengeTitle,
    this.dailyChallengeInstruction,
    this.dailyChallengeHighlightColor,
    this.dailyChallengeProgress = 0,
    this.dailyChallengeTarget = 0,
    this.challengeStreak = 0,
    List<DailyChallengeSummary> challengeHistory = const [],
    this.themeId = defaultThemeId,
    this.soundEnabled = true,
    this.hapticsEnabled = true,
    this.musicEnabled = true,
    this.undoPowerUps = 0,
    this.skipPowerUps = 0,
    this.hintPowerUps = 0,
    this.hint,
    this.difficulty = 'medium',
    this.isPaused = false,
    this.gameOverBonusClaimed = false,
    this.totalGamesPlayed = 0,
    this.totalScoreAccumulated = 0,
    this.totalLinesCleared = 0,
    this.bestComboStreak = 0,
    List<String> unlockedAchievements = const [],
  })  : board = cloneBoard(board),
        activePieces = List<BlockPiece>.unmodifiable(clonePieces(activePieces)),
        history = List<GameSnapshot>.unmodifiable(history),
        challengeHistory =
            List<DailyChallengeSummary>.unmodifiable(challengeHistory),
        unlockedAchievements =
            List<String>.unmodifiable(unlockedAchievements);

  final List<List<int?>> board;
  final List<BlockPiece> activePieces;
  final int score;
  final int bestScore;
  final int comboStreak;
  final bool isGameOver;
  final bool rotationEnabled;
  final List<GameSnapshot> history;
  final int rngState;
  final int batchCounter;
  final int lastPlacementScore;
  final int lastLinesCleared;
  final int comboEffectId;
  final bool isDailyChallenge;
  final String? dailyChallengeId;
  final int? dailyChallengeSeed;
  final bool dailyChallengeCompleted;
  final int dailyChallengeBestScore;
  final String? dailyChallengeTitle;
  final String? dailyChallengeInstruction;
  final int? dailyChallengeHighlightColor;
  final int dailyChallengeProgress;
  final int dailyChallengeTarget;
  final int challengeStreak;
  final List<DailyChallengeSummary> challengeHistory;
  final String themeId;
  final bool soundEnabled;
  final bool hapticsEnabled;
  final bool musicEnabled;
  final int undoPowerUps;
  final int skipPowerUps;
  final int hintPowerUps;
  final HintSuggestion? hint;
  final String difficulty;
  final bool isPaused;
  final bool gameOverBonusClaimed;
  final List<String> unlockedAchievements;
  final int totalGamesPlayed;
  final int totalScoreAccumulated;
  final int totalLinesCleared;
  final int bestComboStreak;

  double get averageScore =>
      totalGamesPlayed == 0 ? 0 : totalScoreAccumulated / totalGamesPlayed;

  int get achievementsUnlocked => unlockedAchievements.length;

  GameThemeData get theme =>
      gameThemes[themeId] ?? gameThemes[defaultThemeId]!;

  factory GameState.initial({
    bool rotationEnabled = true,
    int seed = 0,
    String themeId = defaultThemeId,
    bool soundEnabled = true,
    bool hapticsEnabled = true,
    bool musicEnabled = true,
    String difficulty = 'medium',
  }) {
    return GameState(
      board: createEmptyBoard(),
      activePieces: const [],
      rotationEnabled: rotationEnabled,
      rngState: seed,
      themeId: themeId,
      soundEnabled: soundEnabled,
      hapticsEnabled: hapticsEnabled,
      musicEnabled: musicEnabled,
      difficulty: difficulty,
    );
  }

  GameState copyWith({
    List<List<int?>>? board,
    List<BlockPiece>? activePieces,
    int? score,
    int? bestScore,
    int? comboStreak,
    bool? isGameOver,
    bool? rotationEnabled,
    List<GameSnapshot>? history,
    int? rngState,
    int? batchCounter,
    int? lastPlacementScore,
    int? lastLinesCleared,
    int? comboEffectId,
    bool? isDailyChallenge,
    String? dailyChallengeId,
    int? dailyChallengeSeed,
    bool? dailyChallengeCompleted,
    int? dailyChallengeBestScore,
    String? dailyChallengeTitle,
    String? dailyChallengeInstruction,
    int? dailyChallengeHighlightColor,
    int? dailyChallengeProgress,
    int? dailyChallengeTarget,
    int? challengeStreak,
    List<DailyChallengeSummary>? challengeHistory,
    String? themeId,
    bool? soundEnabled,
    bool? hapticsEnabled,
    bool? musicEnabled,
    int? undoPowerUps,
    int? skipPowerUps,
    int? hintPowerUps,
    HintSuggestion? hint,
    String? difficulty,
    bool? isPaused,
    bool? gameOverBonusClaimed,
    int? totalGamesPlayed,
    int? totalScoreAccumulated,
    int? totalLinesCleared,
    int? bestComboStreak,
    List<String>? unlockedAchievements,
  }) {
    return GameState(
      board: board ?? this.board,
      activePieces: activePieces ?? this.activePieces,
      score: score ?? this.score,
      bestScore: bestScore ?? this.bestScore,
      comboStreak: comboStreak ?? this.comboStreak,
      isGameOver: isGameOver ?? this.isGameOver,
      rotationEnabled: rotationEnabled ?? this.rotationEnabled,
      history: history ?? this.history,
      rngState: rngState ?? this.rngState,
      batchCounter: batchCounter ?? this.batchCounter,
      lastPlacementScore: lastPlacementScore ?? this.lastPlacementScore,
      lastLinesCleared: lastLinesCleared ?? this.lastLinesCleared,
      comboEffectId: comboEffectId ?? this.comboEffectId,
      isDailyChallenge: isDailyChallenge ?? this.isDailyChallenge,
      dailyChallengeId: dailyChallengeId ?? this.dailyChallengeId,
      dailyChallengeSeed: dailyChallengeSeed ?? this.dailyChallengeSeed,
      dailyChallengeCompleted:
          dailyChallengeCompleted ?? this.dailyChallengeCompleted,
      dailyChallengeBestScore:
          dailyChallengeBestScore ?? this.dailyChallengeBestScore,
      dailyChallengeTitle:
          dailyChallengeTitle ?? this.dailyChallengeTitle,
      dailyChallengeInstruction:
          dailyChallengeInstruction ?? this.dailyChallengeInstruction,
      dailyChallengeHighlightColor:
          dailyChallengeHighlightColor ?? this.dailyChallengeHighlightColor,
      dailyChallengeProgress:
          dailyChallengeProgress ?? this.dailyChallengeProgress,
      dailyChallengeTarget:
          dailyChallengeTarget ?? this.dailyChallengeTarget,
      challengeStreak: challengeStreak ?? this.challengeStreak,
      challengeHistory: challengeHistory ?? this.challengeHistory,
      themeId: themeId ?? this.themeId,
      soundEnabled: soundEnabled ?? this.soundEnabled,
      hapticsEnabled: hapticsEnabled ?? this.hapticsEnabled,
      musicEnabled: musicEnabled ?? this.musicEnabled,
      undoPowerUps: undoPowerUps ?? this.undoPowerUps,
      skipPowerUps: skipPowerUps ?? this.skipPowerUps,
      hintPowerUps: hintPowerUps ?? this.hintPowerUps,
      hint: hint ?? this.hint,
      difficulty: difficulty ?? this.difficulty,
      isPaused: isPaused ?? this.isPaused,
      gameOverBonusClaimed:
          gameOverBonusClaimed ?? this.gameOverBonusClaimed,
      totalGamesPlayed: totalGamesPlayed ?? this.totalGamesPlayed,
      totalScoreAccumulated:
          totalScoreAccumulated ?? this.totalScoreAccumulated,
      totalLinesCleared: totalLinesCleared ?? this.totalLinesCleared,
      bestComboStreak: bestComboStreak ?? this.bestComboStreak,
      unlockedAchievements:
          unlockedAchievements ?? this.unlockedAchievements,
    );
  }

  factory GameState.fromJson(Map<String, dynamic> json) => GameState(
        board: (json['board'] as List<dynamic>? ?? const [])
            .map<List<int?>>(
              (row) => (row as List<dynamic>)
                  .map((cell) => cell as int?)
                  .toList(growable: false),
            )
            .toList(growable: false),
        activePieces: (json['activePieces'] as List<dynamic>? ?? const [])
            .map((item) => BlockPiece.fromJson(item as Map<String, dynamic>))
            .toList(growable: false),
        score: json['score'] as int? ?? 0,
        bestScore: json['bestScore'] as int? ?? 0,
        comboStreak: json['comboStreak'] as int? ?? 0,
        isGameOver: json['isGameOver'] as bool? ?? false,
        rotationEnabled: json['rotationEnabled'] as bool? ?? true,
        history: (json['history'] as List<dynamic>? ?? const [])
            .map((item) => GameSnapshot.fromJson(item as Map<String, dynamic>))
            .toList(growable: false),
        rngState: json['rngState'] as int? ?? 0,
        batchCounter: json['batchCounter'] as int? ?? 0,
        lastPlacementScore: json['lastPlacementScore'] as int? ?? 0,
        lastLinesCleared: json['lastLinesCleared'] as int? ?? 0,
        comboEffectId: json['comboEffectId'] as int? ?? 0,
        isDailyChallenge: json['isDailyChallenge'] as bool? ?? false,
        dailyChallengeId: json['dailyChallengeId'] as String?,
        dailyChallengeSeed: json['dailyChallengeSeed'] as int?,
        dailyChallengeCompleted:
            json['dailyChallengeCompleted'] as bool? ?? false,
        dailyChallengeBestScore:
            json['dailyChallengeBestScore'] as int? ?? 0,
        dailyChallengeTitle: json['dailyChallengeTitle'] as String?,
        dailyChallengeInstruction:
            json['dailyChallengeInstruction'] as String?,
        dailyChallengeHighlightColor:
            json['dailyChallengeHighlightColor'] as int?,
        dailyChallengeProgress:
            json['dailyChallengeProgress'] as int? ?? 0,
        dailyChallengeTarget:
            json['dailyChallengeTarget'] as int? ?? 0,
        challengeStreak: json['challengeStreak'] as int? ?? 0,
        challengeHistory: (json['challengeHistory'] as List<dynamic>? ?? const [])
            .map((item) =>
                DailyChallengeSummary.fromJson(item as Map<String, dynamic>))
            .toList(growable: false),
        themeId: json['themeId'] as String? ?? defaultThemeId,
        soundEnabled: json['soundEnabled'] as bool? ?? true,
        hapticsEnabled: json['hapticsEnabled'] as bool? ?? true,
        musicEnabled: json['musicEnabled'] as bool? ?? true,
        undoPowerUps: json['undoPowerUps'] as int? ?? 0,
        skipPowerUps: json['skipPowerUps'] as int? ?? 0,
        hintPowerUps: json['hintPowerUps'] as int? ?? 0,
        hint: json['hint'] != null
            ? HintSuggestion.fromJson(json['hint'] as Map<String, dynamic>)
            : null,
        difficulty: json['difficulty'] as String? ?? 'medium',
        isPaused: json['isPaused'] as bool? ?? false,
        gameOverBonusClaimed:
            json['gameOverBonusClaimed'] as bool? ?? false,
        totalGamesPlayed: json['totalGamesPlayed'] as int? ?? 0,
        totalScoreAccumulated:
            json['totalScoreAccumulated'] as int? ?? 0,
        totalLinesCleared: json['totalLinesCleared'] as int? ?? 0,
        bestComboStreak: json['bestComboStreak'] as int? ?? 0,
        unlockedAchievements: (json['unlockedAchievements']
                    as List<dynamic>? ??
                const [])
            .cast<String>(),
      );

  Map<String, dynamic> toJson() => {
        'board': board.map((row) => List<int?>.from(row)).toList(growable: false),
        'activePieces':
            activePieces.map((piece) => piece.toJson()).toList(growable: false),
        'score': score,
        'bestScore': bestScore,
        'comboStreak': comboStreak,
        'isGameOver': isGameOver,
        'rotationEnabled': rotationEnabled,
        'history': history.map((snapshot) => snapshot.toJson()).toList(growable: false),
        'rngState': rngState,
        'batchCounter': batchCounter,
        'lastPlacementScore': lastPlacementScore,
        'lastLinesCleared': lastLinesCleared,
        'comboEffectId': comboEffectId,
        'isDailyChallenge': isDailyChallenge,
        'dailyChallengeId': dailyChallengeId,
        'dailyChallengeSeed': dailyChallengeSeed,
        'dailyChallengeCompleted': dailyChallengeCompleted,
        'dailyChallengeBestScore': dailyChallengeBestScore,
        'dailyChallengeTitle': dailyChallengeTitle,
        'dailyChallengeInstruction': dailyChallengeInstruction,
        'dailyChallengeHighlightColor': dailyChallengeHighlightColor,
        'dailyChallengeProgress': dailyChallengeProgress,
        'dailyChallengeTarget': dailyChallengeTarget,
        'challengeStreak': challengeStreak,
        'challengeHistory':
            challengeHistory.map((entry) => entry.toJson()).toList(growable: false),
        'themeId': themeId,
        'soundEnabled': soundEnabled,
        'hapticsEnabled': hapticsEnabled,
        'musicEnabled': musicEnabled,
        'undoPowerUps': undoPowerUps,
        'skipPowerUps': skipPowerUps,
        'hintPowerUps': hintPowerUps,
        'hint': hint?.toJson(),
        'difficulty': difficulty,
        'isPaused': isPaused,
        'gameOverBonusClaimed': gameOverBonusClaimed,
        'totalGamesPlayed': totalGamesPlayed,
        'totalScoreAccumulated': totalScoreAccumulated,
        'totalLinesCleared': totalLinesCleared,
        'bestComboStreak': bestComboStreak,
        'unlockedAchievements':
            unlockedAchievements.toList(growable: false),
      };
}
