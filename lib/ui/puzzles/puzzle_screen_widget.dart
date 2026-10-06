import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:shove/audio/shove_audio_player.dart';
import 'package:shove/cellula/cellula_foundation/cellula_tokens.dart';
import 'package:shove/cellula/cellula_foundation/wrappers/cellula_app_bar.dart';
import 'package:shove/puzzles/shove_puzzle_session.dart';
import 'package:shove/puzzles/shove_puzzles.dart';
import 'package:shove/resources/shove_assets.dart';
import 'package:shove/ui/game_board/board_widget.dart';
import 'package:shove/ui/puzzles/puzzle_progress.dart';

String movesText(int count) => count == 1 ? '1 move' : '$count moves';

class PuzzleScreen extends StatefulWidget {
  final int startIndex;
  final PuzzleProgress progress;
  final ShoveAudioPlayerFactory createAudioPlayer;

  const PuzzleScreen({
    required this.startIndex,
    required this.progress,
    this.createAudioPlayer = ShoveAudioPlayer.new,
    super.key,
  });

  @override
  State<PuzzleScreen> createState() => _PuzzleScreenState();
}

class _PuzzleScreenState extends State<PuzzleScreen> {
  late int _index = widget.startIndex;
  late ShovePuzzleSession _session = _createSession();

  ShovePuzzleSession _createSession() =>
      ShovePuzzleSession(shovePuzzles[_index], onSound: _playSound)
        ..addListener(_onSessionChanged);

  void _playSound(AudioAssets sound) =>
      widget.createAudioPlayer().play(AssetSource(sound.assetPath));

  void _onSessionChanged() {
    if (_session.status == PuzzleStatus.solved) {
      widget.progress.markSolved(_index);
    }
  }

  void _next() {
    final previous = _session;
    setState(() {
      _index++;
      _session = _createSession();
    });
    // Dispose after the frame so no widget is still listening to it
    WidgetsBinding.instance.addPostFrameCallback((_) => previous.dispose());
  }

  @override
  void dispose() {
    _session.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = CellulaTokens.none();

    return Scaffold(
      backgroundColor: tokens.bg.page,
      appBar: cellulaAppBar(
        cellulaTokens: tokens,
        title: 'Puzzle ${_index + 1} of ${shovePuzzles.length}',
        onNavBackPressed: () => Navigator.pop(context),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: ListenableBuilder(
              listenable: _session,
              builder: (context, _) => Column(
                children: [
                  _buildHeader(),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Center(
                        child: BoardWidget(
                          key: ObjectKey(_session),
                          game: _session.game,
                          isInteractive: _session.isPlayersTurn,
                          hintSquares: _session.hintSquares,
                          onMove: _session.makeMove,
                        ),
                      ),
                    ),
                  ),
                  _buildStatus(),
                  _buildControls(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final theme = Theme.of(context);
    final puzzle = _session.puzzle;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Column(
        children: [
          Text(puzzle.title, style: theme.textTheme.titleLarge),
          Text(
            'You play white, at the bottom. Win in ${movesText(puzzle.movesToWin)}.',
            style: theme.textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
          Text(
            'Win by reaching the back rank, removing every enemy shover or leaving the opponent without a move.',
            style: theme.textTheme.bodySmall,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildStatus() {
    final theme = Theme.of(context);
    final session = _session;

    final (IconData icon, String text, Color color) = switch (session.status) {
      PuzzleStatus.solving => (
        Icons.touch_app,
        'Your move: win in ${movesText(session.movesLeft)}.',
        theme.colorScheme.onSurface,
      ),
      PuzzleStatus.opponentReplying => (
        Icons.hourglass_bottom,
        'Opponent replies…',
        theme.colorScheme.onSurface,
      ),
      PuzzleStatus.wrongMove => (
        Icons.close,
        'That does not win. Try again!',
        theme.colorScheme.error,
      ),
      PuzzleStatus.solved => (
        Icons.emoji_events,
        session.mistakes == 0
            ? 'Solved on the first try!'
            : 'Solved after ${session.mistakes} wrong ${session.mistakes == 1 ? 'move' : 'moves'}.',
        Colors.green.shade800,
      ),
    };

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  text,
                  style: theme.textTheme.titleMedium?.copyWith(color: color),
                ),
              ),
            ],
          ),
          if (session.hintTextShown && session.status != PuzzleStatus.solved)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                session.puzzle.hint,
                style: theme.textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildControls() {
    final isSolved = _session.status == PuzzleStatus.solved;
    final hasNext = _index + 1 < shovePuzzles.length;

    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
      child: Wrap(
        alignment: WrapAlignment.center,
        spacing: 8,
        runSpacing: 4,
        children: [
          if (isSolved && hasNext)
            FilledButton.icon(
              onPressed: _next,
              icon: const Icon(Icons.arrow_forward),
              label: const Text('Next puzzle'),
            ),
          if (isSolved && !hasNext)
            FilledButton.icon(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.list),
              label: const Text('All puzzles'),
            ),
          if (!isSolved)
            OutlinedButton.icon(
              onPressed: _session.isPlayersTurn ? _session.showHint : null,
              icon: const Icon(Icons.lightbulb_outline),
              label: Text(_session.hintTextShown ? 'Show piece' : 'Hint'),
            ),
          OutlinedButton.icon(
            onPressed: _session.reset,
            icon: const Icon(Icons.replay),
            label: Text(isSolved ? 'Retry' : 'Reset'),
          ),
        ],
      ),
    );
  }
}
