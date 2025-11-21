class Achievement {
  const Achievement({
    required this.id,
    required this.title,
    required this.description,
  });

  final String id;
  final String title;
  final String description;
}

const achievementCatalog = [
  Achievement(
    id: 'first_game',
    title: 'First Flight',
    description: 'Finish your very first run.',
  ),
  Achievement(
    id: 'ten_games',
    title: 'Persistent Pilot',
    description: 'Complete 10 total games.',
  ),
  Achievement(
    id: 'score_1000',
    title: 'One-K Navigator',
    description: 'Score at least 1,000 points in a single game.',
  ),
  Achievement(
    id: 'score_5000',
    title: 'Five-K Voyager',
    description: 'Score 5,000 points in a single game.',
  ),
  Achievement(
    id: 'combo_5',
    title: 'Combo Cadet',
    description: 'Reach a combo streak of 5.',
  ),
  Achievement(
    id: 'combo_10',
    title: 'Combo Commander',
    description: 'Reach a combo streak of 10.',
  ),
  Achievement(
    id: 'lines_100',
    title: 'Line Harvester',
    description: 'Clear 100 lines across all games.',
  ),
  Achievement(
    id: 'lines_500',
    title: 'Galaxy Sweeper',
    description: 'Clear 500 lines across all games.',
  ),
  Achievement(
    id: 'daily_complete',
    title: 'Daily Hero',
    description: 'Complete any daily challenge.',
  ),
  Achievement(
    id: 'streak_5',
    title: 'Chrono Runner',
    description: 'Maintain a 5-day daily challenge streak.',
  ),
];
