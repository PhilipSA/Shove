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
  @override
  Widget build(BuildContext context) {
    return Scaffold(
        body: Column(
      children: [
        CellulaTextInput(
          isRequired: true,
          maxLength: 12,
          errorText: 'Player one name is required',
          cellulaTokens: CellulaTokens.none(),
          placeholderText: 'Enter player one',
          onChanged: (String) {},
        ),
        CellulaTextInput(
          isRequired: true,
          maxLength: 12,
          errorText: 'Player two is requried',
          cellulaTokens: CellulaTokens.none(),
          placeholderText: 'Enter player two',
          onChanged: (String) {},
        ),
        CellulaButton(
          buttonVariant: CellulaButtonVariant.primary(
              CellulaTokens.none(), CellulaButtonSize.xLarge),
          text: 'Start Game',
          onPressed: () {
            Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) => ShoveBoardWidget(
                          game: ShoveGame(
                              ShovePlayer('1', true), RandomAi('2', false)),
                        )));
          },
        )
      ],
    ));
  }
}
