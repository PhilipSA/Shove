import 'package:flutter/material.dart';
import 'package:shove/ai/abstraction/i_ai.dart';
import 'package:shove/cellula/cellula_foundation/cellula_tokens.dart';
import 'package:shove/game_objects/shove_game.dart';
import 'package:shove/game_objects/shove_game_move.dart';
import 'package:shove/game_objects/shove_square.dart';
import 'package:shove/ui/game_board_widget/dragable_square_widget.dart';

class ShoveBoardWidget extends StatefulWidget {
  final ShoveGame game;

  const ShoveBoardWidget({required this.game, super.key});

  @override
  createState() => _ShoveBoardWidgetState();
}

class _ShoveBoardWidgetState extends State<ShoveBoardWidget> {
  // ignore: unused_field
  var _hasChanged = false;

  @override
  void initState() {
    super.initState();

    final bothPlayersAreAi =
        widget.game.player1 is IAi && widget.game.player2 is IAi;

    if (bothPlayersAreAi) {
      processAiGame();
    }
  }

  Future<void> processAiGame() async {
    if (widget.game.isGameOver) return;

    await widget.game.procceedGameState();

    setState(() {
      _hasChanged = true;
    });

    if (!widget.game.isGameOver) {
      await Future.delayed(Durations.short1);
      processAiGame();
    }
  }

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
                : CellulaTokens.none().primary.c500;

            final currentSquare = widget.game.getSquareByXY(row, col);
            final currentPiece = currentSquare.piece;

            final hasPiece = currentPiece != null;
            final isDraggable = hasPiece &&
                currentPiece.owner == widget.game.currentPlayersTurn &&
                !currentPiece.isIncapacitated;

            return DragTarget<ShoveSquare>(
              builder: (_, a, b) {
                return Stack(children: [
                  Container(
                    color: color,
                  ),
                  DragableSquareWidget(
                      color: color,
                      isDraggable: isDraggable,
                      shoveSquare: currentSquare,
                      onDragStarted: () {},
                      onDragCompleted: () => {},
                      onDraggableCanceled: (_, a) {},
                      onDraggableFeedback: () => {},
                      child: currentPiece != null
                          ? currentPiece.texture
                          : Container()),
                  if (currentPiece?.isIncapacitated ?? false)
                    Text('XX',
                        style: TextStyle(color: Colors.pink.withOpacity(0.5))),
                ]);
              },
              onWillAccept: (draggedSquare) {
                final result =
                    widget.game.validateMove(draggedSquare!, currentSquare);
                return result;
              },
              onAccept: (data) async {
                await widget.game.move(ShoveGameMove(data, currentSquare));
                await widget.game.procceedGameState();

                setState(() {
                  _hasChanged = true;
                });
              },
              onMove: (_) {},
            );
          }),
    );
  }
}
