import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:shove/ai/min_max_ai.dart';
import 'package:shove/ai/random_ai.dart';
import 'package:shove/audio/shove_audio_player.dart';
import 'package:shove/cellula/cellula_foundation/cellula_foundation.dart';
import 'package:shove/cellula/cellula_foundation/cellula_tokens.dart';
import 'package:shove/cellula/cellula_foundation/components/cellula_button.dart';
import 'package:shove/cellula/cellula_foundation/components/cellula_input_checkbox.dart';
import 'package:shove/cellula/cellula_foundation/components/cellula_textinput.dart';
import 'package:shove/game_objects/abstraction/i_player.dart';
import 'package:shove/game_objects/shove_game.dart';
import 'package:shove/game_objects/shove_player.dart';
import 'package:shove/ui/game_board/shove_board_view.dart';

enum _SelectablePlayerTypes { shovePlayer, minMaxAi, randomAi }

class PlayersWidget extends StatefulWidget {
  final ShoveAudioPlayer audioPlayer;
  const PlayersWidget(this.audioPlayer, {super.key});

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
          isPlayerOne);
    } else if (type == _SelectablePlayerTypes.minMaxAi) {
      return MinMaxAi(isPlayerOne ? playerOne.value.text : playerTwo.value.text,
          isPlayerOne);
    } else if (type == _SelectablePlayerTypes.randomAi) {
      return RandomAi(isPlayerOne ? playerOne.value.text : playerTwo.value.text,
          isPlayerOne);
    } else {
      return ShovePlayer(
          isPlayerOne ? playerOne.value.text : playerTwo.value.text,
          isPlayerOne);
    }
  }

  void onStartClick() {
    IPlayer player1 = getPlayerFromType(player1Type, true);
    IPlayer player2 = getPlayerFromType(player2Type, false);

    final shoveGame = ShoveGame(player1, player2);

    if (playerOne.value.text.isEmpty || playerTwo.value.text.isEmpty) {
      setState(() {
        playerOneErrorText = 'Name can not be empty';
        playerTwoErrorText = 'Name can not be empty';
      });
    } else {
      widget.audioPlayer.stop();
      Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ShoveBoardWidget(
              musicPlayer: ShoveAudioPlayer(playerId: 'game_music'),
              game: shoveGame,
            ),
          ));
    }
  }

  Widget playerSelectionDropDown(
      _SelectablePlayerTypes selectedType, bool isPlayerOne) {
    return DropdownButton<_SelectablePlayerTypes>(
      isExpanded: true,
      value: selectedType,
      icon: const Icon(Icons.arrow_downward),
      iconSize: 24,
      elevation: 16,
      style: const TextStyle(color: Colors.deepPurple),
      underline: Container(
        height: 2,
        color: Colors.deepPurpleAccent,
      ),
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
          .map<DropdownMenuItem<_SelectablePlayerTypes>>(
              (_SelectablePlayerTypes value) {
        return DropdownMenuItem<_SelectablePlayerTypes>(
          value: value,
          child: Text(
            value.name,
            style: const TextStyle(color: Colors.black),
          ),
        );
      }).toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Scaffold(
          body: Column(
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
              onChanged: (String) {},
            ),
          ),
          Padding(
            padding: EdgeInsets.all(CellulaSpacing.x2.spacing),
            child: playerSelectionDropDown(player1Type, true),
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
              onChanged: (String) {},
            ),
          ),
          Padding(
            padding: EdgeInsets.all(CellulaSpacing.x2.spacing),
            child: playerSelectionDropDown(player2Type, false),
          ),
          Padding(
            padding: EdgeInsets.all(CellulaSpacing.x2.spacing),
            child: CellulaButton(
              buttonVariant: CellulaButtonVariant.primary(
                  CellulaTokens.none(), CellulaButtonSize.xLarge),
              text: 'Start Game',
              onPressed: onStartClick,
            ),
          )
        ],
      )),
    );
  }
}
