import 'package:flutter/material.dart';

class GameThemeData {
  const GameThemeData({
    required this.id,
    required this.name,
    required this.backgroundGradient,
    required this.boardGradient,
    required this.boardBorderColor,
    required this.boardShadowColor,
    required this.emptyCellColor,
    required this.dropHighlightColor,
    required this.chipBackgroundColor,
    required this.trayGlowColor,
    required this.comboGradient,
    this.backgroundImage,
  });

  final String id;
  final String name;
  final Gradient backgroundGradient;
  final Gradient boardGradient;
  final Color boardBorderColor;
  final Color boardShadowColor;
  final Color emptyCellColor;
  final Color dropHighlightColor;
  final Color chipBackgroundColor;
  final Color trayGlowColor;
  final List<Color> comboGradient;
  final DecorationImage? backgroundImage;

  LinearGradient get comboLinearGradient => LinearGradient(
        colors: comboGradient,
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );
}

const defaultThemeId = 'holy_circus';

const holyCircusTheme = GameThemeData(
  id: 'holy_circus',
  name: 'Holy Circus',
  backgroundGradient: LinearGradient(
    colors: [
      Color(0xFFFFC778),
      Color(0xFFFF8BA7),
      Color(0xFF7ED1FF),
    ],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  ),
  backgroundImage: DecorationImage(
    image: AssetImage('assets/block-blast.png'),
    fit: BoxFit.cover,
    colorFilter: ColorFilter.mode(
      Color(0xD81B1037),
      BlendMode.srcATop,
    ),
  ),
  boardGradient: LinearGradient(
    colors: [
      Color(0xFF311A66),
      Color(0xFF4E2A8E),
    ],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  ),
  boardBorderColor: Color(0xFFFFE066),
  boardShadowColor: Color(0xCC000000),
  dropHighlightColor: Color(0xFFFFC045),
  comboGradient: [Color(0xFFFF9E80), Color(0xFFFFF176)],
  chipBackgroundColor: Color(0xCC2A194F),
  trayGlowColor: Color(0xFFFFD166),
  emptyCellColor: Color(0x33161532),
);

const gameThemes = <String, GameThemeData>{
  'holy_circus': holyCircusTheme,
  'neon_glow': GameThemeData(
    id: 'neon_glow',
    name: 'Neon Glow',
    backgroundGradient: LinearGradient(
      colors: [Color(0xFF1B1734), Color(0xFF09051F)],
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
    ),
    boardGradient: LinearGradient(
      colors: [Color(0xFF1A1038), Color(0xFF0A051C)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
    boardBorderColor: Color(0x88FFFFFF),
    boardShadowColor: Color(0x55215BFF),
    emptyCellColor: Color(0x33FFFFFF),
    dropHighlightColor: Color(0xFF00FFC6),
    chipBackgroundColor: Color(0x22FFFFFF),
    trayGlowColor: Color(0xFF4AE9D8),
    comboGradient: [Color(0xFF4AE9D8), Color(0xFF7B5BFF)],
  ),
  'classic_wood': GameThemeData(
    id: 'classic_wood',
    name: 'Classic Wood',
    backgroundGradient: LinearGradient(
      colors: [Color(0xFF7B4A2D), Color(0xFF3E2415)],
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
    ),
    boardGradient: LinearGradient(
      colors: [Color(0xFF5C3723), Color(0xFF2E1B10)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
    boardBorderColor: Color(0x88FFE0B2),
    boardShadowColor: Color(0x553E2415),
    emptyCellColor: Color(0x33FFE0B2),
    dropHighlightColor: Color(0xFFFFC15E),
    chipBackgroundColor: Color(0x22FFE0B2),
    trayGlowColor: Color(0xFFFFB74D),
    comboGradient: [Color(0xFFFFE0B2), Color(0xFFFFA726)],
  ),
  'deep_space': GameThemeData(
    id: 'deep_space',
    name: 'Deep Space',
    backgroundGradient: LinearGradient(
      colors: [Color(0xFF000814), Color(0xFF001D3D)],
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
    ),
    boardGradient: LinearGradient(
      colors: [Color(0xFF001427), Color(0xFF000B1D)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
    boardBorderColor: Color(0x5580A1C1),
    boardShadowColor: Color(0x5521478A),
    emptyCellColor: Color(0x2221478A),
    dropHighlightColor: Color(0xFF64FFDA),
    chipBackgroundColor: Color(0x2221478A),
    trayGlowColor: Color(0xFF64FFDA),
    comboGradient: [Color(0xFF64FFDA), Color(0xFF00B4D8)],
  ),
  'pastel_dream': GameThemeData(
    id: 'pastel_dream',
    name: 'Pastel Dream',
    backgroundGradient: LinearGradient(
      colors: [Color(0xFFFFF5F7), Color(0xFFE0F7FA)],
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
    ),
    boardGradient: LinearGradient(
      colors: [Color(0xFFFFE0F2), Color(0xFFE0F7FA)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
    boardBorderColor: Color(0x55FF80AB),
    boardShadowColor: Color(0x33FF80AB),
    emptyCellColor: Color(0x44FFFFFF),
    dropHighlightColor: Color(0xFF81D4FA),
    chipBackgroundColor: Color(0x33FFFFFF),
    trayGlowColor: Color(0xFFFF8A80),
    comboGradient: [Color(0xFFFF8A80), Color(0xFF80DEEA)],
  ),
  'piranha_brothers': GameThemeData(
    id: 'piranha_brothers',
    name: 'Piranha Brothers',
    backgroundGradient: LinearGradient(
      colors: [Color(0xFF3F2B96), Color(0xFFA8C0FF)],
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
    ),
    boardGradient: LinearGradient(
      colors: [Color(0xFF6A11CB), Color(0xFF2575FC)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
    boardBorderColor: Color(0x88FFFFFF),
    boardShadowColor: Color(0x553F2B96),
    emptyCellColor: Color(0x33FFFFFF),
    dropHighlightColor: Color(0xFFFFD60A),
    chipBackgroundColor: Color(0x22FFFFFF),
    trayGlowColor: Color(0xFFFFC300),
    comboGradient: [Color(0xFFFFD60A), Color(0xFFFF6B6B)],
  ),
};

Iterable<GameThemeData> get availableThemes => gameThemes.values;
