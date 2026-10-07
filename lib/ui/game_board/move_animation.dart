import 'dart:math';
import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:shove/game_objects/piece_type.dart';
import 'package:shove/game_objects/shove_game.dart';
import 'package:shove/game_objects/shove_game_move.dart';
import 'package:shove/game_objects/shove_game_move_type.dart';
import 'package:shove/game_objects/shove_piece.dart';

/// A square as (row, column).
typedef GridPos = (int x, int y);

enum FlightStyle {
  /// Plain step.
  slide,

  /// Accelerates into a hit.
  dash,

  /// Hops over a piece.
  hop,

  /// Thrown through the air.
  lob,

  /// Hauled in by a hook.
  pull,

  /// Knocked back by a shove.
  shoved,

  /// Knocked off the board.
  ejected,
}

/// One piece travelling between two squares during part (begin..end) of the animation.
class PieceFlight {
  final ShovePiece piece;
  final GridPos from;
  final GridPos to;
  final FlightStyle style;
  final double begin;
  final double end;

  /// Number of fading afterimages behind the piece.
  final int trail;

  const PieceFlight({
    required this.piece,
    required this.from,
    required this.to,
    required this.style,
    this.begin = 0,
    this.end = 1,
    this.trail = 0,
  });

  double _local(double progress) =>
      ((progress - begin) / (end - begin)).clamp(0.0, 1.0);

  Curve get _curve => switch (style) {
    FlightStyle.slide => Curves.easeOutCubic,
    FlightStyle.dash => Curves.easeInCubic,
    FlightStyle.hop || FlightStyle.pull => Curves.easeInOut,
    FlightStyle.lob => Curves.easeInOutSine,
    FlightStyle.shoved => Curves.easeOutCubic,
    FlightStyle.ejected => Curves.easeInQuad,
  };

  /// Top-left corner of the piece's cell, in cells (dx = column, dy = row).
  Offset position(double progress) {
    final t = _curve.transform(_local(progress));
    return Offset(
      lerpDouble(from.$2, to.$2, t)!,
      lerpDouble(from.$1, to.$1, t)!,
    );
  }

  /// How far the piece is lifted off the board, 0..1.
  double lift(double progress) =>
      style == FlightStyle.hop || style == FlightStyle.lob
      ? sin(pi * _local(progress))
      : 0;

  double scale(double progress) {
    final l = _local(progress);
    return switch (style) {
      FlightStyle.hop => 1 + 0.35 * sin(pi * l),
      FlightStyle.lob => 1 + 0.6 * sin(pi * l),
      FlightStyle.shoved => 1 + 0.15 * sin(pi * l),
      FlightStyle.ejected => 1 - 0.5 * l,
      _ => 1,
    };
  }

  double rotation(double progress) {
    final l = _local(progress);
    return switch (style) {
      FlightStyle.lob => Curves.easeInOut.transform(l) * 2 * pi,
      FlightStyle.shoved => sin(pi * l) * 0.35,
      FlightStyle.ejected => 3 * pi * l,
      _ => 0,
    };
  }

  double opacity(double progress) {
    if (style != FlightStyle.ejected) return 1;
    final l = _local(progress);
    return l < 0.5 ? 1 : 1 - (l - 0.5) * 2;
  }
}

/// An expanding ring (with sparks) on a square.
class ImpactEffect {
  final GridPos at;
  final double begin;
  final double end;
  final Color color;
  final bool sparks;

  /// Final radius in cells.
  final double reach;

  const ImpactEffect({
    required this.at,
    required this.begin,
    required this.end,
    required this.color,
    this.sparks = false,
    this.reach = 0.8,
  });
}

/// What to show for the last move: flights, impacts and a screen shake.
class MoveAnimation {
  static const duration = Duration(milliseconds: 520);

  final List<PieceFlight> flights;
  final List<ImpactEffect> impacts;

  /// The hook's square and the piece it is reeling in.
  final ({GridPos hook, PieceFlight piece})? rope;

  /// Fraction of the animation at which the board shakes, if it does.
  final double? shakeAt;

  /// Squares whose piece is drawn by the animation instead of the board until it ends.
  final Set<GridPos> hidden;

  const MoveAnimation({
    required this.flights,
    required this.impacts,
    required this.hidden,
    this.rope,
    this.shakeAt,
  });

  Offset shakeOffset(double progress, double amplitude) {
    final start = shakeAt;
    if (start == null) return Offset.zero;
    final l = (progress - start) / 0.3;
    if (l <= 0 || l >= 1) return Offset.zero;
    final v = sin(l * pi * 7) * (1 - l) * amplitude;
    return Offset(v, v * 0.5);
  }

  /// Animation for [move], which has already been made on [game]; null if there is nothing to show.
  /// With [skipPrimary] the moved piece is not animated (the player already dragged it there).
  static MoveAnimation? of(
    ShoveGame game,
    ShoveGameMove move, {
    bool skipPrimary = false,
  }) {
    final from = (move.oldSquare.x, move.oldSquare.y);
    final to = (move.newSquare.x, move.newSquare.y);
    final flights = <PieceFlight>[];
    final impacts = <ImpactEffect>[];
    final hidden = <GridPos>{};

    if (move.shoveGameMoveType == ShoveGameMoveType.thrown) {
      final thrown = move.thrownPiece;
      final helper = move.throwerSquare;
      if (thrown == null || helper == null) return null;

      final helperPos = (helper.x, helper.y);
      final helperPiece =
          game.pieces[game.getSquareByXY(helper.x, helper.y)?.pieceId];
      final isPull = helperPiece?.pieceType == PieceType.hook;

      PieceFlight? flight;
      if (!skipPrimary) {
        flight = PieceFlight(
          piece: thrown,
          from: from,
          to: to,
          style: isPull ? FlightStyle.pull : FlightStyle.lob,
          end: isPull ? 0.8 : 1,
        );
        flights.add(flight);
        hidden.add(to);
      }
      impacts
        ..add(
          ImpactEffect(
            at: helperPos,
            begin: 0,
            end: 0.4,
            color: Colors.orange.shade700,
            reach: 0.6,
          ),
        )
        ..add(
          ImpactEffect(
            at: to,
            begin: isPull ? 0.6 : 0.75,
            end: 1,
            color: Colors.brown.shade400,
            sparks: true,
            reach: 0.7,
          ),
        );
      return MoveAnimation(
        flights: flights,
        impacts: impacts,
        hidden: hidden,
        rope: isPull && flight != null
            ? (hook: helperPos, piece: flight)
            : null,
      );
    }

    final mover = game.pieces[game.getSquareByXY(to.$1, to.$2)?.pieceId];
    if (mover == null) return null;

    final shoved = move.shovedPiece;
    final isCharger = mover.pieceType == PieceType.charger;
    final isLeap =
        mover.pieceType == PieceType.leaper &&
        max((from.$1 - to.$1).abs(), (from.$2 - to.$2).abs()) >= 2;

    final double impactAt;
    if (shoved == null) {
      impactAt = 0;
    } else {
      impactAt = skipPrimary ? 0.05 : (isCharger ? 0.4 : 0.35);
    }
    final moverEnd = shoved != null
        ? impactAt
        : isLeap
        ? 0.9
        : isCharger
        ? 0.55
        : 0.7;

    if (!skipPrimary) {
      flights.add(
        PieceFlight(
          piece: mover,
          from: from,
          to: to,
          style: isLeap
              ? FlightStyle.hop
              : (isCharger || shoved != null)
              ? FlightStyle.dash
              : FlightStyle.slide,
          end: moverEnd,
          trail: isCharger ? 3 : 0,
        ),
      );
      hidden.add(to);
    }

    final leapedOver = move.leapedOverSquare;
    if (leapedOver != null) {
      impacts.add(
        ImpactEffect(
          at: (leapedOver.x, leapedOver.y),
          begin: 0.45,
          end: 0.95,
          color: Colors.amber.shade700,
          sparks: true,
        ),
      );
    }

    if (shoved != null) {
      final landing = move.shovedToSquare;
      final target = landing != null
          ? (landing.x, landing.y)
          : _offBoard(game, from, to, mover.pieceType);

      // The shoved piece is drawn over the mover's square until it is hit.
      flights.insert(
        0,
        PieceFlight(
          piece: shoved,
          from: to,
          to: target,
          style: landing == null ? FlightStyle.ejected : FlightStyle.shoved,
          begin: max(0, impactAt - 0.05),
        ),
      );
      if (landing != null) hidden.add(target);

      impacts.add(
        ImpactEffect(
          at: to,
          begin: max(0, impactAt - 0.05),
          end: impactAt + 0.4,
          color: landing == null ? Colors.red.shade600 : Colors.orange.shade600,
          sparks: true,
        ),
      );
    }

    return MoveAnimation(
      flights: flights,
      impacts: impacts,
      hidden: hidden,
      shakeAt: shoved != null && (isCharger || move.eliminatedPiece)
          ? impactAt
          : null,
    );
  }

  /// The first square past the board edge that a piece shoved from [to] away from [from] reaches.
  static GridPos _offBoard(
    ShoveGame game,
    GridPos from,
    GridPos to,
    PieceType mover,
  ) {
    var dx = (to.$1 - from.$1).sign;
    var dy = (to.$2 - from.$2).sign;
    // A shover pushes along one axis only, rows first
    if (mover == PieceType.shover && dx != 0) dy = 0;

    var x = to.$1;
    var y = to.$2;
    do {
      x += dx;
      y += dy;
    } while (!game.isOutOfBounds(x, y));
    return (x, y);
  }
}

/// Draws the animation on top of the board grid; sized to the grid.
class MoveAnimationOverlay extends StatelessWidget {
  final MoveAnimation animation;
  final Animation<double> progress;

  const MoveAnimationOverlay({
    super.key,
    required this.animation,
    required this.progress,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final cellW = constraints.maxWidth / ShoveGame.totalNumberOfColumns;
        final cellH = constraints.maxHeight / ShoveGame.totalNumberOfRows;

        return Stack(
          clipBehavior: Clip.none,
          children: [
            if (animation.rope != null)
              Positioned.fill(
                child: CustomPaint(
                  painter: _RopePainter(
                    animation.rope!,
                    progress,
                    cellW,
                    cellH,
                  ),
                ),
              ),
            for (final flight in animation.flights)
              if (flight.piece.texture != null)
                Positioned.fill(
                  child: _FlightWidget(
                    flight: flight,
                    progress: progress,
                    cellW: cellW,
                    cellH: cellH,
                  ),
                ),
            Positioned.fill(
              child: CustomPaint(
                painter: _ImpactPainter(
                  animation.impacts,
                  progress,
                  cellW,
                  cellH,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _FlightWidget extends StatelessWidget {
  final PieceFlight flight;
  final Animation<double> progress;
  final double cellW;
  final double cellH;

  const _FlightWidget({
    required this.flight,
    required this.progress,
    required this.cellW,
    required this.cellH,
  });

  Widget _piece(double p, Widget image, {double fade = 1}) {
    final pos = flight.position(p);
    final lifted = flight.lift(p) * cellH * 0.18;
    final opacity = flight.opacity(p) * fade;

    Widget piece = Padding(padding: EdgeInsets.all(cellW * 0.08), child: image);
    piece = Transform.rotate(
      angle: flight.rotation(p),
      child: Transform.scale(scale: flight.scale(p), child: piece),
    );
    if (opacity < 1) piece = Opacity(opacity: opacity, child: piece);

    return Positioned(
      left: pos.dx * cellW,
      top: pos.dy * cellH - lifted,
      width: cellW,
      height: cellH,
      child: piece,
    );
  }

  @override
  Widget build(BuildContext context) {
    final image = SvgPicture.asset(flight.piece.texture!.assetPath);

    return AnimatedBuilder(
      animation: progress,
      child: image,
      builder: (context, image) {
        final p = progress.value;
        final lift = flight.lift(p);
        final ground = flight.position(p);

        return Stack(
          clipBehavior: Clip.none,
          children: [
            if (lift > 0)
              Positioned(
                left: ground.dx * cellW + cellW * 0.2,
                top: ground.dy * cellH + cellH * 0.65,
                width: cellW * 0.6,
                height: cellH * 0.2,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.black.withValues(
                      alpha: 0.25 * (1 - lift * 0.5),
                    ),
                  ),
                ),
              ),
            if (flight.trail > 0 && p > flight.begin && p < flight.end + 0.15)
              for (var i = flight.trail; i >= 1; i--)
                if ((flight.position(p) - flight.position(p - i * 0.04))
                        .distance >
                    0.05)
                  _piece(p - i * 0.04, image!, fade: 0.35 / i),
            _piece(p, image!),
          ],
        );
      },
    );
  }
}

class _ImpactPainter extends CustomPainter {
  final List<ImpactEffect> impacts;
  final Animation<double> progress;
  final double cellW;
  final double cellH;

  _ImpactPainter(this.impacts, this.progress, this.cellW, this.cellH)
    : super(repaint: progress);

  @override
  void paint(Canvas canvas, Size size) {
    for (final effect in impacts) {
      final l = (progress.value - effect.begin) / (effect.end - effect.begin);
      if (l <= 0 || l >= 1) continue;

      final center = Offset(
        (effect.at.$2 + 0.5) * cellW,
        (effect.at.$1 + 0.5) * cellH,
      );
      final radius =
          cellW *
          effect.reach *
          (0.25 + 0.75 * Curves.easeOutCubic.transform(l));
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = max(1.0, cellW * 0.09 * (1 - l))
        ..color = effect.color.withValues(alpha: 1 - l);

      canvas.drawCircle(center, radius, paint);

      if (effect.sparks) {
        for (var i = 0; i < 8; i++) {
          final angle = i * pi / 4 + pi / 8;
          final direction = Offset(cos(angle), sin(angle));
          canvas.drawLine(
            center + direction * radius * 0.7,
            center + direction * radius * 1.2,
            paint,
          );
        }
      }
    }
  }

  @override
  bool shouldRepaint(_ImpactPainter oldDelegate) =>
      oldDelegate.impacts != impacts || oldDelegate.progress != progress;
}

class _RopePainter extends CustomPainter {
  final ({GridPos hook, PieceFlight piece}) rope;
  final Animation<double> progress;
  final double cellW;
  final double cellH;

  _RopePainter(this.rope, this.progress, this.cellW, this.cellH)
    : super(repaint: progress);

  @override
  void paint(Canvas canvas, Size size) {
    final p = progress.value;
    final fade = p < 0.8 ? 1.0 : (1 - (p - 0.8) / 0.2).clamp(0.0, 1.0);
    final hook = Offset(
      (rope.hook.$2 + 0.5) * cellW,
      (rope.hook.$1 + 0.5) * cellH,
    );
    final piece = rope.piece.position(p) + const Offset(0.5, 0.5);

    canvas.drawLine(
      hook,
      Offset(piece.dx * cellW, piece.dy * cellH),
      Paint()
        ..strokeCap = StrokeCap.round
        ..strokeWidth = max(2.0, cellW * 0.07)
        ..color = Colors.brown.shade600.withValues(alpha: fade),
    );
  }

  @override
  bool shouldRepaint(_RopePainter oldDelegate) =>
      oldDelegate.rope != rope || oldDelegate.progress != progress;
}
