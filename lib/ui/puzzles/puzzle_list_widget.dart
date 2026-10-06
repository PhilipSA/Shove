import 'package:flutter/material.dart';
import 'package:shove/audio/shove_audio_player.dart';
import 'package:shove/cellula/cellula_foundation/cellula_tokens.dart';
import 'package:shove/cellula/cellula_foundation/wrappers/cellula_app_bar.dart';
import 'package:shove/puzzles/shove_puzzles.dart';
import 'package:shove/ui/puzzles/puzzle_progress.dart';
import 'package:shove/ui/puzzles/puzzle_screen_widget.dart';

class PuzzleListScreen extends StatefulWidget {
  final ShoveAudioPlayerFactory createAudioPlayer;

  const PuzzleListScreen({
    this.createAudioPlayer = ShoveAudioPlayer.new,
    super.key,
  });

  @override
  State<PuzzleListScreen> createState() => _PuzzleListScreenState();
}

class _PuzzleListScreenState extends State<PuzzleListScreen> {
  final _progress = PuzzleProgress();

  @override
  void dispose() {
    _progress.dispose();
    super.dispose();
  }

  void _open(int index) => Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => PuzzleScreen(
        startIndex: index,
        progress: _progress,
        createAudioPlayer: widget.createAudioPlayer,
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final tokens = CellulaTokens.none();
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: tokens.bg.page,
      appBar: cellulaAppBar(
        cellulaTokens: tokens,
        title: 'Puzzles',
        onNavBackPressed: () => Navigator.pop(context),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: ListenableBuilder(
              listenable: _progress,
              builder: (context, _) => ListView(
                padding: const EdgeInsets.all(8),
                children: [
                  Padding(
                    padding: const EdgeInsets.all(8),
                    child: Text(
                      '${_progress.solvedCount} of ${shovePuzzles.length} solved. '
                      'Find the winning moves against the best defence.',
                      style: theme.textTheme.bodyMedium,
                    ),
                  ),
                  for (var i = 0; i < shovePuzzles.length; i++)
                    Card(
                      child: ListTile(
                        leading: _progress.isSolved(i)
                            ? Icon(
                                Icons.check_circle,
                                color: Colors.green.shade700,
                              )
                            : CircleAvatar(child: Text('${i + 1}')),
                        title: Text(shovePuzzles[i].title),
                        subtitle: Text(
                          'Win in ${movesText(shovePuzzles[i].movesToWin)}',
                        ),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => _open(i),
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
