import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shove/audio/shove_audio_player.dart';
import 'package:shove/cellula/cellula_foundation/cellula_tokens.dart';
import 'package:shove/cellula/cellula_foundation/components/cellula_button.dart';
import 'package:shove/game_objects/shove_game.dart';
import 'package:shove/game_objects/shove_game_notation.dart';
import 'package:shove/game_objects/shove_player.dart';
import 'package:shove/ui/game_board/shove_board_view.dart';

class AnalyzeButton extends StatelessWidget {
  final ShoveAudioPlayerFactory createAudioPlayer;

  const AnalyzeButton({
    this.createAudioPlayer = ShoveAudioPlayer.new,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return CellulaButton(
      buttonVariant: CellulaButtonVariant.secondary(
        CellulaTokens.none(),
        CellulaButtonSize.large,
      ),
      text: 'Analyze a game',
      onPressed: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) =>
              AnalyzeGameScreen(createAudioPlayer: createAudioPlayer),
        ),
      ),
    );
  }
}

/// Lets the user paste a game in [ShoveGameNotation] and step through it on the board.
class AnalyzeGameScreen extends StatefulWidget {
  final ShoveAudioPlayerFactory createAudioPlayer;

  const AnalyzeGameScreen({
    this.createAudioPlayer = ShoveAudioPlayer.new,
    super.key,
  });

  @override
  State<AnalyzeGameScreen> createState() => _AnalyzeGameScreenState();
}

class _AnalyzeGameScreenState extends State<AnalyzeGameScreen> {
  final _controller = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _paste() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text;
    if (text == null || !mounted) return;
    setState(() {
      _controller.text = text;
      _error = null;
    });
  }

  void _analyze() {
    final ShoveGameNotation notation;
    final ShoveGame game;
    try {
      notation = ShoveGameNotation.parse(_controller.text);
      game = _newGame(notation);
      notation.replayOn(_newGame(notation));
    } on FormatException catch (e) {
      setState(() => _error = e.message);
      return;
    }

    setState(() => _error = null);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ShoveBoardWidget(
          musicPlayer: widget.createAudioPlayer(playerId: 'game_music'),
          createAudioPlayer: widget.createAudioPlayer,
          game: game,
          importedGame: notation,
        ),
      ),
    );
  }

  ShoveGame _newGame(ShoveGameNotation notation) => ShoveGame(
    ShovePlayer(notation.white ?? 'White', true),
    ShovePlayer(notation.black ?? 'Black', false),
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Analyze a game')),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    controller: _controller,
                    minLines: 8,
                    maxLines: 14,
                    keyboardType: TextInputType.multiline,
                    onChanged: (_) {
                      if (_error != null) setState(() => _error = null);
                    },
                    decoration: InputDecoration(
                      border: const OutlineInputBorder(),
                      labelText: 'Game notation',
                      hintText: '1. a2-a3 h7-h6\n2. b1-c3 g8-f6',
                      errorText: _error,
                      errorMaxLines: 4,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      OutlinedButton.icon(
                        onPressed: _paste,
                        icon: const Icon(Icons.paste),
                        label: const Text('Paste'),
                      ),
                      const Spacer(),
                      FilledButton.icon(
                        onPressed: _analyze,
                        icon: const Icon(Icons.analytics_outlined),
                        label: const Text('Analyze'),
                      ),
                    ],
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
