enum PieceType {
  shover(2),
  thrower(4),
  blocker(2),
  leaper(3),
  charger(4),
  hook(4);

  final int pieceValue;

  const PieceType(this.pieceValue);
}
