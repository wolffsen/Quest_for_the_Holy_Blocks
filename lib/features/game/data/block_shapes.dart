class BlockPrototype {
  final String id;
  final List<List<int>> shape;
  final int colorValue;

  const BlockPrototype({
    required this.id,
    required this.shape,
    required this.colorValue,
  });
}

List<List<int>> cloneShape(List<List<int>> shape) =>
    [for (final row in shape) [...row]];

const blockPrototypes = <BlockPrototype>[
  BlockPrototype(
    id: 'starline',
    shape: [
      [1, 1, 1, 1],
    ],
    colorValue: 0xFF7F5AF0,
  ),
  BlockPrototype(
    id: 'nebula_t',
    shape: [
      [0, 1, 0],
      [1, 1, 1],
    ],
    colorValue: 0xFF2CB1BC,
  ),
  BlockPrototype(
    id: 'asteroid_l',
    shape: [
      [1, 0, 0],
      [1, 1, 1],
    ],
    colorValue: 0xFFFF8906,
  ),
  BlockPrototype(
    id: 'meteor_square',
    shape: [
      [1, 1],
      [1, 1],
    ],
    colorValue: 0xFF3E76F6,
  ),
  BlockPrototype(
    id: 'comet_s',
    shape: [
      [0, 1, 1],
      [1, 1, 0],
    ],
    colorValue: 0xFF90E0EF,
  ),
  BlockPrototype(
    id: 'satellite_hook',
    shape: [
      [1, 1, 0],
      [0, 1, 1],
    ],
    colorValue: 0xFFEF476F,
  ),
  BlockPrototype(
    id: 'crystal_single',
    shape: [
      [1],
    ],
    colorValue: 0xFFE5C3FF,
  ),
  BlockPrototype(
    id: 'galaxy_plus',
    shape: [
      [0, 1, 0],
      [1, 1, 1],
      [0, 1, 0],
    ],
    colorValue: 0xFF5CE1E6,
  ),
];
