int fnv1a32(String input) {
  const int fnvPrime = 0x01000193;
  int hash = 0x811C9DC5;
  for (final codeUnit in input.codeUnits) {
    hash ^= codeUnit;
    hash = (hash * fnvPrime) & 0xFFFFFFFF;
  }
  return hash;
}

DateTime normalizeUtcMidnight(DateTime dateUtc) =>
    DateTime.utc(dateUtc.year, dateUtc.month, dateUtc.day);

DateTime todayUtcMidnight() => normalizeUtcMidnight(DateTime.now().toUtc());
