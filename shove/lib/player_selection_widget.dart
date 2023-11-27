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
import 'package:shove/ui/game_board_widget/shove_board_widget.dart';

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
  bool _aiCheckbox = false;

  @override
  void dispose() {
    // Clean up the controller when the widget is disposed.
    playerOne.dispose();
    playerTwo.dispose();
    super.dispose();
  }

  void onChanged(bool? value) {
    setState(() {
      _aiCheckbox = value!;
    });
  }

  void onStartClick() {
    IPlayer player1 = ShovePlayer(playerOne.value.text, true);
    IPlayer player2 = ShovePlayer(playerTwo.value.text, false);

    if (_aiCheckbox) {
      player1 = RandomAi(playerOne.value.text, true);
      player2 = RandomAi(playerTwo.value.text, false);
    }

    final shoveGame = ShoveGame(player1, player2);

    if (playerOne.value.text.isEmpty || playerTwo.value.text.isEmpty) {
      setState(() {
        playerOneErrorText = 'Name can not be empty';
        playerTwoErrorText = 'Name can not be empty';
      });
    } else {
      widget.audioPlayer
        ..stop()
        ..play(AssetSource('sounds/music/GameMusic.mp3'), volume: 0.1);
      Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ShoveBoardWidget(
              game: shoveGame,
            ),
          ));
    }
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
            child: CellulaInputCheckbox(
                cellulaTokens: CellulaTokens.none(),
                value: _aiCheckbox,
                enabled: true,
                title: 'Only AI',
                hasValidationError: false,
                onChanged: onChanged),
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
