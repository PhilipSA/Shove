abstract class IGameState {
  final IPlayer player1;
  final IPlayer player2;
  final List<List<IPiece>> board;
  final bool isWhiteTurn;
  final bool isCheck;
  final bool isCheckmate;
  final bool isStalemate;
  final bool isDraw;
  final bool isGameOver;

  IGameState(
      this.player1,
      this.player2,
      this.board,
      this.isWhiteTurn,
      this.isCheck,
      this.isCheckmate,
      this.isStalemate,
      this.isDraw,
      this.isGameOver);
}
