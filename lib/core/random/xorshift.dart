class XorShift32 {
  static const int _mask32 = 0xFFFFFFFF;

  static int normalizeSeed(int seed) {
    final normalized = seed & _mask32;
    return normalized == 0 ? 0x6C8E9CF5 : normalized;
  }

  static int step(int state) {
    var x = normalizeSeed(state);
    x ^= (x << 13) & _mask32;
    x ^= (x >> 17);
    x ^= (x << 5) & _mask32;
    return x & _mask32;
  }

  static int positiveValue(int state) => step(state) & 0x7FFFFFFF;

  static int nextIndex(int state, int max) {
    if (max <= 0) return 0;
    final value = positiveValue(state);
    return value % max;
  }
}
