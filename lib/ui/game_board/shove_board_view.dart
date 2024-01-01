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
import 'package:shove/interactor/shove_game_interactor.dart';
import 'package:shove/ui/game_board/board_widget.dart';
import 'package:shove/ui/game_board/player_names.widget.dart';
import 'package:shove/ui/game_board/timer_widget.dart';

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
                child: BoardWidget(
                    shoveGameMoveState: _shoveGameInteractor.shoveGameMoveState,
                    game: widget.game,
                    shoveGameEvaluationState:
                        _shoveGameInteractor.shoveGameEvaluationState,
                    onMove: (move) async {
                      await _shoveGameInteractor.makeMove(move);
                    },
                    displayEvaluationBar: _displayEvaluationBar,
                    showDebugInfo: widget.showDebugInfo),
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
                              '${widget.game.pieces.values.where((element) => element.owner == widget.game.player2).length.toString()} pieces left',
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
                              '${widget.game.pieces.values.where((element) => element.owner == widget.game.player1).length.toString()} pieces left',
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
