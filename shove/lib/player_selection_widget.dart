import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shove/ai/random_ai.dart';
import 'package:shove/cellula/cellula_foundation/cellula_tokens.dart';
import 'package:shove/cellula/cellula_foundation/components/cellula_button.dart';
import 'package:shove/cellula/cellula_foundation/components/cellula_textinput.dart';
import 'package:shove/game_objects/shove_game.dart';
import 'package:shove/game_objects/shove_player.dart';
import 'package:shove/ui/game_board_widget/shove_board_widget.dart';

class PlayersWidget extends StatefulWidget {
  const PlayersWidget({super.key});

  @override
  State<PlayersWidget> createState() => _PlayersWidgetState();
}

class _PlayersWidgetState extends State<PlayersWidget> {
  final playerOne = TextEditingController();
  final playerTwo = TextEditingController();
  var playerOneErrorText = null;
  var PlayerTwoErrorText = null;

  @override
  void dispose() {
    // Clean up the controller when the widget is disposed.
    playerOne.dispose();
    playerTwo.dispose();
    super.dispose();
  }

  void onStartClick() {
    final player1 = ShovePlayer(playerOne.value.text, true);
    final player2 = RandomAi(playerTwo.value.text, false);
    final shoveGame = ShoveGame(player1, player2);

    //player1.makeMove(shoveGame);

    if (playerOne.value.text.isEmpty || playerTwo.value.text.isEmpty) {
      setState(() {
        playerOneErrorText = 'Name can not be empty';
        PlayerTwoErrorText = 'Name can not be empty';
      });
    } else {
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
    return Scaffold(
        body: Column(
      children: [
        CellulaTextInput(
          textEditingController: playerOne,
          isRequired: true,
          maxLength: 12,
          errorText: playerOneErrorText,
          cellulaTokens: CellulaTokens.none(),
          placeholderText: 'Enter player one',
          onChanged: (String) {},
        ),
        CellulaTextInput(
          textEditingController: playerTwo,
          isRequired: true,
          maxLength: 12,
          errorText: PlayerTwoErrorText,
          cellulaTokens: CellulaTokens.none(),
          placeholderText: 'Enter player two',
          onChanged: (String) {},
        ),
        CellulaButton(
          buttonVariant: CellulaButtonVariant.primary(
              CellulaTokens.none(), CellulaButtonSize.xLarge),
          text: 'Start Game',
          onPressed: onStartClick,
        )
      ],
    ));
  }
}
