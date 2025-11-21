import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../controllers/game_controller.dart';
import '../../models/block_piece.dart';
import '../../models/game_theme.dart';
import '../../models/piece_drag_payload.dart' show PieceDragPayload, kHoverLiftCells;
import 'game_board.dart' show boardCellSizeProvider;

class PieceTray extends ConsumerWidget {
  const PieceTray({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(gameControllerProvider);
    final controller = ref.read(gameControllerProvider.notifier);
    final theme = state.theme;
    final cellSizeRaw = ref.watch(boardCellSizeProvider);
    final cellSize = cellSizeRaw <= 0 ? 24.0 : cellSizeRaw;

    if (state.activePieces.isEmpty) {
      return Center(
        child: Text(
          state.isGameOver ? 'Board Locked' : 'Drawing new star-bridges...',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.only(top: 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            theme.chipBackgroundColor.withValues(alpha: 0.98),
            theme.chipBackgroundColor.withValues(alpha: 0.94),
          ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.4),
            blurRadius: 18,
            spreadRadius: 2,
            offset: const Offset(0, -6),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _TrayHeader(theme: theme),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: cellSize * 4.5,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  for (final piece in state.activePieces)
                    Flexible(
                      fit: FlexFit.loose, // 👈 let the child size itself
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        child: Align(
                          alignment: Alignment.topCenter,
                          child: _PieceDraggable(
                            piece: piece,
                            rotationEnabled: state.rotationEnabled,
                            onRotate: () => controller.rotatePiece(piece.id),
                            enabled: !state.isGameOver && !state.isPaused,
                            theme: theme,
                            cellSize: cellSize,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PieceDraggable extends StatelessWidget {
  const _PieceDraggable({
    required this.piece,
    required this.rotationEnabled,
    required this.onRotate,
    required this.enabled,
    required this.theme,
    required this.cellSize,
  });

  final BlockPiece piece;
  final bool rotationEnabled;
  final VoidCallback onRotate;
  final bool enabled;
  final GameThemeData theme;
  final double cellSize;

  @override
  Widget build(BuildContext context) {
    final anchorRowOffset = piece.height - 1;
    final anchorColOffset = piece.width ~/ 2;

    // Finger is kHoverLiftCells BELOW the piece anchor cell
    // => the piece appears to hover above the finger.
    final anchorOffset = Offset(
      (anchorColOffset + 0.5) * cellSize,
      (anchorRowOffset + 0.5 + kHoverLiftCells) * cellSize,
    );

    final child = _PiecePreview(
      piece: piece,
      glow: true,
      theme: theme,
    );

    return Draggable<PieceDragPayload>(
      data: PieceDragPayload(
        piece.id,
        anchorRowOffset: anchorRowOffset,
        anchorColOffset: anchorColOffset,
      ),
      feedback: Material(
        color: Colors.transparent,
        child: _BoardSizedPiece(
          piece: piece,
          cellSize: cellSize,
          theme: theme,
        ),
      ),
      dragAnchorStrategy: (_, __, ___) => anchorOffset,
      maxSimultaneousDrags: enabled ? 1 : 0,
      childWhenDragging: Opacity(
        opacity: 0.3,
        child: child,
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          child,
          if (rotationEnabled)
            Positioned(
              top: -4,
              right: -4,
              child: _RotateButton(onPressed: enabled ? onRotate : null),
            ),
        ],
      ),
    );
  }
}

class _BoardSizedPiece extends StatelessWidget {
  const _BoardSizedPiece({
    required this.piece,
    required this.cellSize,
    required this.theme,
  });

  final BlockPiece piece;
  final double cellSize;
  final GameThemeData theme;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: piece.width * cellSize,
      height: piece.height * cellSize,
      child: CustomPaint(
        painter: _PiecePainter(piece: piece, theme: theme),
      ),
    );
  }
}

/// PREVIEW CARD UNDER THE ROTATE ICON
class _PiecePreview extends StatelessWidget {
  const _PiecePreview({
    required this.piece,
    required this.theme,
    this.glow = false,
  });

  final BlockPiece piece;
  final GameThemeData theme;
  final bool glow;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            theme.trayGlowColor.withValues(alpha: 0.2),
            theme.chipBackgroundColor.withValues(alpha: 0.4),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
        boxShadow: glow
            ? [
                BoxShadow(
                  color: theme.trayGlowColor.withValues(alpha: 0.7),
                  blurRadius: 12,
                  spreadRadius: 2,
                ),
              ]
            : null,
      ),
      child: AspectRatio(
        aspectRatio: piece.width / piece.height,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final cellSize = constraints.maxWidth / piece.width;

            // IMPORTANT:
            // - Align the whole grid to the TOP-RIGHT of the card.
            // - Rows are also right-aligned.
            // This keeps the rotate icon (top/right of the card)
            // visually “attached” to the piece for all shapes.
            return Align(
              alignment: Alignment.topRight,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  for (var y = 0; y < piece.height; y++)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        for (var x = 0; x < piece.width; x++)
                          Padding(
                            padding: const EdgeInsets.all(1.5),
                            child: AnimatedContainer(
                              duration:
                                  const Duration(milliseconds: 150),
                              width: cellSize - 3,
                              height: cellSize - 3,
                              decoration: BoxDecoration(
                                color: piece.cells[y][x] == 1
                                    ? piece.color
                                    : theme.emptyCellColor,
                                borderRadius: BorderRadius.circular(4),
                                boxShadow: piece.cells[y][x] == 1
                                    ? [
                                        BoxShadow(
                                          color: piece.color
                                              .withValues(alpha: 0.6),
                                          blurRadius: 6,
                                        ),
                                      ]
                                    : null,
                              ),
                            ),
                          ),
                      ],
                    ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _PiecePainter extends CustomPainter {
  const _PiecePainter({
    required this.piece,
    required this.theme,
  });

  final BlockPiece piece;
  final GameThemeData theme;

  @override
  void paint(Canvas canvas, Size size) {
    final cellWidth = size.width / piece.width;
    final cellHeight = size.height / piece.height;
    final paint = Paint()
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;

    for (var y = 0; y < piece.height; y++) {
      for (var x = 0; x < piece.width; x++) {
        if (piece.cells[y][x] != 1) continue;

        final rect = Rect.fromLTWH(
          x * cellWidth + 1,
          y * cellHeight + 1,
          cellWidth - 2,
          cellHeight - 2,
        );

        final rRect = RRect.fromRectAndRadius(rect, const Radius.circular(6));
        final gradient = LinearGradient(
          colors: [
            piece.color.withValues(alpha: 0.95),
            piece.color.withValues(alpha: 0.65),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );

        paint.shader = gradient.createShader(rect);
        canvas.drawRRect(rRect, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _PiecePainter oldDelegate) {
    return oldDelegate.piece != piece || oldDelegate.theme != theme;
  }
}

class _RotateButton extends StatelessWidget {
  const _RotateButton({this.onPressed});

  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withValues(alpha: 0.55),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onPressed,
        child: const Padding(
          padding: EdgeInsets.all(4),
          child: Icon(
            Icons.rotate_90_degrees_ccw,
            size: 16,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}

class _TrayHeader extends StatelessWidget {
  const _TrayHeader({required this.theme});

  final GameThemeData theme;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          'Next Pieces',
          style: textTheme.titleMedium?.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          'Drag to the board',
          style: textTheme.bodySmall?.copyWith(
            color: Colors.white70,
          ),
        ),
      ],
    );
  }
}
