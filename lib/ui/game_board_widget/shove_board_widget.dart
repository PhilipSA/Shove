import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shove/ai/abstraction/i_ai.dart';
import 'package:shove/audio/shove_audio_player.dart';
import 'package:shove/cellula/cellula_foundation/cellula_foundation.dart';
import 'package:shove/cellula/cellula_foundation/cellula_tokens.dart';
import 'package:shove/cellula/cellula_foundation/components/cellula_button.dart';
import 'package:shove/cellula/cellula_foundation/components/cellula_toggle.dart';
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
  final ShoveAudioPlayer musicPlayer;
  final bool showDebugInfo = false;

  const ShoveBoardWidget(
      {required this.game, required this.musicPlayer, super.key});

  @override
  createState() => _ShoveBoardWidgetState();
}

class _ShoveBoardWidgetState extends State<ShoveBoardWidget> {
  late final ShoveGameInteractor _shoveGameInteractor;

  // ignore: unused_field
  var _hasChanged = false;
  ShoveGameMove? _onGoingMove;
  final ValueNotifier<bool> _displayEvaluationBar = ValueNotifier(false);
  final ValueNotifier<bool> _isMusicPlaying = ValueNotifier(true);

  @override
  void initState() {
    super.initState();

    widget.musicPlayer
      ..stop()
      ..play(AssetSource('sounds/music/game_music.mp3'), volume: 0.1);

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
  void dispose() {
    _shoveGameInteractor.dispose();
    widget.musicPlayer.dispose();
    super.dispose();
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
      body: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1000, minHeight: 800),
        child: MultiProvider(
          providers: [
            ChangeNotifierProvider.value(
                value: _shoveGameInteractor.shoveGameEvaluationState),
            ChangeNotifierProvider.value(
                value: _shoveGameInteractor.shoveGameMoveState),
            ChangeNotifierProvider.value(
                value: _shoveGameInteractor.shoveGameOverState)
          ],
          child: Column(
            children: [
              PlayerTextBadge(widget.game.player2.playerName),
              Flexible(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Flexible(
                      flex: 0,
                      child: ValueListenableBuilder(
                          valueListenable: _displayEvaluationBar,
                          builder: (BuildContext context, value, child) {
                            return Visibility(
                              visible: value,
                              child: EvaluationBarWidget(
                                  shoveGameEvaluationState: _shoveGameInteractor
                                      .shoveGameEvaluationState),
                            );
                          }),
                    ),
                    Flexible(
                      flex: 2,
                      child: ChangeNotifierProvider.value(
                        value: _shoveGameInteractor.shoveGameMoveState,
                        child: Consumer<ShoveGameMoveState>(
                          builder: (context, shoveGameMoveState, _) {
                            return GridView.builder(
                                shrinkWrap: true,
                                gridDelegate:
                                    const SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: ShoveGame.totalNumberOfRows,
                                ),
                                itemCount: ShoveGame.totalNumberOfColumns *
                                    ShoveGame.totalNumberOfRows,
                                itemBuilder: (context, index) {
                                  int row =
                                      index ~/ ShoveGame.totalNumberOfRows;
                                  int col =
                                      index % ShoveGame.totalNumberOfColumns;
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
                                                  widget
                                                      .game.currentPlayersTurn,
                                                  throwerSquare:
                                                      isThrowerTarget.isValid
                                                          ? isThrowerTarget
                                                              .throwerSquare
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
                                          Text(
                                              '${currentSquare.x}, ${currentSquare.y}',
                                              style: TextStyle(
                                                  color: Colors.pink
                                                      .withOpacity(0.5))),
                                        if (currentPiece?.isIncapacitated ??
                                            false)
                                          Text('XX',
                                              style: TextStyle(
                                                  color: Colors.pink
                                                      .withOpacity(0.5))),
                                      ]);
                                    },
                                    onWillAccept: (draggedSquare) {
                                      if (_onGoingMove == null) return false;
                                      _onGoingMove = ShoveGameMove(
                                          _onGoingMove!.oldSquare,
                                          currentSquare,
                                          widget.game.currentPlayersTurn,
                                          throwerSquare:
                                              _onGoingMove!.throwerSquare);
                                      final result = widget.game
                                          .validateMove(_onGoingMove!);
                                      return result;
                                    },
                                    onAccept: (data) async {
                                      _onGoingMove = ShoveGameMove(
                                          _onGoingMove!.oldSquare,
                                          currentSquare,
                                          widget.game.currentPlayersTurn,
                                          throwerSquare:
                                              _onGoingMove!.throwerSquare);

                                      await _shoveGameInteractor
                                          .makeMove(_onGoingMove!);
                                    },
                                    onMove: (_) {},
                                  );
                                });
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              PlayerTextBadge(widget.game.player1.playerName),
              Padding(
                padding: EdgeInsets.all(CellulaSpacing.x2.spacing),
                child: Wrap(
                  runAlignment: WrapAlignment.center,
                  alignment: WrapAlignment.spaceAround,
                  children: [
                    Consumer<ShoveGameOverState>(
                        builder: (context, shoveGameOverState, _) {
                      return Visibility(
                        visible: shoveGameOverState.isGameOver,
                        child: CellulaText(
                            text: 'Game Over',
                            color: CellulaTokens.none().content.defaultColor,
                            fontVariant: CellulaFontHeading.xSmall.fontVariant),
                      );
                    }),
                    if (widget.showDebugInfo)
                      CellulaText(
                          text:
                              '${widget.game.pieces.where((element) => element.owner == widget.game.player2).length.toString()} pieces left',
                          color: CellulaTokens.none().content.defaultColor,
                          fontVariant: CellulaFontHeading.xSmall.fontVariant),
                    const Divider(),
                    const TimerWidget(),
                    ChangeNotifierProvider.value(
                        value: _shoveGameInteractor.shoveGameMoveState,
                        child: Consumer<ShoveGameMoveState>(
                            builder: (context, shoveGameMoveState, _) {
                          return CellulaText(
                            text:
                                'Make a move: ${widget.game.currentPlayersTurn.playerName}',
                            color: CellulaTokens.none().content.defaultColor,
                            fontVariant: CellulaFontHeading.small.fontVariant,
                          );
                        })),
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
                    if (widget.showDebugInfo)
                      CellulaText(
                          text:
                              '${widget.game.pieces.where((element) => element.owner == widget.game.player1).length.toString()} pieces left',
                          color: CellulaTokens.none().content.defaultColor,
                          fontVariant: CellulaFontHeading.xSmall.fontVariant),
                  ],
                ),
              ),
              Column(
                mainAxisSize: MainAxisSize.max,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  ValueListenableBuilder(
                      valueListenable: _displayEvaluationBar,
                      builder: (BuildContext context, value, child) {
                        return CellulaToggle(
                          title: 'Toggle eval bar',
                          cellulaTokens: CellulaTokens.none(),
                          value: value,
                          onChanged: (value) {
                            _shoveGameInteractor.isEvalbarEnabled = value;
                            _displayEvaluationBar.value = value;
                          },
                          dense: true,
                        );
                      }),
                  ValueListenableBuilder(
                      valueListenable: _isMusicPlaying,
                      builder: (BuildContext context, value, child) {
                        return CellulaToggle(
                          title: 'Toggle music',
                          cellulaTokens: CellulaTokens.none(),
                          value: _isMusicPlaying.value,
                          onChanged: (value) {
                            if (value) {
                              widget.musicPlayer
                                ..stop()
                                ..play(
                                    AssetSource('sounds/music/game_music.mp3'),
                                    volume: 0.1);
                            } else {
                              widget.musicPlayer.stop();
                            }

                            _isMusicPlaying.value = value;
                          },
                          dense: true,
                        );
                      }),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
