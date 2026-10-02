import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';
import 'package:shove/ai/abstraction/i_ai.dart';
import 'package:shove/audio/shove_audio_player.dart';
import 'package:shove/cellula/cellula_foundation/cellula_tokens.dart';
import 'package:shove/cellula/cellula_foundation/wrappers/cellula_app_bar.dart';
import 'package:shove/game_objects/abstraction/i_player.dart';
import 'package:shove/game_objects/piece_type.dart';
import 'package:shove/game_objects/shove_game.dart';
import 'package:shove/interactor/shove_game_interactor.dart';
import 'package:shove/resources/shove_assets.dart';
import 'package:shove/ui/about/about_board_widget.dart';
import 'package:shove/ui/game_board/board_widget.dart';
import 'package:shove/ui/game_board/evaluation_bar_widget.dart';
import 'package:shove/ui/game_board/timer_widget.dart';

class ShoveBoardWidget extends StatefulWidget {
  final ShoveGame game;
  final ShoveAudioPlayer musicPlayer;
  final ShoveAudioPlayerFactory createAudioPlayer;
  final bool showDebugInfo;

  const ShoveBoardWidget({
    required this.game,
    required this.musicPlayer,
    this.createAudioPlayer = ShoveAudioPlayer.new,
    this.showDebugInfo = false,
    super.key,
  });

  @override
  State<ShoveBoardWidget> createState() => _ShoveBoardWidgetState();
}

class _ShoveBoardWidgetState extends State<ShoveBoardWidget> {
  static const _music = 'sounds/music/game_music.mp3';
  static const _wideLayoutMinWidth = 720.0;

  late ShoveGameInteractor _interactor;
  int _gameNumber = 0;
  bool _resultDismissed = false;
  bool _showEvaluationBar = false;
  bool _isMusicPlaying = true;

  ShoveGame get _game => _interactor.shoveGame;

  @override
  void initState() {
    super.initState();
    widget.musicPlayer
      ..stop()
      ..play(AssetSource(_music), volume: 0.1);
    _startGame(widget.game);
  }

  void _startGame(ShoveGame game) {
    _interactor = ShoveGameInteractor(
      game,
      createAudioPlayer: widget.createAudioPlayer,
    )..isEvalbarEnabled = _showEvaluationBar;
    _resultDismissed = false;
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _interactor.processAiTurns(),
    );
  }

  void _rematch() {
    final previous = _interactor;
    setState(() {
      _gameNumber++;
      _startGame(
        ShoveGame(previous.shoveGame.player1, previous.shoveGame.player2),
      );
    });
    // Dispose after the frame so no widget is still listening to it
    WidgetsBinding.instance.addPostFrameCallback((_) => previous.dispose());
  }

  void _toggleMusic() {
    setState(() => _isMusicPlaying = !_isMusicPlaying);
    widget.musicPlayer.stop();
    if (_isMusicPlaying) {
      widget.musicPlayer.play(AssetSource(_music), volume: 0.1);
    }
  }

  void _toggleEvaluationBar() {
    setState(() => _showEvaluationBar = !_showEvaluationBar);
    _interactor.isEvalbarEnabled = _showEvaluationBar;
    if (_showEvaluationBar) _interactor.evaluateGameState();
  }

  @override
  void dispose() {
    _interactor.dispose();
    widget.musicPlayer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = CellulaTokens.none();

    return ChangeNotifierProvider.value(
      value: _interactor.shoveGameEvaluationState,
      child: ListenableBuilder(
        listenable: Listenable.merge([
          _interactor.shoveGameMoveState,
          _interactor.shoveGameOverState,
        ]),
        builder: (context, _) {
          final overState = _interactor.shoveGameOverState;
          final title = !overState.isGameOver
              ? 'Shove'
              : overState.isDraw
              ? 'Draw'
              : '${overState.winner!.playerName} wins!';

          return Scaffold(
            backgroundColor: tokens.bg.page,
            appBar: cellulaAppBar(
              cellulaTokens: tokens,
              title: title,
              onNavBackPressed: () => Navigator.pop(context),
            ),
            body: SafeArea(
              child: KeyedSubtree(
                key: ValueKey(_gameNumber),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final isWide =
                        constraints.maxWidth >= _wideLayoutMinWidth &&
                        constraints.maxWidth > constraints.maxHeight;
                    return isWide ? _buildWide(constraints) : _buildTall();
                  },
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildTall() {
    return Column(
      children: [
        _PlayerPanel(
          game: _game,
          player: _game.player2,
          interactor: _interactor,
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: _buildBoardArea(),
          ),
        ),
        _PlayerPanel(
          game: _game,
          player: _game.player1,
          interactor: _interactor,
        ),
        _StatusLine(
          game: _game,
          onShowResult: () => setState(() => _resultDismissed = false),
        ),
        _buildControls(),
      ],
    );
  }

  Widget _buildWide(BoxConstraints constraints) {
    final panelWidth = (constraints.maxWidth * 0.3).clamp(260.0, 380.0);
    return Row(
      children: [
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: _buildBoardArea(),
          ),
        ),
        SizedBox(
          width: panelWidth,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(0, 16, 16, 16),
            child: Column(
              children: [
                _PlayerPanel(
                  game: _game,
                  player: _game.player2,
                  interactor: _interactor,
                ),
                Expanded(
                  child: Center(
                    child: SingleChildScrollView(
                      child: Column(
                        children: [
                          _StatusLine(
                            game: _game,
                            onShowResult: () =>
                                setState(() => _resultDismissed = false),
                          ),
                          _buildControls(),
                        ],
                      ),
                    ),
                  ),
                ),
                _PlayerPanel(
                  game: _game,
                  player: _game.player1,
                  interactor: _interactor,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBoardArea() {
    const evalBarWidth = 18.0;
    const evalBarGap = 6.0;

    return LayoutBuilder(
      builder: (context, constraints) {
        final reserved = _showEvaluationBar ? evalBarWidth + evalBarGap : 0.0;
        final side = (constraints.maxWidth - reserved).clamp(
          0.0,
          constraints.maxHeight,
        );

        return Center(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_showEvaluationBar) ...[
                SizedBox(
                  width: evalBarWidth,
                  height: side,
                  child: EvaluationBarWidget(
                    shoveGameEvaluationState:
                        _interactor.shoveGameEvaluationState,
                  ),
                ),
                const SizedBox(width: evalBarGap),
              ],
              SizedBox.square(
                dimension: side,
                child: Stack(
                  children: [
                    BoardWidget(
                      game: _game,
                      isInteractive: _interactor.isHumansTurn,
                      showDebugInfo: widget.showDebugInfo,
                      onMove: _interactor.makeMove,
                    ),
                    if (_interactor.shoveGameOverState.isGameOver &&
                        !_resultDismissed)
                      Positioned.fill(
                        child: _GameOverOverlay(
                          game: _game,
                          onRematch: _rematch,
                          onViewBoard: () =>
                              setState(() => _resultDismissed = true),
                          onExit: () => Navigator.pop(context),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildControls() {
    final isOver = _interactor.shoveGameOverState.isGameOver;

    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
      child: Wrap(
        alignment: WrapAlignment.center,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 4,
        runSpacing: 4,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: TimerWidget(isRunning: !isOver),
          ),
          IconButton.filledTonal(
            tooltip: 'Undo',
            icon: const Icon(Icons.undo),
            onPressed: _interactor.canUndo ? _interactor.undo : null,
          ),
          IconButton(
            tooltip: 'Evaluation bar',
            isSelected: _showEvaluationBar,
            icon: const Icon(Icons.insights_outlined),
            selectedIcon: const Icon(Icons.insights),
            onPressed: _toggleEvaluationBar,
          ),
          IconButton(
            tooltip: _isMusicPlaying ? 'Mute music' : 'Play music',
            icon: Icon(_isMusicPlaying ? Icons.music_note : Icons.music_off),
            onPressed: _toggleMusic,
          ),
          IconButton(
            tooltip: 'Rules',
            icon: const Icon(Icons.help_outline),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const About()),
            ),
          ),
          if (isOver)
            FilledButton.icon(
              onPressed: _rematch,
              icon: const Icon(Icons.replay),
              label: const Text('Rematch'),
            ),
        ],
      ),
    );
  }
}

String _gameOverDescription(ShoveGame game) {
  final winner = game.gameOverState?.winner;
  final loser = winner == null ? null : game.getOpponent(winner);
  return switch (game.gameOverReason) {
    GameOverReason.reachedGoal =>
      '${winner!.playerName} got a shover to the back rank.',
    GameOverReason.noShoversLeft => '${loser!.playerName} has no shovers left.',
    GameOverReason.noLegalMoves =>
      '${loser!.playerName} has no legal moves left.',
    GameOverReason.repetition => 'Both players kept repeating the same moves.',
    null => '',
  };
}

int _piecesLost(ShoveGame game, IPlayer player) =>
    2 * ShoveGame.totalNumberOfColumns -
    game.pieces.values.where((piece) => piece.owner == player).length;

class _PlayerPanel extends StatelessWidget {
  final ShoveGame game;
  final IPlayer player;
  final ShoveGameInteractor interactor;

  const _PlayerPanel({
    required this.game,
    required this.player,
    required this.interactor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isOver = game.isGameOver;
    final isTurn = !isOver && game.currentPlayersTurn == player;
    final isWinner = isOver && game.gameOverState?.winner == player;
    final isThinking = isTurn && interactor.shoveGameMoveState.isAiThinking;
    final shovers = game.pieces.values
        .where((p) => p.owner == player && p.pieceType == PieceType.shover)
        .length;

    final status = isWinner
        ? 'Winner!'
        : isThinking
        ? 'Thinking…'
        : isTurn
        ? 'To move'
        : null;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isWinner
            ? Colors.amber.shade100
            : isTurn
            ? theme.colorScheme.primaryContainer
            : theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isWinner
              ? Colors.amber.shade700
              : isTurn
              ? theme.colorScheme.primary
              : Colors.transparent,
          width: 2,
        ),
      ),
      child: Row(
        children: [
          SvgPicture.asset(
            (player.isWhite ? TextureAssets.shover : TextureAssets.invShover)
                .assetPath,
            width: 28,
            height: 28,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${player.playerName}${player is IAi ? ' (AI)' : ''}',
                  style: theme.textTheme.titleMedium,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  'Shovers: $shovers · Pieces lost: ${_piecesLost(game, player)}',
                  style: theme.textTheme.bodySmall,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          if (isThinking)
            const Padding(
              padding: EdgeInsets.only(right: 8),
              child: SizedBox.square(
                dimension: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          if (isWinner) Icon(Icons.emoji_events, color: Colors.amber.shade800),
          if (status != null)
            Padding(
              padding: const EdgeInsets.only(left: 4),
              child: Text(status, style: theme.textTheme.labelLarge),
            ),
        ],
      ),
    );
  }
}

/// One-line summary of the last move, or the result once the game is over.
class _StatusLine extends StatelessWidget {
  final ShoveGame game;
  final VoidCallback onShowResult;

  const _StatusLine({required this.game, required this.onShowResult});

  String? _lastMoveText() {
    if (game.allMadeMoves.isEmpty) return null;
    final move = game.allMadeMoves.last;
    final name = move.madeBy.playerName;

    if (move.eliminatedPiece) {
      return '$name shoved a ${move.shovedPiece!.pieceType.name} off the board!';
    }
    if (move.shovedPiece != null) {
      return '$name shoved a ${move.shovedPiece!.pieceType.name} – it is stunned.';
    }
    if (move.thrownPiece != null) {
      return '$name threw a ${move.thrownPiece!.pieceType.name} – it is stunned.';
    }
    if (move.leapedOverSquare != null) {
      final victim = game.pieces[move.leapedOverSquare!.pieceId];
      return '$name leaped over a ${victim?.pieceType.name ?? 'piece'} – it is stunned.';
    }
    final moved = game.pieces[move.newSquare.pieceId];
    return '$name moved a ${moved?.pieceType.name ?? 'piece'}.';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (game.isGameOver) {
      final winner = game.gameOverState?.winner;
      return Padding(
        padding: const EdgeInsets.all(8),
        child: Wrap(
          alignment: WrapAlignment.center,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 8,
          children: [
            Icon(
              winner == null ? Icons.handshake : Icons.emoji_events,
              color: Colors.amber.shade800,
            ),
            Text(
              winner == null ? 'Draw' : '${winner.playerName} wins!',
              style: theme.textTheme.titleMedium,
            ),
            TextButton(onPressed: onShowResult, child: const Text('Result')),
          ],
        ),
      );
    }

    final text = _lastMoveText();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Text(
        text ??
            '${game.currentPlayersTurn.playerName} starts. Tap a piece to see its moves.',
        style: theme.textTheme.bodyMedium,
        textAlign: TextAlign.center,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}

class _GameOverOverlay extends StatelessWidget {
  final ShoveGame game;
  final VoidCallback onRematch;
  final VoidCallback onViewBoard;
  final VoidCallback onExit;

  const _GameOverOverlay({
    required this.game,
    required this.onRematch,
    required this.onViewBoard,
    required this.onExit,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final winner = game.gameOverState?.winner;

    final card = Card(
      elevation: 12,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              winner == null ? Icons.handshake : Icons.emoji_events,
              size: 72,
              color: Colors.amber.shade700,
            ),
            const SizedBox(height: 8),
            if (winner != null)
              SvgPicture.asset(
                (winner.isWhite
                        ? TextureAssets.shover
                        : TextureAssets.invShover)
                    .assetPath,
                width: 40,
                height: 40,
              ),
            const SizedBox(height: 8),
            Text(
              winner == null ? 'Draw' : '${winner.playerName} wins!',
              style: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              _gameOverDescription(game),
              style: theme.textTheme.bodyLarge,
              textAlign: TextAlign.center,
            ),
            Text(
              '${game.allMadeMoves.length} moves played',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: onRematch,
              icon: const Icon(Icons.replay),
              label: const Text('Rematch'),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: onViewBoard,
              icon: const Icon(Icons.grid_on),
              label: const Text('View board'),
            ),
            TextButton(onPressed: onExit, child: const Text('Main menu')),
          ],
        ),
      ),
    );

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 450),
      curve: Curves.easeOutBack,
      builder: (context, t, child) => ColoredBox(
        color: Colors.black.withValues(alpha: 0.55 * t.clamp(0, 1)),
        child: Opacity(
          opacity: t.clamp(0, 1),
          child: Transform.scale(scale: 0.8 + 0.2 * t, child: child),
        ),
      ),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(12),
          // Shrinks the card on very small boards instead of overflowing
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: SizedBox(width: 320, child: card),
          ),
        ),
      ),
    );
  }
}
