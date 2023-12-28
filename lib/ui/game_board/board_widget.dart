import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shove/ai/abstraction/i_ai.dart';
import 'package:shove/cellula/cellula_foundation/cellula_tokens.dart';
import 'package:shove/game_objects/shove_game.dart';
import 'package:shove/game_objects/shove_game_move.dart';
import 'package:shove/game_objects/shove_square.dart';
import 'package:shove/interactor/shove_game_interactor.dart';
import 'package:shove/ui/game_board/dragable_square_widget.dart';
import 'package:shove/ui/game_board/evaluation_bar_widget.dart';

class BoardWidget extends StatefulWidget {
  final ShoveGameMoveState shoveGameMoveState;
  final ShoveGameEvaluationState shoveGameEvaluationState;
  final ShoveGame game;
  final bool showDebugInfo;
  final ValueNotifier<bool> displayEvaluationBar;
  final Function(ShoveGameMove) onMove;

  const BoardWidget(
      {Key? key,
      required this.shoveGameMoveState,
      required this.game,
      required this.shoveGameEvaluationState,
      required this.onMove,
      required this.displayEvaluationBar,
      required this.showDebugInfo})
      : super(key: key);

  @override
  createState() => _BoardWidgetState();
}

class _BoardWidgetState extends State<BoardWidget> {
  ShoveGameMove? _onGoingMove;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Flexible(
          flex: 0,
          child: ValueListenableBuilder(
              valueListenable: widget.displayEvaluationBar,
              builder: (BuildContext context, value, child) {
                return Visibility(
                  visible: value,
                  child: EvaluationBarWidget(
                      shoveGameEvaluationState:
                          widget.shoveGameEvaluationState),
                );
              }),
        ),
        Flexible(
          flex: 2,
          child: ChangeNotifierProvider.value(
            value: widget.shoveGameMoveState,
            child: Consumer<ShoveGameMoveState>(
              builder: (context, shoveGameMoveState, _) {
                return GridView.builder(
                    shrinkWrap: true,
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: ShoveGame.totalNumberOfRows + 2,
                    ),
                    itemCount: (ShoveGame.totalNumberOfColumns + 2) *
                        (ShoveGame.totalNumberOfRows + 2),
                    itemBuilder: (context, index) {
                      int row = index ~/ (ShoveGame.totalNumberOfRows + 2) - 1;
                      int col =
                          index % (ShoveGame.totalNumberOfColumns + 2) - 1;
                      Color color =
                          (row.isEven && col.isEven) || (row.isOdd && col.isOdd)
                              ? Colors.white
                              : CellulaTokens.none().primary.c500;

                      var currentSquare = widget.game.getSquareByXY(row, col);

                      if (currentSquare == null) {
                        return DragTarget<ShoveSquare>(
                            builder: (_, a, b) {
                              return Container(
                                color: Colors.amberAccent.withAlpha(90),
                              );
                            },
                            onWillAccept: (_) => true,
                            onAccept: (_) {
                              _onGoingMove = ShoveGameMove(
                                  _onGoingMove!.oldSquare,
                                  ShoveSquare(-1, -1, null),
                                  widget.game.currentPlayersTurn,
                                  throwerSquare: _onGoingMove!.throwerSquare);

                              widget.onMove(_onGoingMove!);
                            });
                      }

                      final currentPiece = currentSquare!.piece;

                      final hasPiece = currentPiece != null;

                      final isThrowerTarget = widget.game
                          .shoveSquareIsValidTargetForThrow(currentSquare);

                      final isDraggable = isThrowerTarget.isValid ||
                          (hasPiece &&
                              currentPiece.owner ==
                                  widget.game.currentPlayersTurn &&
                              !currentPiece.isIncapacitated &&
                              currentPiece.owner is! IAi);

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
                                      currentSquare,
                                      currentSquare,
                                      widget.game.currentPlayersTurn,
                                      throwerSquare: isThrowerTarget.isValid
                                          ? isThrowerTarget.throwerSquare
                                          : null);
                                },
                                onDragCompleted: () {
                                  _onGoingMove = null;
                                },
                                onDraggableCanceled: (_, a) {},
                                onDraggableFeedback: () => {},
                                child: currentPiece != null
                                    ? currentPiece.texture!
                                    : Container()),
                            if (widget.showDebugInfo)
                              Text('${currentSquare.x}, ${currentSquare.y}',
                                  style: TextStyle(
                                      color: Colors.pink.withOpacity(0.5))),
                            if (currentPiece?.isIncapacitated ?? false)
                              Text('XX',
                                  style: TextStyle(
                                      color: Colors.pink.withOpacity(0.5))),
                          ]);
                        },
                        onWillAccept: (draggedSquare) {
                          if (_onGoingMove == null) return false;
                          _onGoingMove = ShoveGameMove(_onGoingMove!.oldSquare,
                              currentSquare, widget.game.currentPlayersTurn,
                              throwerSquare: _onGoingMove!.throwerSquare);
                          final result =
                              widget.game.validateMove(_onGoingMove!);
                          return result;
                        },
                        onAccept: (data) async {
                          _onGoingMove = ShoveGameMove(_onGoingMove!.oldSquare,
                              currentSquare, widget.game.currentPlayersTurn,
                              throwerSquare: _onGoingMove!.throwerSquare);

                          widget.onMove(_onGoingMove!);
                        },
                        onMove: (_) {},
                      );
                    });
              },
            ),
          ),
        ),
      ],
    );
  }
}
