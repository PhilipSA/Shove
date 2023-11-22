import 'package:flutter/material.dart';
import 'package:shove/ai/abstraction/i_ai.dart';
import 'package:shove/cellula/cellula_foundation/cellula_tokens.dart';
import 'package:shove/cellula/cellula_foundation/wrappers/cellula_app_bar.dart';
import 'package:shove/game_objects/shove_game.dart';
import 'package:shove/game_objects/shove_game_move.dart';
import 'package:shove/game_objects/shove_game_move_type.dart';
import 'package:shove/game_objects/shove_square.dart';
import 'package:shove/ui/game_board_widget/dragable_square_widget.dart';
import 'package:shove/ui/game_board_widget/player_names.widget.dart';

class ShoveBoardWidget extends StatefulWidget {
  final ShoveGame game;

  const ShoveBoardWidget({required this.game, super.key});

  @override
  createState() => _ShoveBoardWidgetState();
}

class _ShoveBoardWidgetState extends State<ShoveBoardWidget> {
  // ignore: unused_field
  var _hasChanged = false;
  ShoveGameMove? _onGoingMove;

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
    return Scaffold(
      appBar: cellulaAppBar(
        cellulaTokens: CellulaTokens.none(),
        title: 'Shove 2.0 Remaster Final Edition',
        onNavBackPressed: () {
          Navigator.pop(context);
        },
      ),
      body: Row(
        children: [
          AspectRatio(
            aspectRatio: 1,
            child: GridView.builder(
                shrinkWrap: true,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: ShoveGame.totalNumberOfRows,
                ),
                itemCount: ShoveGame.totalNumberOfColumns *
                    ShoveGame.totalNumberOfRows,
                itemBuilder: (context, index) {
                  int row = index ~/ ShoveGame.totalNumberOfRows;
                  int col = index % ShoveGame.totalNumberOfColumns;
                  Color color =
                      (row.isEven && col.isEven) || (row.isOdd && col.isOdd)
                          ? Colors.white
                          : CellulaTokens.none().primary.c500;

                  final currentSquare = widget.game.getSquareByXY(row, col);
                  final currentPiece = currentSquare!.piece;

                  final isEdgeSquare = row == 0 ||
                      row == ShoveGame.totalNumberOfRows - 1 ||
                      col == 0 ||
                      col == ShoveGame.totalNumberOfColumns - 1;

                  if (isEdgeSquare) {
                    color = Colors.orange.withOpacity(0.1);
                  }

                  final hasPiece = currentPiece != null;

                  final isThrowerTarget = widget.game
                      .shoveSquareIsValidTargetForThrow(currentSquare);

                  final isDraggable = isThrowerTarget ||
                      (hasPiece &&
                          currentPiece.owner ==
                              widget.game.currentPlayersTurn &&
                          !currentPiece.isIncapacitated);

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
                            onDragStarted: () {
                              _onGoingMove = ShoveGameMove(
                                  currentSquare, currentSquare,
                                  shoveGameMoveType: isThrowerTarget
                                      ? ShoveGameMoveType.thrown
                                      : ShoveGameMoveType.move);
                            },
                            onDragCompleted: () {
                              _onGoingMove = null;
                            },
                            onDraggableCanceled: (_, a) {},
                            onDraggableFeedback: () => {},
                            child: currentPiece != null
                                ? currentPiece.texture
                                : Container()),
                        if (currentPiece?.isIncapacitated ?? false)
                          Text('XX',
                              style: TextStyle(
                                  color: Colors.pink.withOpacity(0.5))),
                      ]);
                    },
                    onWillAccept: (draggedSquare) {
                      if (_onGoingMove == null) return false;
                      _onGoingMove = ShoveGameMove(
                          _onGoingMove!.oldSquare, currentSquare,
                          shoveGameMoveType: _onGoingMove!.shoveGameMoveType);
                      final result = widget.game.validateMove(_onGoingMove!);
                      return result;
                    },
                    onAccept: (data) async {
                      _onGoingMove = ShoveGameMove(
                          _onGoingMove!.oldSquare, currentSquare,
                          shoveGameMoveType: _onGoingMove!.shoveGameMoveType);
                      await widget.game.move(_onGoingMove!);
                      await widget.game.procceedGameState();

                      setState(() {
                        _hasChanged = true;
                      });
                    },
                    onMove: (_) {},
                  );
                }),
          ),
          Column(
            children: [
              PlayerTextBox(widget.game.player1.playerName),
              PlayerTextBox(widget.game.player2.playerName)
            ],
          )
        ],
      ),
    );
  }
}
