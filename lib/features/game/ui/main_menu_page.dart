import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../controllers/game_controller.dart';
import '../models/game_state.dart';
import '../models/game_theme.dart';
import 'game_page.dart';
import '../data/achievements.dart';

class MainMenuPage extends ConsumerWidget {
  const MainMenuPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(gameControllerProvider);
    final controller = ref.read(gameControllerProvider.notifier);
    final theme = state.theme;
    final canContinue = !state.isGameOver && state.activePieces.isNotEmpty;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: theme.backgroundGradient,
          image: theme.backgroundImage,
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(
                      height: 112,
                      width: 112,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(28),
                        child: Image.asset(
                          'assets/block-blast.png',
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Text(
                        'Quest for the Holy Blocks',
                        style: Theme.of(context)
                            .textTheme
                            .displaySmall
                            ?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 32),
                FilledButton(
                  onPressed: () {
                    controller.startNewGame();
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const GamePage()),
                    );
                  },
                  child: const Text('Start New Game'),
                ),
                const SizedBox(height: 12),
                FilledButton.tonal(
                  onPressed: canContinue
                      ? () {
                          controller.resume();
                          Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => const GamePage()),
                          );
                        }
                      : null,
                  child: const Text('Continue'),
                ),
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: () async {
                    await controller.startDailyChallenge();
                    if (!context.mounted) return;
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const GamePage()),
                    );
                  },
                  child: const Text('Daily Challenge'),
                ),
                const SizedBox(height: 32),
                FilledButton.icon(
                  icon: const Icon(Icons.settings),
                  onPressed: () => _showSettings(context, controller, state),
                  label: const Text('Settings'),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  icon: const Icon(Icons.leaderboard),
                  onPressed: () => _showStatsAndAchievements(context, state),
                  label: const Text('Stats & Achievements'),
                ),
                const Spacer(),
                Text(
                  'Best Score: ${state.bestScore}',
                  style: Theme.of(context)
                      .textTheme
                      .bodyLarge
                      ?.copyWith(color: Colors.white70),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showSettings(
    BuildContext context,
    GameController controller,
    GameState state,
  ) {
    showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.symmetric(vertical: 16),
        children: [
          SwitchListTile(
            value: state.soundEnabled,
            onChanged: (_) => controller.toggleSound(),
            title: const Text('Sound Effects'),
          ),
          SwitchListTile(
            value: state.musicEnabled,
            onChanged: (_) => controller.toggleMusic(),
            title: const Text('Music'),
          ),
          SwitchListTile(
            value: state.hapticsEnabled,
            onChanged: (_) => controller.toggleHaptics(),
            title: const Text('Vibration'),
          ),
          ListTile(
            leading: const Icon(Icons.palette),
            title: const Text('Theme'),
            subtitle: Text(state.theme.name),
            onTap: () => _pickTheme(ctx, controller),
          ),
          ListTile(
            leading: const Icon(Icons.tune),
            title: const Text('Difficulty'),
            subtitle: Text(state.difficulty),
            onTap: () => _pickDifficulty(ctx, controller, state.difficulty),
          ),
        ],
      ),
    );
  }

  void _pickTheme(BuildContext context, GameController controller) {
    showDialog<void>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('Choose Theme'),
        children: [
          for (final entry in availableThemes)
            SimpleDialogOption(
              onPressed: () {
                controller.setTheme(entry.id);
                Navigator.pop(ctx);
              },
              child: Text(entry.name),
            ),
        ],
      ),
    );
  }

  void _pickDifficulty(
    BuildContext context,
    GameController controller,
    String current,
  ) {
    showDialog<void>(
      context: context,
      builder: (ctx) {
        var selected = current;
        return StatefulBuilder(
          builder: (context, setState) => SimpleDialog(
            title: const Text('Select Difficulty'),
            children: [
              for (final level in difficultyLevels)
                ListTile(
                  title: Text(level[0].toUpperCase() + level.substring(1)),
                  trailing: selected == level ? const Icon(Icons.check) : null,
                  selected: selected == level,
                  onTap: () {
                    setState(() => selected = level);
                    controller.setDifficulty(level);
                    Navigator.pop(ctx);
                  },
                ),
            ],
          ),
        );
      },
    );
  }

  void _showStatsAndAchievements(BuildContext context, GameState state) {
    showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Mission Stats', style: Theme.of(ctx).textTheme.titleLarge),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.star),
              title: const Text('All-time Best'),
              trailing: Text(state.bestScore.toString()),
            ),
            ListTile(
              leading: const Icon(Icons.sports_score),
              title: const Text('Average Score'),
              trailing: Text(state.averageScore.toStringAsFixed(1)),
            ),
            ListTile(
              leading: const Icon(Icons.rocket_launch),
              title: const Text('Games Played'),
              trailing: Text(state.totalGamesPlayed.toString()),
            ),
            ListTile(
              leading: const Icon(Icons.auto_graph),
              title: const Text('Best Combo Streak'),
              trailing: Text(state.bestComboStreak.toString()),
            ),
            ListTile(
              leading: const Icon(Icons.grid_on),
              title: const Text('Lines Cleared'),
              trailing: Text(state.totalLinesCleared.toString()),
            ),
            ListTile(
              leading: const Icon(Icons.calendar_month),
              title: const Text('Daily Challenge Streak'),
              trailing: Text(state.challengeStreak.toString()),
            ),
            const Divider(),
            Text(
              'Achievements (${state.achievementsUnlocked}/${achievementCatalog.length})',
              style: Theme.of(ctx).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            for (final achievement in achievementCatalog)
              ListTile(
                leading: Icon(
                  state.unlockedAchievements.contains(achievement.id)
                      ? Icons.verified
                      : Icons.lock_outline,
                  color: state.unlockedAchievements.contains(achievement.id)
                      ? Colors.tealAccent
                      : Colors.white24,
                ),
                title: Text(achievement.title),
                subtitle: Text(achievement.description),
              ),
            const Divider(),
            if (state.challengeHistory.isEmpty)
              const ListTile(
                title: Text('No daily challenge history yet.'),
              )
            else
              for (final entry in state.challengeHistory)
                ListTile(
                  leading: Icon(
                    entry.completed
                        ? Icons.check_circle
                        : Icons.radio_button_unchecked,
                    color: entry.completed ? Colors.teal : Colors.grey,
                  ),
                  title: Text(entry.id),
                  trailing: Text(entry.bestScore.toString()),
                ),
          ],
        ),
      ),
    );
  }
}
