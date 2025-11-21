import 'package:flutter/material.dart';

class BlockPiece {
  BlockPiece({
    required this.id,
    required List<List<int>> cells,
    required this.colorValue,
  }) : cells = _cloneCells(cells);

  final String id;
  final List<List<int>> cells;
  final int colorValue;

  BlockPiece copyWith({
    String? id,
    List<List<int>>? cells,
    int? colorValue,
  }) {
    return BlockPiece(
      id: id ?? this.id,
      cells: cells ?? this.cells,
      colorValue: colorValue ?? this.colorValue,
    );
  }

  factory BlockPiece.fromJson(Map<String, dynamic> json) {
    return BlockPiece(
      id: json['id'] as String,
      cells: (json['cells'] as List<dynamic>? ?? const [])
          .map<List<int>>(
            (row) => (row as List<dynamic>)
                .map((cell) => cell as int)
                .toList(growable: false),
          )
          .toList(growable: false),
      colorValue: json['colorValue'] as int,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'cells':
            cells.map((row) => List<int>.from(row)).toList(growable: false),
        'colorValue': colorValue,
      };

  static List<List<int>> _cloneCells(List<List<int>> source) => [
        for (final row in source) List<int>.from(row, growable: false),
      ];
}

extension BlockPieceX on BlockPiece {
  int get width => cells.isEmpty ? 0 : cells.first.length;
  int get height => cells.length;
  Color get color => Color(colorValue);

  BlockPiece rotateClockwise() {
    if (cells.isEmpty || cells.first.isEmpty) {
      return this;
    }
    final rotated = List.generate(
      width,
      (_) => List<int>.filled(height, 0, growable: false),
      growable: false,
    );
    for (var y = 0; y < height; y++) {
      for (var x = 0; x < width; x++) {
        rotated[x][height - 1 - y] = cells[y][x];
      }
    }
    return copyWith(cells: rotated);
  }
}
