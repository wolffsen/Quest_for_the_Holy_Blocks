import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _storageKey = 'daily_challenges_cache';
const _maxEntries = 14;

class DailyChallengeEntry {
  DailyChallengeEntry({
    required this.id,
    required this.seed,
    this.completed = false,
    this.bestScore = 0,
    DateTime? completedAt,
  }) : completedAt = completedAt?.toUtc();

  final String id;
  final int seed;
  final bool completed;
  final int bestScore;
  final DateTime? completedAt;

  DailyChallengeEntry copyWith({
    bool? completed,
    int? bestScore,
    DateTime? completedAt,
  }) {
    return DailyChallengeEntry(
      id: id,
      seed: seed,
      completed: completed ?? this.completed,
      bestScore: bestScore ?? this.bestScore,
      completedAt: completedAt ?? this.completedAt,
    );
  }

  factory DailyChallengeEntry.fromJson(Map<String, dynamic> json) {
    return DailyChallengeEntry(
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

class DailyChallengeRepository {
  Future<SharedPreferences> get _prefs async => SharedPreferences.getInstance();

  Future<Map<String, DailyChallengeEntry>> _loadAll() async {
    final prefs = await _prefs;
    final raw = prefs.getString(_storageKey);
    if (raw == null || raw.isEmpty) return {};
    final decoded = jsonDecode(raw) as List<dynamic>;
    final map = <String, DailyChallengeEntry>{};
    for (final item in decoded) {
      final entry =
          DailyChallengeEntry.fromJson(item as Map<String, dynamic>);
      map[entry.id] = entry;
    }
    return map;
  }

  Future<void> _persist(Map<String, DailyChallengeEntry> entries) async {
    final prefs = await _prefs;
    final sorted = entries.values.toList()
      ..sort((a, b) => b.id.compareTo(a.id));
    final trimmed = sorted.take(_maxEntries).toList();
    await prefs.setString(
      _storageKey,
      jsonEncode([
        for (final entry in trimmed) entry.toJson(),
      ]),
    );
  }

  Future<DailyChallengeEntry> ensureEntry(String id, int seed) async {
    final map = await _loadAll();
    final existing = map[id];
    if (existing != null) return existing;
    final created = DailyChallengeEntry(id: id, seed: seed);
    map[id] = created;
    await _persist(map);
    return created;
  }

  Future<DailyChallengeEntry?> getEntry(String id) async {
    final map = await _loadAll();
    return map[id];
  }

  Future<void> saveEntry(DailyChallengeEntry entry) async {
    final map = await _loadAll();
    map[entry.id] = entry;
    await _persist(map);
  }

  Future<List<DailyChallengeEntry>> getRecentEntries() async {
    final map = await _loadAll();
    final entries = map.values.toList()
      ..sort((a, b) => b.id.compareTo(a.id));
    return entries.take(_maxEntries).toList();
  }

  int calculateStreak(List<DailyChallengeEntry> entries) {
    if (entries.isEmpty) return 0;
    final lookup = {for (final entry in entries) entry.id: entry};
    var streak = 0;
    var cursor = DateTime.now().toUtc();
    while (true) {
      final id = formatId(cursor);
      final entry = lookup[id];
      if (entry == null || !entry.completed) {
        break;
      }
      streak++;
      cursor = cursor.subtract(const Duration(days: 1));
    }
    return streak;
  }

  static String formatId(DateTime date) {
    final utc = DateTime.utc(date.year, date.month, date.day);
    return '${utc.year.toString().padLeft(4, '0')}'
        '${utc.month.toString().padLeft(2, '0')}'
        '${utc.day.toString().padLeft(2, '0')}';
  }

  static DateTime parseId(String id) {
    final year = int.parse(id.substring(0, 4));
    final month = int.parse(id.substring(4, 6));
    final day = int.parse(id.substring(6, 8));
    return DateTime.utc(year, month, day);
  }
}

final dailyChallengeRepositoryProvider =
    Provider<DailyChallengeRepository>((ref) => DailyChallengeRepository());
