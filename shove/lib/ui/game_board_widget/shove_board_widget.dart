import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shove/ai/abstraction/i_ai.dart';
import 'package:shove/audio/shove_audio_player.dart';
import 'package:shove/cellula/cellula_foundation/cellula_foundation.dart';
import 'package:shove/cellula/cellula_foundation/cellula_tokens.dart';
import 'package:shove/cellula/cellula_foundation/components/cellula_button.dart';
import 'package:shove/cellula/cellula_foundation/wrappers/cellula_app_bar.dart';
import 'package:shove/cellula/cellula_foundation/wrappers/cellula_text.dart';
import 'package:shove/game_objects/game_state/shove_game_evaluator.dart';
import 'package:shove/game_objects/shove_game.dart';
import 'package:shove/game_objects/shove_game_move.dart';
import 'package:shove/game_objects/shove_square.dart';
import 'package:shove/interactor/shove_game_interactor.dart';
import 'package:shove/ui/game_board_widget/dragable_square_widget.dart';
import 'package:shove/ui/game_board_widget/evaluation_bar_widget.dart';
import 'package:shove/ui/game_board_widget/player_names.widget.dart';
import 'package:shove/ui/game_board_widget/timer_widget.dart';

class ShoveBoardWidget extends StatefulWidget {
  final ShoveGame game;
  final ShoveGameEvaluator evaluator = const ShoveGameEvaluator();

  const ShoveBoardWidget({required this.game, super.key});

  @override
  createState() => _ShoveBoardWidgetState();
}

class _ShoveBoardWidgetState extends State<ShoveBoardWidget> {
  late final ShoveGameInteractor _shoveGameInteractor;

  // ignore: unused_field
  var _hasChanged = false;
  ShoveGameMove? _onGoingMove;

  @override
  void initState() {
    super.initState();

    _shoveGameInteractor = ShoveGameInteractor(widget.game);

    final bothPlayersAreAi =
        widget.game.player1 is IAi && widget.game.player2 is IAi;

    if (bothPlayersAreAi) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        _shoveGameInteractor.processAiGame();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: cellulaAppBar(
        cellulaTokens: CellulaTokens.none(),
        title:
            widget.game.isGameOver ? 'GG' : 'Shove 2.0 Remaster Final Edition',
        onNavBackPressed: () {
          Navigator.pop(context);
        },
      ),
      body: MultiProvider(
        providers: [
          ChangeNotifierProvider.value(
              value: _shoveGameInteractor.shoveGameEvaluationState),
          ChangeNotifierProvider.value(
              value: _shoveGameInteractor.shoveGameMoveState),
        ],
        child: Row(
          children: [
            Flexible(
              flex: 5,
              child: AspectRatio(
                aspectRatio: 1,
                child: ChangeNotifierProvider.value(
                  value: _shoveGameInteractor.shoveGameMoveState,
                  child: Consumer<ShoveGameMoveState>(
                    builder: (context, shoveGameMoveState, _) {
                      return GridView.builder(
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: ShoveGame.totalNumberOfRows,
                          ),
                          itemCount: ShoveGame.totalNumberOfColumns *
                              ShoveGame.totalNumberOfRows,
                          itemBuilder: (context, index) {
                            int row = index ~/ ShoveGame.totalNumberOfRows;
                            int col = index % ShoveGame.totalNumberOfColumns;
                            Color color = (row.isEven && col.isEven) ||
                                    (row.isOdd && col.isOdd)
                                ? Colors.white
                                : CellulaTokens.none().primary.c500;

                            final currentSquare =
                                widget.game.getSquareByXY(row, col);
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
                                .shoveSquareIsValidTargetForThrow(
                                    currentSquare);

                            final isDraggable = isThrowerTarget.isValid ||
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
                                            currentSquare,
                                            currentSquare,
                                            widget.game.currentPlayersTurn,
                                            throwerSquare: isThrowerTarget
                                                    .isValid
                                                ? isThrowerTarget.throwerSquare
                                                : null);
                                      },
                                      onDragCompleted: () {
                                        _onGoingMove = null;
                                      },
                                      onDraggableCanceled: (_, a) {},
                                      onDraggableFeedback: () => {},
                                      child: currentPiece != null
                                          ? currentPiece.texture
                                          : Container()),
                                  Text('${currentSquare.x}, ${currentSquare.y}',
                                      style: TextStyle(
                                          color: Colors.pink.withOpacity(0.5))),
                                  if (currentPiece?.isIncapacitated ?? false)
                                    Text('XX',
                                        style: TextStyle(
                                            color:
                                                Colors.pink.withOpacity(0.5))),
                                ]);
                              },
                              onWillAccept: (draggedSquare) {
                                if (_onGoingMove == null) return false;
                                _onGoingMove = ShoveGameMove(
                                    _onGoingMove!.oldSquare,
                                    currentSquare,
                                    widget.game.currentPlayersTurn,
                                    throwerSquare: _onGoingMove!.throwerSquare);
                                final result =
                                    widget.game.validateMove(_onGoingMove!);
                                return result;
                              },
                              onAccept: (data) async {
                                _onGoingMove = ShoveGameMove(
                                    _onGoingMove!.oldSquare,
                                    currentSquare,
                                    widget.game.currentPlayersTurn,
                                    throwerSquare: _onGoingMove!.throwerSquare);
                                final audioToPlay =
                                    await widget.game.move(_onGoingMove!);

                                setState(() {
                                  _hasChanged = true;
                                });

                                if (audioToPlay != null) {
                                  await ShoveAudioPlayer().play(audioToPlay);
                                }

                                WidgetsBinding.instance
                                    .addPostFrameCallback((_) async {
                                  await _shoveGameInteractor
                                      .onProcceedGameState();
                                });
                              },
                              onMove: (_) {},
                            );
                          });
                    },
                  ),
                ),
              ),
            ),
            Flexible(
              child: Padding(
                padding: EdgeInsets.all(CellulaSpacing.x2.spacing),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    CellulaText(
                        text:
                            '${widget.game.pieces.where((element) => element.owner == widget.game.player2).length.toString()} pieces left',
                        color: CellulaTokens.none().content.defaultColor,
                        fontVariant: CellulaFontHeading.xSmall.fontVariant),
                    PlayerTextBadge(widget.game.player2.playerName),
                    const Divider(),
                    const Flexible(child: TimerWidget()),
                    Flexible(
                      child: CellulaText(
                        text:
                            'Make a move: ${widget.game.currentPlayersTurn.playerName}',
                        color: CellulaTokens.none().content.defaultColor,
                        fontVariant: CellulaFontHeading.small.fontVariant,
                      ),
                    ),
                    CellulaButton(
                      text: 'Undo',
                      buttonVariant: CellulaButtonVariant.secondary(
                          CellulaTokens.none(), CellulaButtonSize.small),
                      onPressed: () {
                        widget.game.undoLastMove();
                        setState(() {
                          _hasChanged = true;
                        });
                      },
                    ),
                    const Divider(),
                    PlayerTextBadge(widget.game.player1.playerName),
                    CellulaText(
                        text:
                            '${widget.game.pieces.where((element) => element.owner == widget.game.player1).length.toString()} pieces left',
                        color: CellulaTokens.none().content.defaultColor,
                        fontVariant: CellulaFontHeading.xSmall.fontVariant),
                    const Divider(),
                    EvaluationBarWidget(
                        shoveGameEvaluationState:
                            _shoveGameInteractor.shoveGameEvaluationState),
                  ],
                ),
              ),
            )
          ],
        ),
      ),
    );
  }
}
