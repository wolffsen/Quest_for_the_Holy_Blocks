import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';

import '../controllers/game_controller.dart';
import '../models/game_state.dart';
import '../models/game_theme.dart';
import '../models/power_up_type.dart';
import 'main_menu_page.dart' show MainMenuPage;
import 'widgets/game_board.dart';
import 'widgets/piece_tray.dart';

const _gameOverBonusPoints = 500;

class GamePage extends ConsumerStatefulWidget {
  const GamePage({super.key});

  @override
  ConsumerState<GamePage> createState() => _GamePageState();
}

class _GamePageState extends ConsumerState<GamePage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final state = ref.read(gameControllerProvider);
      if (state.activePieces.isEmpty) {
        ref.read(gameControllerProvider.notifier).bootstrap();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(gameControllerProvider);
    final controller = ref.read(gameControllerProvider.notifier);
    final theme = state.theme;

    return Scaffold(
      body: Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              gradient: theme.backgroundGradient,
              image: theme.backgroundImage,
            ),
          ),
          SafeArea(
            child: Stack(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _TopBar(
                        state: state,
                        onBack: () {
                          controller.pause();
                          Navigator.of(context).pushReplacement(
                            MaterialPageRoute(builder: (_) => const MainMenuPage()),
                          );
                        },
                        onOpenSettings: () {
                          if (!state.isPaused) controller.pause();
                        },
                      ),
                      const SizedBox(height: 12),
                      _StatStrip(state: state),
                      if (state.isDailyChallenge &&
                          state.dailyChallengeTitle != null &&
                          state.dailyChallengeInstruction != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: _DailyChallengeInfo(
                            title: state.dailyChallengeTitle!,
                            instruction: state.dailyChallengeInstruction!,
                            progress: state.dailyChallengeProgress,
                            target: state.dailyChallengeTarget,
                            highlightColor: state.dailyChallengeHighlightColor,
                          ),
                        ),
                      const SizedBox(height: 16),
                      Expanded(
                        child: Column(
                          children: [
                            Expanded(
                              child: Center(
                                child: ConstrainedBox(
                                  constraints: const BoxConstraints(maxWidth: 420),
                                  child: IgnorePointer(
                                    ignoring: state.isPaused || state.isGameOver,
                                    child: const GameBoard(),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 24),
                            IgnorePointer(
                              ignoring: state.isPaused || state.isGameOver,
                              child: const PieceTray(),
                            ),
                            const SizedBox(height: 140),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Align(
                  alignment: Alignment.bottomCenter,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: _PowerFabToolbar(
                      state: state,
                      onUseUndo: controller.canUndo
                          ? () {
                              HapticFeedback.lightImpact();
                              controller.undo();
                            }
                          : null,
                      onUseSkip: state.skipPowerUps > 0 && !state.isPaused && !state.isGameOver
                          ? () {
                              HapticFeedback.lightImpact();
                              controller.skipTrayPowerUp();
                            }
                          : null,
                      onUseHint: state.hintPowerUps > 0 && !state.isPaused && !state.isGameOver
                          ? () {
                              HapticFeedback.selectionClick();
                              controller.useHintPowerUp();
                            }
                          : null,
                      onRequestAd: (type) => _handlePowerAd(context, controller, type),
                    ),
                  ),
                ),
                if (state.isPaused)
                  _PauseOverlay(
                    controller: controller,
                    state: state,
                  ),
              ],
            ),
          ),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: state.lastLinesCleared > 1
                ? _ComboBanner(
                    key: ValueKey(state.comboEffectId),
                    linesCleared: state.lastLinesCleared,
                    pointsAwarded: state.lastPlacementScore,
                    theme: theme,
                  )
                : const SizedBox.shrink(),
          ),
          if (state.isDailyChallenge && state.dailyChallengeCompleted)
            _DailyChallengeBadge(theme: theme),
          if (state.isGameOver)
            _GameOverOverlay(controller: controller, state: state),
        ],
      ),
    );
  }

  Future<void> _handlePowerAd(
    BuildContext context,
    GameController controller,
    PowerUpType type,
  ) async {
    final labels = {
      PowerUpType.undo: ('Undo', 'Gain an extra undo by watching a short ad.'),
      PowerUpType.skip: ('Skip', 'Refresh your tray with a rewarded ad.'),
      PowerUpType.hint: ('Hint', 'Reveal a placement suggestion via ad.'),
    };
    final (title, message) = labels[type]!;
    final confirmed = await showModalBottomSheet<bool>(
          context: context,
          builder: (ctx) => Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(title, style: Theme.of(ctx).textTheme.titleLarge),
                const SizedBox(height: 12),
                Text(message, style: Theme.of(ctx).textTheme.bodyMedium),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Not now')),
                    const SizedBox(width: 12),
                    FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Watch Ad')),
                  ],
                ),
              ],
            ),
          ),
        ) ??
        false;
    if (!confirmed) return;
    await controller.watchAdForPowerUp(type);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$title power-up added!')),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.state,
    required this.onBack,
    required this.onOpenSettings,
  });

  final GameState state;
  final VoidCallback onBack;
  final VoidCallback onOpenSettings;

  @override
  Widget build(BuildContext context) {
    final scoreStyle = Theme.of(context).textTheme.displayMedium?.copyWith(
          fontWeight: FontWeight.w700,
          color: Colors.white,
        );
    final subtitleStyle = Theme.of(context).textTheme.bodySmall?.copyWith(
          color: Colors.white70,
        );
    return Row(
      children: [
        IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: onBack,
        ),
        Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Score', style: subtitleStyle),
              Text('${state.score}', style: scoreStyle, textAlign: TextAlign.center),
              if (state.comboStreak > 1)
                Text('Combo x${state.comboStreak}', style: subtitleStyle),
            ],
          ),
        ),
        IconButton(
          icon: const Icon(Icons.settings),
          onPressed: onOpenSettings,
        ),
      ],
    );
  }
}

class _StatStrip extends StatelessWidget {
  const _StatStrip({required this.state});
  final GameState state;

  @override
  Widget build(BuildContext context) {
    final items = <_StatPill>[
      _StatPill(label: 'Best', value: state.bestScore.toString()),
      _StatPill(
        label: 'Lines',
        value: state.totalLinesCleared.toString(),
      ),
      _StatPill(
        label: 'Daily Best',
        value: state.dailyChallengeBestScore == 0 ? '—' : state.dailyChallengeBestScore.toString(),
      ),
    ];
    return Wrap(
      spacing: 12,
      runSpacing: 8,
      alignment: WrapAlignment.center,
      children: items,
    );
  }
}

class _StatPill extends StatelessWidget {
  const _StatPill({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: theme.textTheme.labelSmall?.copyWith(color: Colors.white70)),
          const SizedBox(height: 4),
          Text(value, style: theme.textTheme.titleMedium?.copyWith(color: Colors.white)),
        ],
      ),
    );
  }
}

class _PowerFabToolbar extends StatelessWidget {
  const _PowerFabToolbar({
    required this.state,
    required this.onUseUndo,
    required this.onUseSkip,
    required this.onUseHint,
    required this.onRequestAd,
  });

  final GameState state;
  final VoidCallback? onUseUndo;
  final VoidCallback? onUseSkip;
  final VoidCallback? onUseHint;
  final ValueChanged<PowerUpType> onRequestAd;

  @override
  Widget build(BuildContext context) {
    if (state.isGameOver) return const SizedBox.shrink();
    final disabled = state.isPaused;
    final background = state.theme.chipBackgroundColor.withValues(alpha: 0.85);
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 200),
      opacity: disabled ? 0.35 : 1,
      child: IgnorePointer(
        ignoring: disabled,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.circular(24),
            boxShadow: const [
              BoxShadow(color: Colors.black45, blurRadius: 16, offset: Offset(0, 4)),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _PowerFab(
                icon: Icons.undo,
                label: 'Undo',
                count: state.undoPowerUps,
                enabled: onUseUndo != null,
                onActivate: onUseUndo,
                onRequestAd: () => onRequestAd(PowerUpType.undo),
              ),
              const SizedBox(width: 12),
              _PowerFab(
                icon: Icons.shuffle,
                label: 'Skip',
                count: state.skipPowerUps,
                enabled: onUseSkip != null,
                onActivate: onUseSkip,
                onRequestAd: () => onRequestAd(PowerUpType.skip),
              ),
              const SizedBox(width: 12),
              _PowerFab(
                icon: Icons.lightbulb,
                label: 'Hint',
                count: state.hintPowerUps,
                enabled: onUseHint != null,
                onActivate: onUseHint,
                onRequestAd: () => onRequestAd(PowerUpType.hint),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PowerFab extends StatelessWidget {
  const _PowerFab({
    required this.icon,
    required this.label,
    required this.count,
    required this.enabled,
    required this.onActivate,
    required this.onRequestAd,
  });

  final IconData icon;
  final String label;
  final int count;
  final bool enabled;
  final VoidCallback? onActivate;
  final VoidCallback onRequestAd;

  @override
  Widget build(BuildContext context) {
    final hasCharges = count > 0;
    final canActivate = hasCharges && enabled && onActivate != null;
    final showAd = !hasCharges;
    final baseColor = Colors.white;
    final pillStyle = Theme.of(context).textTheme.labelSmall?.copyWith(color: Colors.white70);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: canActivate
              ? onActivate
              : showAd
                  ? onRequestAd
                  : null,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: canActivate ? const Color(0xFFFFC778) : Colors.white12,
                  border: Border.all(color: Colors.white24, width: 1),
                ),
                child: Icon(
                  icon,
                  size: 20,
                  color: canActivate ? Colors.black87 : baseColor.withValues(alpha: 0.65),
                ),
              ),
              if (showAd)
                const Positioned(
                  bottom: 6,
                  right: 6,
                  child: Icon(Icons.add_circle, size: 14, color: Colors.white70),
                ),
            ],
          ),
        ),
        if (showAd)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(
              'Get more',
              style: pillStyle?.copyWith(fontSize: 10),
            ),
          ),
        const SizedBox(height: 4),
        Text('×$count', style: pillStyle),
        Text(label, style: pillStyle),
      ],
    );
  }
}

class _PauseOverlay extends StatelessWidget {
  const _PauseOverlay({
    required this.controller,
    required this.state,
  });

  final GameController controller;
  final GameState state;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Positioned.fill(
      child: DecoratedBox(
        decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.65)),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Card(
              margin: const EdgeInsets.symmetric(horizontal: 24),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('Mission Control', style: theme.textTheme.titleLarge),
                    const SizedBox(height: 16),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 360),
                      child: SingleChildScrollView(
                        child: Column(
                          children: [
                            _SettingsGroup(
                              title: 'Gameplay',
                              children: [
                                SwitchListTile(
                                  value: state.rotationEnabled,
                                  onChanged: (value) => controller.toggleRotation(value),
                                  title: const Text('Allow rotation'),
                                ),
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                  child: _DifficultySelector(
                                    current: state.difficulty,
                                    onChanged: controller.setDifficulty,
                                  ),
                                ),
                              ],
                            ),
                            _SettingsGroup(
                              title: 'Audio & Feel',
                              children: [
                                SwitchListTile(
                                  value: state.soundEnabled,
                                  onChanged: (value) => controller.toggleSound(value),
                                  title: const Text('Sound effects'),
                                ),
                                SwitchListTile(
                                  value: state.musicEnabled,
                                  onChanged: (value) => controller.toggleMusic(value),
                                  title: const Text('Music'),
                                ),
                                SwitchListTile(
                                  value: state.hapticsEnabled,
                                  onChanged: (value) => controller.toggleHaptics(value),
                                  title: const Text('Haptics'),
                                ),
                              ],
                            ),
                            _SettingsGroup(
                              title: 'Appearance',
                              children: [
                                ListTile(
                                  leading: const Icon(Icons.palette_outlined),
                                  title: const Text('Theme'),
                                  subtitle: Text(state.theme.name),
                                  trailing: const Icon(Icons.chevron_right),
                                  onTap: () => _pickTheme(context, controller, state.themeId),
                                ),
                              ],
                            ),
                            _SettingsGroup(
                              title: 'Data',
                              children: [
                                ListTile(
                                  leading: const Icon(Icons.auto_fix_off),
                                  title: const Text('Reset best score'),
                                  onTap: () async {
                                    final confirm = await showDialog<bool>(
                                          context: context,
                                          builder: (ctx) => AlertDialog(
                                            title: const Text('Reset best score?'),
                                            content: const Text('This cannot be undone.'),
                                            actions: [
                                              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                                              FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Reset')),
                                            ],
                                          ),
                                        ) ??
                                        false;
                                    if (confirm) controller.resetBestScore();
                                  },
                                ),
                                const ListTile(
                                  leading: Icon(Icons.privacy_tip_outlined),
                                  title: Text('Privacy policy'),
                                  subtitle: Text('Coming soon'),
                                  enabled: false,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        FilledButton(
                          onPressed: controller.resume,
                          child: const Text('Resume'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _pickTheme(
    BuildContext context,
    GameController controller,
    String currentThemeId,
  ) async {
    final selected = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => ListView(
        shrinkWrap: true,
        children: [
          for (final entry in availableThemes)
            ListTile(
              title: Text(entry.name),
              trailing: entry.id == currentThemeId ? const Icon(Icons.check) : null,
              selected: entry.id == currentThemeId,
              onTap: () => Navigator.pop(ctx, entry.id),
            ),
        ],
      ),
    );
    if (selected != null) controller.setTheme(selected);
  }
}

class _SettingsGroup extends StatelessWidget {
  const _SettingsGroup({required this.title, required this.children});
  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final headline = Theme.of(context).textTheme.titleMedium;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: headline),
          const SizedBox(height: 8),
          ...children,
        ],
      ),
    );
  }
}

class _DifficultySelector extends StatelessWidget {
  const _DifficultySelector({required this.current, required this.onChanged});
  final String current;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      children: [
        for (final level in difficultyLevels)
          ChoiceChip(
            label: Text(level[0].toUpperCase() + level.substring(1)),
            selected: current == level,
            onSelected: (selected) {
              if (selected) onChanged(level);
            },
          ),
      ],
    );
  }
}

class _GameOverOverlay extends StatelessWidget {
  const _GameOverOverlay({required this.controller, required this.state});

  final GameController controller;
  final GameState state;

  @override
  Widget build(BuildContext context) {
    final theme = state.theme;
    final overlayStart = theme.dropHighlightColor.withValues(alpha: 0.85);
    final overlayEnd = theme.boardShadowColor.withValues(alpha: 0.6);
    return Positioned.fill(
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [overlayStart, overlayEnd],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 360),
            child: Card(
              margin: const EdgeInsets.symmetric(horizontal: 24),
              color: Colors.deepPurple.shade900.withValues(alpha: 0.9),
              elevation: 16,
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'No more star-paths!',
                      style: Theme.of(context).textTheme.titleLarge,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    Text('Score: ${state.score}', textAlign: TextAlign.center),
                    Text('Best: ${state.bestScore}', textAlign: TextAlign.center),
                    Text('Max Combo: ${state.comboStreak}', textAlign: TextAlign.center),
                    const SizedBox(height: 20),
                    FilledButton(
                      onPressed: controller.startNewGame,
                      child: const Text('Play Again'),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: state.gameOverBonusClaimed
                          ? null
                          : () async {
                              final rewarded = await controller.watchAdForBonus();
                              if (!context.mounted) return;
                              if (!rewarded) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Ad not available. Please try again later.'),
                                  ),
                                );
                              }
                            },
                      icon: const Icon(Icons.emoji_emotions),
                      label: Text(
                        state.gameOverBonusClaimed
                            ? 'Bonus Claimed'
                            : 'Watch Ad for +$_gameOverBonusPoints',
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DailyChallengeBadge extends StatelessWidget {
  const _DailyChallengeBadge({required this.theme});

  final GameThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 24,
      right: 24,
      child: Chip(
        backgroundColor: theme.dropHighlightColor.withValues(alpha: 0.85),
        labelPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        avatar: const Icon(Icons.star, color: Colors.black87),
        label: Text(
          'Daily Challenge Completed',
          style: Theme.of(context)
              .textTheme
              .labelLarge
              ?.copyWith(color: Colors.black87, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}

class _ComboBanner extends StatelessWidget {
  const _ComboBanner({
    super.key,
    required this.linesCleared,
    required this.pointsAwarded,
    required this.theme,
  });

  final int linesCleared;
  final int pointsAwarded;
  final GameThemeData theme;

  @override
  Widget build(BuildContext context) {
    final gradient = theme.comboLinearGradient;
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(top: 48),
      child: Align(
        alignment: Alignment.topCenter,
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(32),
            gradient: gradient,
            boxShadow: const [
              BoxShadow(
                color: Color(0x884AE9D8),
                blurRadius: 20,
                spreadRadius: 4,
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Combo x$linesCleared!',
                  style: textTheme.titleLarge?.copyWith(color: Colors.white),
                ),
                Text(
                  '+$pointsAwarded points',
                  style: textTheme.titleMedium?.copyWith(color: Colors.white70),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DailyChallengeInfo extends StatelessWidget {
  const _DailyChallengeInfo({
    required this.title,
    required this.instruction,
    required this.progress,
    required this.target,
    this.highlightColor,
  });

  final String title;
  final String instruction;
  final int progress;
  final int target;
  final int? highlightColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white24),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: theme.textTheme.titleMedium?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              instruction,
              style: theme.textTheme.bodySmall?.copyWith(
                color: Colors.white70,
              ),
            ),
            if (highlightColor != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 18,
                      height: 18,
                      decoration: BoxDecoration(
                        color: Color(highlightColor!),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: Colors.white54),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Target color',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: Colors.white70,
                      ),
                    ),
                  ],
                ),
              ),
            if (target > 0)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  'Progress: ${(progress > target ? target : progress)} / $target',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: Colors.white70,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
