import 'package:flutter/material.dart';
import 'package:shove/shove_game.dart';
import 'package:shove/ui/dragable_square_widget.dart';

class ChessBoardWidget extends StatelessWidget {
  final ShoveGame game;

  const ChessBoardWidget({required this.game, super.key});

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 1,
      child: GridView.builder(
        shrinkWrap: true,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 8,
        ),
        itemCount: 64,
        itemBuilder: (context, index) {
          int row = index ~/ 8;
          int col = index % 8;
          Color color = (row.isEven && col.isEven) || (row.isOdd && col.isOdd)
              ? Colors.white
              : Colors.black;

          final currentPiece = game.board[row][col].piece;

          final hasPiece = currentPiece != null;

          return Stack(children: [
            Container(
              color: color,
            ),
            DragableSquareWidget(
                color: color,
                isDraggable: hasPiece,
                onDragStarted: () => {},
                onDragCompleted: () => {},
                onDraggableCanceled: (_, a) => {},
                onDraggableFeedback: () => {},
                child: currentPiece?.texture ?? Container())
          ]);
        },
      ),
    );
  }
}
