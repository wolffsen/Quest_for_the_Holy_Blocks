import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../controllers/game_controller.dart';
import '../../models/block_piece.dart';
import '../../models/piece_drag_payload.dart';

final _dropPreviewProvider = StateProvider<_DropPreview?>((ref) => null);
final boardCellSizeProvider = StateProvider<double>((ref) => 24);

// Hover lift rows + a few extra so bottom rows stay reachable.
const _ghostRows = kHoverLiftCells + 3;

class _DropPreview {
  const _DropPreview({
    required this.piece,
    required this.anchorRow,
    required this.anchorCol,
  });

  final BlockPiece piece;
  final int anchorRow;
  final int anchorCol;

  bool covers(int row, int col) {
    final localRow = row - anchorRow;
    final localCol = col - anchorCol;
    if (localRow < 0 || localCol < 0) return false;
    if (localRow >= piece.height || localCol >= piece.width) return false;
    return piece.cells[localRow][localCol] == 1;
  }
}

class GameBoard extends ConsumerWidget {
  const GameBoard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(gameControllerProvider);
    final controller = ref.read(gameControllerProvider.notifier);
    final board = state.board;
    final size = board.length;
    final theme = state.theme;
    final preview = ref.watch(_dropPreviewProvider);
    final hintSuggestion = state.hint;
    final hintPiece =
        hintSuggestion != null ? _findPiece(state.activePieces, hintSuggestion.pieceId) : null;

    if (state.isPaused) {
      return AspectRatio(
        aspectRatio: 1,
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: theme.boardBorderColor, width: 2),
            gradient: theme.boardGradient,
          ),
          child: const Center(
            child: Icon(Icons.pause, size: 48, color: Colors.white54),
          ),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        // Fit: boardPixels + ghostHeight <= maxHeight
        final maxWidth = constraints.maxWidth;
        final maxHeight = constraints.maxHeight.isFinite
            ? constraints.maxHeight
            : maxWidth * (1 + _ghostRows / size.toDouble());

        final boardPixelsFromHeight =
            maxHeight / (1 + _ghostRows / size.toDouble());
        final boardPixels = math.min(maxWidth, boardPixelsFromHeight);

        final cellSize = boardPixels / size;
        final ghostHeight = cellSize * _ghostRows;
        final totalHeight = boardPixels + ghostHeight;

        ref.read(boardCellSizeProvider.notifier).state = cellSize;

        DragTarget<PieceDragPayload> buildTarget({
          required int rawRow,
          required int col,
          required bool paintCell,
        }) {
          // clamp() returns num → cast back to int
          final boardRow = rawRow.clamp(0, size - 1) as int;

          return DragTarget<PieceDragPayload>(
            onWillAcceptWithDetails: (details) {
              final payload = details.data;
              final piece = _findPiece(state.activePieces, payload.pieceId);
              if (piece == null) return false;

              // Finger is kHoverLiftCells BELOW the anchor cell.
              final anchorRow = rawRow - payload.anchorRowOffset - kHoverLiftCells;
              final anchorCol = col - payload.anchorColOffset;

              final maxRow = size - piece.height;
              final maxCol = size - piece.width;

              final clampedRow = anchorRow.clamp(0, maxRow) as int;
              final clampedCol = anchorCol.clamp(0, maxCol) as int;

              final canPlace =
                  controller.canPlace(payload.pieceId, clampedRow, clampedCol);

              ref.read(_dropPreviewProvider.notifier).state = canPlace
                  ? _DropPreview(
                      piece: piece,
                      anchorRow: clampedRow,
                      anchorCol: clampedCol,
                    )
                  : null;

              return canPlace;
            },
            onLeave: (_) {
              ref.read(_dropPreviewProvider.notifier).state = null;
            },
            onAcceptWithDetails: (details) {
              final payload = details.data;
              final piece = _findPiece(state.activePieces, payload.pieceId);
              if (piece == null) return;

              // Only use the hover preview, never recompute from finger.
              final currentPreview = ref.read(_dropPreviewProvider);
              if (currentPreview == null || currentPreview.piece.id != piece.id) {
                return;
              }

              ref.read(_dropPreviewProvider.notifier).state = null;
              controller.placePiece(
                payload.pieceId,
                currentPreview.anchorRow,
                currentPreview.anchorCol,
              );
            },
            builder: (context, candidate, rejected) {
              if (!paintCell) return const SizedBox.expand();

              final cellValue = board[boardRow][col];
              Color? baseColor;
              if (cellValue != null) baseColor = Color(cellValue);
              final occupied = baseColor != null;

              final isPreview = preview?.covers(boardRow, col) ?? false;
              final isHint = !isPreview &&
                  hintSuggestion != null &&
                  hintPiece != null &&
                  hintSuggestion.covers(hintPiece, boardRow, col);

              // Solid block look:
              Color backgroundColor;
              if (isPreview) {
                backgroundColor =
                    theme.dropHighlightColor.withValues(alpha: 0.4);
              } else if (isHint) {
                backgroundColor =
                    theme.dropHighlightColor.withValues(alpha: 0.22);
              } else if (occupied) {
                backgroundColor = baseColor!;
              } else {
                backgroundColor = theme.emptyCellColor;
              }

              return AnimatedContainer(
                duration: const Duration(milliseconds: 120),
                decoration: BoxDecoration(
                  color: backgroundColor,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: occupied ? Colors.white24 : Colors.white10,
                    width: occupied ? 1.2 : 0.8,
                  ),
                  boxShadow: occupied
                      ? [
                          BoxShadow(
                            color: baseColor!.withValues(alpha: 0.45),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : null,
                ),
              );
            },
          );
        }

        // Visible 9x9 board
        final boardGrid = Container(
          width: boardPixels,
          height: boardPixels,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: theme.boardBorderColor, width: 2),
            boxShadow: [
              BoxShadow(
                color: theme.boardShadowColor,
                blurRadius: 18,
                spreadRadius: 2,
              ),
            ],
            gradient: theme.boardGradient,
          ),
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              for (var row = 0; row < size; row++)
                Expanded(
                  child: Row(
                    children: [
                      for (var col = 0; col < size; col++)
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.all(1.5),
                            child: buildTarget(
                              rawRow: row,
                              col: col,
                              paintCell: true,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
            ],
          ),
        );

        // Ghost hit area below board (not drawn)
        final ghostOverlay = Positioned(
          left: 0,
          right: 0,
          top: boardPixels,
          height: ghostHeight,
          child: Column(
            children: [
              for (var ghost = 0; ghost < _ghostRows; ghost++)
                SizedBox(
                  height: cellSize,
                  child: Row(
                    children: [
                      for (var col = 0; col < size; col++)
                        SizedBox(
                          width: cellSize,
                          height: cellSize,
                          child: buildTarget(
                            rawRow: size + ghost,
                            col: col,
                            paintCell: false,
                          ),
                        ),
                    ],
                  ),
                ),
            ],
          ),
        );

        return Align(
          alignment: Alignment.topCenter,
          child: SizedBox(
            width: boardPixels,
            height: totalHeight,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  height: boardPixels,
                  child: boardGrid,
                ),
                ghostOverlay,
              ],
            ),
          ),
        );
      },
    );
  }
}

BlockPiece? _findPiece(List<BlockPiece> pieces, String id) {
  for (final piece in pieces) {
    if (piece.id == id) return piece;
  }
  return null;
}
