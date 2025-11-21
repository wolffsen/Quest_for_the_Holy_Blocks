const int kHoverLiftCells = 3;

class PieceDragPayload {
  const PieceDragPayload(
    this.pieceId, {
    this.anchorRowOffset = 0,
    this.anchorColOffset = 0,
  });

  final String pieceId;
  final int anchorRowOffset;
  final int anchorColOffset;
}
