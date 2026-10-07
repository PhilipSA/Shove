import 'package:flutter/material.dart';
import 'package:shove/ai/alpha_zero/alpha_zero_ai.dart';
import 'package:shove/ai/alpha_zero/alpha_zero_model.dart';
import 'package:shove/ai/min_max/min_max_ai.dart';
import 'package:shove/ai/random_ai.dart';
import 'package:shove/audio/shove_audio_player.dart';
import 'package:shove/cellula/cellula_foundation/cellula_foundation.dart';
import 'package:shove/cellula/cellula_foundation/cellula_tokens.dart';
import 'package:shove/cellula/cellula_foundation/components/cellula_button.dart';
import 'package:shove/cellula/cellula_foundation/components/cellula_textinput.dart';
import 'package:shove/game_objects/abstraction/i_player.dart';
import 'package:shove/game_objects/shove_game.dart';
import 'package:shove/game_objects/shove_player.dart';
import 'package:shove/ui/game_board/shove_board_view.dart';
import 'package:shove/ui/play/model_file_picker.dart';

enum _SelectablePlayerTypes { shovePlayer, minMaxAi, randomAi, alphaZeroAi }

class PlayersWidget extends StatefulWidget {
  final ShoveAudioPlayer audioPlayer;
  final ShoveAudioPlayerFactory createAudioPlayer;

  /// Reads an AlphaZero weights file from the user's disk.
  final Future<PickedModelFile?> Function() pickModelFile;

  const PlayersWidget(
    this.audioPlayer, {
    this.createAudioPlayer = ShoveAudioPlayer.new,
    this.pickModelFile = pickAlphaZeroModelFile,
    super.key,
  });

  @override
  State<PlayersWidget> createState() => _PlayersWidgetState();
}

class _PlayersWidgetState extends State<PlayersWidget> {
  final playerOne = TextEditingController();
  final playerTwo = TextEditingController();
  String? playerOneErrorText;
  String? playerTwoErrorText;

  _SelectablePlayerTypes player1Type = _SelectablePlayerTypes.shovePlayer;
  _SelectablePlayerTypes player2Type = _SelectablePlayerTypes.shovePlayer;

  // Uploaded AlphaZero models, kept per side so two checkpoints can play each other.
  final _models = <bool, AlphaZeroModel>{};
  final _modelErrors = <bool, String>{};
  final _modelPicks = <bool, int>{};

  bool _needsModel(bool isPlayerOne) =>
      (isPlayerOne ? player1Type : player2Type) ==
          _SelectablePlayerTypes.alphaZeroAi &&
      _models[isPlayerOne] == null;

  bool get _canStart => !_needsModel(true) && !_needsModel(false);

  Future<void> _uploadModel(bool isPlayerOne) async {
    final pick = _modelPicks[isPlayerOne] = (_modelPicks[isPlayerOne] ?? 0) + 1;
    AlphaZeroModel? model;
    String? error;
    try {
      final file = await widget.pickModelFile();
      if (file == null) return;
      model = AlphaZeroModel.parse(file.name, file.text);
    } on FormatException catch (e) {
      error = e.message;
    } catch (e) {
      error = '$e';
    }
    // A newer pick for the same side wins.
    if (!mounted || pick != _modelPicks[isPlayerOne]) return;
    setState(() {
      if (model != null) {
        _models[isPlayerOne] = model;
        _modelErrors.remove(isPlayerOne);
      } else {
        _models.remove(isPlayerOne);
        _modelErrors[isPlayerOne] = error!;
      }
    });
  }

  @override
  void dispose() {
    // Clean up the controller when the widget is disposed.
    playerOne.dispose();
    playerTwo.dispose();
    super.dispose();
  }

  IPlayer getPlayerFromType(_SelectablePlayerTypes type, bool isPlayerOne) {
    if (type == _SelectablePlayerTypes.shovePlayer) {
      return ShovePlayer(
        isPlayerOne ? playerOne.value.text : playerTwo.value.text,
        isPlayerOne,
      );
    } else if (type == _SelectablePlayerTypes.minMaxAi) {
      return MinMaxAi(
        isPlayerOne ? playerOne.value.text : playerTwo.value.text,
        isPlayerOne,
      );
    } else if (type == _SelectablePlayerTypes.randomAi) {
      return RandomAi(
        isPlayerOne ? playerOne.value.text : playerTwo.value.text,
        isPlayerOne,
      );
    } else if (type == _SelectablePlayerTypes.alphaZeroAi) {
      return AlphaZeroAi.withModel(
        isPlayerOne ? playerOne.value.text : playerTwo.value.text,
        isPlayerOne,
        _models[isPlayerOne]!,
      );
    } else {
      return ShovePlayer(
        isPlayerOne ? playerOne.value.text : playerTwo.value.text,
        isPlayerOne,
      );
    }
  }

  void onStartClick() {
    if (!_canStart) {
      setState(() {
        for (final side in [true, false]) {
          if (_needsModel(side)) {
            _modelErrors[side] ??= 'Upload an AlphaZero model first.';
          }
        }
      });
      return;
    }
    IPlayer player1 = getPlayerFromType(player1Type, true);
    IPlayer player2 = getPlayerFromType(player2Type, false);

    if (playerOne.value.text.isEmpty || playerTwo.value.text.isEmpty) {
      setState(() {
        playerOneErrorText = 'Name can not be empty';
        playerTwoErrorText = 'Name can not be empty';
      });
    } else {
      final shoveGame = ShoveGame(player1, player2);
      widget.audioPlayer.stop();
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ShoveBoardWidget(
            musicPlayer: widget.createAudioPlayer(playerId: 'game_music'),
            createAudioPlayer: widget.createAudioPlayer,
            game: shoveGame,
          ),
        ),
      );
    }
  }

  Widget playerSelectionDropDown(
    _SelectablePlayerTypes selectedType,
    bool isPlayerOne,
  ) {
    return DropdownButton<_SelectablePlayerTypes>(
      isExpanded: true,
      value: selectedType,
      icon: const Icon(Icons.arrow_downward),
      iconSize: 24,
      elevation: 16,
      style: const TextStyle(color: Colors.deepPurple),
      underline: Container(height: 2, color: Colors.deepPurpleAccent),
      onChanged: (_SelectablePlayerTypes? newValue) {
        setState(() {
          if (newValue != null) {
            if (isPlayerOne) {
              player1Type = newValue;
            } else {
              player2Type = newValue;
            }
          }
        });
      },
      items: _SelectablePlayerTypes.values
          .map<DropdownMenuItem<_SelectablePlayerTypes>>((
            _SelectablePlayerTypes value,
          ) {
            return DropdownMenuItem<_SelectablePlayerTypes>(
              value: value,
              child: Text(
                value.name,
                style: const TextStyle(color: Colors.black),
              ),
            );
          })
          .toList(),
    );
  }

  Widget _modelPanel(bool isPlayerOne) {
    final model = _models[isPlayerOne];
    final error = _modelErrors[isPlayerOne];
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        OutlinedButton.icon(
          onPressed: () => _uploadModel(isPlayerOne),
          icon: const Icon(Icons.upload_file),
          label: Text(
            model == null ? 'Upload AlphaZero model' : 'Replace model',
          ),
        ),
        if (model != null)
          Text(model.description, style: theme.textTheme.bodySmall),
        if (error != null)
          Text(
            error,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.error,
            ),
          ),
        Text(
          'weights.json is read in this browser only; it is never uploaded.',
          style: theme.textTheme.bodySmall,
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Scaffold(
        body: Center(
          child: SingleChildScrollView(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Column(
                children: [
                  Padding(
                    padding: EdgeInsets.all(CellulaSpacing.x2.spacing),
                    child: CellulaTextInput(
                      textEditingController: playerOne,
                      isRequired: true,
                      maxLength: 12,
                      errorText: playerOneErrorText,
                      cellulaTokens: CellulaTokens.none(),
                      placeholderText: 'Enter player one',
                      onChanged: (_) {},
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.all(CellulaSpacing.x2.spacing),
                    child: playerSelectionDropDown(player1Type, true),
                  ),
                  if (player1Type == _SelectablePlayerTypes.alphaZeroAi)
                    Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: CellulaSpacing.x2.spacing,
                      ),
                      child: _modelPanel(true),
                    ),
                  Padding(
                    padding: EdgeInsets.all(CellulaSpacing.x2.spacing),
                    child: CellulaTextInput(
                      textEditingController: playerTwo,
                      isRequired: true,
                      maxLength: 12,
                      errorText: playerTwoErrorText,
                      cellulaTokens: CellulaTokens.none(),
                      placeholderText: 'Enter player two',
                      onChanged: (_) {},
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.all(CellulaSpacing.x2.spacing),
                    child: playerSelectionDropDown(player2Type, false),
                  ),
                  if (player2Type == _SelectablePlayerTypes.alphaZeroAi)
                    Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: CellulaSpacing.x2.spacing,
                      ),
                      child: _modelPanel(false),
                    ),
                  Padding(
                    padding: EdgeInsets.all(CellulaSpacing.x2.spacing),
                    child: CellulaButton(
                      buttonVariant: CellulaButtonVariant.primary(
                        CellulaTokens.none(),
                        CellulaButtonSize.xLarge,
                      ),
                      text: 'Start Game',
                      enabled: _canStart,
                      onPressed: onStartClick,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
