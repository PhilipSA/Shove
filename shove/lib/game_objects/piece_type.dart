enum PieceType {
  shover(2),
  thrower(5),
  blocker(1),
  leaper(3);

  final int pieceValue;

  const PieceType(this.pieceValue);
}
