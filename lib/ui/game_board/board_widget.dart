import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:shove/cellula/cellula_foundation/cellula_tokens.dart';
import 'package:shove/game_objects/piece_type.dart';
import 'package:shove/game_objects/shove_game.dart';
import 'package:shove/game_objects/shove_game_move.dart';
import 'package:shove/game_objects/shove_piece.dart';
import 'package:shove/game_objects/shove_square.dart';

typedef _Pos = (int x, int y);

_Pos _posOf(ShoveSquare square) => (square.x, square.y);

/// Square, size-adaptive game board. Pieces can be moved by tapping or dragging.
class BoardWidget extends StatefulWidget {
  final ShoveGame game;
  final bool isInteractive;
  final bool showDebugInfo;
  final ValueChanged<ShoveGameMove> onMove;

  /// Squares to point out, as (row, column).
  final Set<(int, int)> hintSquares;

  const BoardWidget({
    super.key,
    required this.game,
    required this.isInteractive,
    required this.onMove,
    this.showDebugInfo = false,
    this.hintSquares = const {},
  });

  @override
  State<BoardWidget> createState() => _BoardWidgetState();
}

class _BoardWidgetState extends State<BoardWidget> {
  static final _lightColor = Colors.white;
  static final _darkColor = CellulaTokens.none().primary.c500;

  _Pos? _selectedPos;

  /// The thrower or hook chosen to move the selected piece.
  _Pos? _helperPos;

  ShoveGame get _game => widget.game;

  @override
  void didUpdateWidget(BoardWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.isInteractive) {
      _selectedPos = null;
      _helperPos = null;
    }
  }

  ShoveSquare? _squareAt(_Pos? pos) =>
      pos == null ? null : _game.getSquareByXY(pos.$1, pos.$2);

  bool _isSelectable(ShoveSquare square) =>
      widget.isInteractive &&
      square.pieceId != null &&
      _game.hasLegalMovesFrom(square);

  /// Selects [square]; an own thrower or hook that was selected before becomes the helper.
  void _select(ShoveSquare square) {
    final pos = _posOf(square);
    if (pos == _selectedPos) return;

    final previous = _squareAt(_selectedPos);
    final helper =
        previous != null &&
            _game
                .getLegalMovesFrom(square)
                .any((m) => identical(m.throwerSquare, previous))
        ? previous
        : null;
    _helperPos = helper == null ? null : _posOf(helper);
    _selectedPos = pos;
  }

  /// The helpers that can move the selected enemy, and the one that will if it is already settled.
  ({Set<_Pos> helpers, _Pos? active}) _helpersOf(
    Iterable<ShoveGameMove> moves,
  ) {
    final helpers = {
      for (final move in moves)
        if (move.throwerSquare != null) _posOf(move.throwerSquare!),
    };
    final active = helpers.contains(_helperPos)
        ? _helperPos
        : helpers.length == 1
        ? helpers.single
        : null;
    return (helpers: helpers, active: active);
  }

  void _onTapSquare(ShoveSquare square, ShoveGameMove? targetMove) {
    if (targetMove != null) {
      _commit(targetMove);
      return;
    }

    final pos = _posOf(square);
    final selected = _squareAt(_selectedPos);
    if (selected != null) {
      final (:helpers, :active) = _helpersOf(_game.getLegalMovesFrom(selected));
      if (active == null && helpers.contains(pos)) {
        setState(() => _helperPos = pos);
        return;
      }
    }

    setState(() {
      if (pos != _selectedPos && _isSelectable(square)) {
        _select(square);
      } else {
        _selectedPos = null;
        _helperPos = null;
      }
    });
  }

  void _commit(ShoveGameMove move) {
    setState(() {
      _selectedPos = null;
      _helperPos = null;
    });
    widget.onMove(move);
  }

  @override
  Widget build(BuildContext context) {
    final selectedSquare = widget.isInteractive
        ? _squareAt(_selectedPos)
        : null;
    final selectedPiece = _game.pieces[selectedSquare?.pieceId];

    final selectedMoves = selectedSquare == null
        ? const <ShoveGameMove>[]
        : _game.getLegalMovesFrom(selectedSquare);
    final (:helpers, :active) = _helpersOf(selectedMoves);

    // With several possible helpers, the player picks one before the landing squares show.
    final needsHelper = helpers.length > 1 && active == null;
    // A helper picked beforehand (thrower or hook first) leaves only its own moves
    final helperPicked = active != null && active == _helperPos;
    final targets = <_Pos, ShoveGameMove>{};
    if (!needsHelper) {
      for (final move in selectedMoves) {
        final helper = move.throwerSquare;
        if (helper == null ? helperPicked : _posOf(helper) != active) continue;
        targets.putIfAbsent(_posOf(move.newSquare), () => move);
      }
    }

    // Selecting your own thrower or hook also reveals which pieces it can move.
    final throwable = <_Pos>{if (needsHelper) ...helpers else ?active};
    if (selectedSquare != null &&
        (selectedPiece?.pieceType == PieceType.thrower ||
            selectedPiece?.pieceType == PieceType.hook) &&
        selectedPiece?.owner == _game.currentPlayersTurn) {
      for (final square in _game.squares) {
        if (square.pieceId == null) continue;
        final canMove = _game
            .getLegalMovesFrom(square)
            .any((m) => identical(m.throwerSquare, selectedSquare));
        if (canMove) throwable.add(_posOf(square));
      }
    }

    final lastMove = _game.allMadeMoves.isEmpty
        ? null
        : _game.allMadeMoves.last;
    final lastMoveSquares = <_Pos>{
      if (lastMove != null) ...[
        _posOf(lastMove.oldSquare),
        _posOf(lastMove.newSquare),
        if (lastMove.throwerSquare != null) _posOf(lastMove.throwerSquare!),
        if (lastMove.shovedToSquare != null) _posOf(lastMove.shovedToSquare!),
      ],
    };

    final winningSquares = <_Pos>{
      if (_game.gameOverReason == GameOverReason.reachedGoal)
        for (final square in [
          ..._game.player1GoalShoveSquares,
          ..._game.player2GoalShoveSquares,
        ])
          if (_game.pieces[square.pieceId]?.pieceType == PieceType.shover &&
              _game.pieces[square.pieceId]?.owner ==
                  _game.gameOverState?.winner)
            _posOf(square),
    };

    return LayoutBuilder(
      builder: (context, constraints) {
        final side = min(constraints.maxWidth, constraints.maxHeight);
        final frame = max(2.0, side * 0.012);
        final cell = (side - frame * 2) / ShoveGame.totalNumberOfColumns;

        return SizedBox.square(
          dimension: side,
          child: Container(
            decoration: BoxDecoration(
              color: CellulaTokens.none().primary.c900,
              borderRadius: BorderRadius.circular(frame * 2),
              boxShadow: const [
                BoxShadow(blurRadius: 12, color: Colors.black26),
              ],
            ),
            padding: EdgeInsets.all(frame),
            child: Column(
              children: [
                for (var x = 0; x < ShoveGame.totalNumberOfRows; x++)
                  Expanded(
                    child: Row(
                      children: [
                        for (var y = 0; y < ShoveGame.totalNumberOfColumns; y++)
                          Expanded(
                            child: _buildSquare(
                              _game.getSquareByXY(x, y)!,
                              cell,
                              selectedPos: selectedSquare == null
                                  ? null
                                  : _posOf(selectedSquare),
                              targetMove: targets[(x, y)],
                              isThrowable: throwable.contains((x, y)),
                              isLastMove: lastMoveSquares.contains((x, y)),
                              isWinning: winningSquares.contains((x, y)),
                            ),
                          ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSquare(
    ShoveSquare square,
    double cell, {
    required _Pos? selectedPos,
    required ShoveGameMove? targetMove,
    required bool isThrowable,
    required bool isLastMove,
    required bool isWinning,
  }) {
    final pos = _posOf(square);
    final piece = _game.pieces[square.pieceId];
    final isGoalRow =
        square.x == 0 || square.x == ShoveGame.totalNumberOfRows - 1;
    final isStunned = piece?.isIncapacitated ?? false;

    return DragTarget<ShoveSquare>(
      onWillAcceptWithDetails: (_) => targetMove != null,
      onAcceptWithDetails: (_) => _commit(targetMove!),
      builder: (context, candidates, _) {
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => _onTapSquare(square, targetMove),
          child: Stack(
            fit: StackFit.expand,
            children: [
              ColoredBox(
                color: (square.x + square.y).isEven ? _lightColor : _darkColor,
              ),
              if (isGoalRow)
                ColoredBox(color: Colors.amber.withValues(alpha: 0.18)),
              if (isLastMove)
                ColoredBox(color: Colors.yellow.withValues(alpha: 0.4)),
              if (widget.hintSquares.contains(pos))
                ColoredBox(color: Colors.greenAccent.withValues(alpha: 0.5)),
              if (pos == selectedPos)
                ColoredBox(
                  color: Colors.lightBlueAccent.withValues(alpha: 0.55),
                ),
              if (isStunned)
                ColoredBox(color: Colors.deepOrange.withValues(alpha: 0.2)),
              if (candidates.isNotEmpty)
                ColoredBox(color: Colors.green.withValues(alpha: 0.35)),
              if (isWinning) _WinningGlow(cell: cell),
              if (piece != null)
                Padding(
                  padding: EdgeInsets.all(cell * 0.08),
                  child: _buildPiece(square, piece, cell, isStunned),
                ),
              if (targetMove != null)
                IgnorePointer(
                  child: _MoveHint(
                    cell: cell,
                    isOccupied: piece != null,
                    isThrow: targetMove.throwerSquare != null,
                  ),
                ),
              if (isThrowable)
                IgnorePointer(
                  child: Container(
                    margin: EdgeInsets.all(cell * 0.04),
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: Colors.orange,
                        width: max(2, cell * 0.06),
                      ),
                      borderRadius: BorderRadius.circular(cell * 0.15),
                    ),
                  ),
                ),
              if (widget.showDebugInfo)
                Text(
                  '${square.x}, ${square.y}',
                  style: TextStyle(color: Colors.pink.withValues(alpha: 0.5)),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPiece(
    ShoveSquare square,
    ShovePiece piece,
    double cell,
    bool isStunned,
  ) {
    final image = SvgPicture.asset(piece.texture!.assetPath);
    final pieceWidget = isStunned
        ? _StunnedPiece(cell: cell, child: image)
        : image;

    if (!_isSelectable(square)) return pieceWidget;

    return Draggable<ShoveSquare>(
      data: square,
      onDragStarted: () => setState(() => _select(square)),
      feedback: SizedBox.square(dimension: cell * 1.1, child: image),
      childWhenDragging: Opacity(opacity: 0.3, child: image),
      child: MouseRegion(cursor: SystemMouseCursors.grab, child: pieceWidget),
    );
  }
}

class _MoveHint extends StatelessWidget {
  final double cell;
  final bool isOccupied;
  final bool isThrow;

  const _MoveHint({
    required this.cell,
    required this.isOccupied,
    required this.isThrow,
  });

  @override
  Widget build(BuildContext context) {
    final color = isThrow ? Colors.orange.shade800 : Colors.black;

    if (isOccupied) {
      // A shove: ring around the piece that will be pushed.
      return Container(
        margin: EdgeInsets.all(cell * 0.03),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: Colors.red.withValues(alpha: 0.75),
            width: max(2, cell * 0.08),
          ),
        ),
      );
    }

    return Center(
      child: Container(
        width: cell * 0.3,
        height: cell * 0.3,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color.withValues(alpha: 0.35),
        ),
      ),
    );
  }
}

class _WinningGlow extends StatelessWidget {
  final double cell;

  const _WinningGlow({required this.cell});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.amber.withValues(alpha: 0.5),
        border: Border.all(color: Colors.amber, width: max(2, cell * 0.08)),
        boxShadow: [BoxShadow(color: Colors.amber, blurRadius: cell * 0.4)],
      ),
    );
  }
}

/// Greyed-out, wobbling piece with a badge, so stunned pieces stand out.
class _StunnedPiece extends StatefulWidget {
  final double cell;
  final Widget child;

  const _StunnedPiece({required this.cell, required this.child});

  @override
  State<_StunnedPiece> createState() => _StunnedPieceState();
}

class _StunnedPieceState extends State<_StunnedPiece>
    with SingleTickerProviderStateMixin {
  static const _greyscale = ColorFilter.matrix(<double>[
    0.2126, 0.7152, 0.0722, 0, 0, //
    0.2126, 0.7152, 0.0722, 0, 0, //
    0.2126, 0.7152, 0.0722, 0, 0, //
    0, 0, 0, 1, 0, //
  ]);

  late final AnimationController _wobble = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 700),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _wobble.stop();
    } else if (!_wobble.isAnimating) {
      _wobble.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _wobble.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final badgeSize = widget.cell * 0.34;

    return Tooltip(
      message: 'Stunned – skips its next turn',
      child: Stack(
        clipBehavior: Clip.none,
        fit: StackFit.expand,
        children: [
          // Own layers, so the wobble does not repaint the rest of the board
          RepaintBoundary(
            child: AnimatedBuilder(
              animation: _wobble,
              builder: (context, child) => Transform.rotate(
                angle: (_wobble.value - 0.5) * 0.3,
                child: child,
              ),
              child: RepaintBoundary(
                child: ColorFiltered(
                  colorFilter: _greyscale,
                  child: Opacity(opacity: 0.55, child: widget.child),
                ),
              ),
            ),
          ),
          Positioned(
            right: -badgeSize * 0.2,
            top: -badgeSize * 0.2,
            width: badgeSize,
            height: badgeSize,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.deepOrange,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 1.5),
              ),
              child: Icon(
                Icons.hourglass_bottom,
                size: badgeSize * 0.65,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
