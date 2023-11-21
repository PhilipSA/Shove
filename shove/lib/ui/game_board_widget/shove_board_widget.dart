import 'package:flutter/material.dart';
import 'package:shove/shove_game.dart';
import 'package:shove/shove_square.dart';
import 'package:shove/ui/game_board_widget/dragable_square_widget.dart';

class ShoveBoardWidget extends StatefulWidget {
  final ShoveGame game;

  const ShoveBoardWidget({required this.game, super.key});

  @override
  createState() => _ShoveBoardWidgetState();
}

class _ShoveBoardWidgetState extends State<ShoveBoardWidget> {
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

            final currentSquare = widget.game.board[row][col];
            final currentPiece = currentSquare.piece;

            final hasPiece = currentPiece != null;

            return DragTarget<ShoveSquare>(
              builder: (_, a, b) {
                return Stack(children: [
                  Container(
                    color: color,
                  ),
                  DragableSquareWidget(
                      color: color,
                      isDraggable: hasPiece,
                      shoveSquare: currentSquare,
                      onDragStarted: () {},
                      onDragCompleted: () => {},
                      onDraggableCanceled: (_, a) {},
                      onDraggableFeedback: () => {},
                      child: currentPiece?.texture ?? Container())
                ]);
              },
              onWillAccept: (draggedSquare) {
                final result =
                    widget.game.validateMove(draggedSquare!, currentSquare);
                print('$draggedSquare');
                print('$draggedSquare');
                print('$currentSquare');
                return result;
              },
              onAccept: (data) {
                print('test accept');
              },
              onMove: (_) {},
            );
          }),
    );
  }
}
