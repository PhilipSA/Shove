import 'package:flutter/material.dart';
import 'package:shove/cellula/cellula_foundation/cellula_foundation.dart';

class CellulaShimmer extends StatefulWidget {
  final Widget? child;

  static CellulaShimmerState? of(BuildContext context) {
    return context.findAncestorStateOfType<CellulaShimmerState>();
  }

  get _linearGradient => LinearGradient(
        colors: [
          Neutral.c300.color,
          Neutral.c200.color,
          Neutral.c300.color,
        ],
        stops: const [
          0.0,
          0.4,
          0.8,
        ],
        begin: const Alignment(-1.0, -0.1),
        end: const Alignment(1.0, 0.1),
        tileMode: TileMode.clamp,
      );

  const CellulaShimmer({
    super.key,
    this.child,
  });

  @override
  CellulaShimmerState createState() => CellulaShimmerState();
}

class CellulaShimmerState extends State<CellulaShimmer>
    with SingleTickerProviderStateMixin {
  late AnimationController _shimmerController;

  @override
  void initState() {
    super.initState();

    _shimmerController = AnimationController.unbounded(vsync: this)
      ..repeat(min: -0.5, max: 1.5, period: const Duration(milliseconds: 1500));
  }

  @override
  void dispose() {
    _shimmerController.dispose();
    super.dispose();
  }

  LinearGradient get gradient => LinearGradient(
        colors: widget._linearGradient.colors,
        stops: widget._linearGradient.stops,
        begin: widget._linearGradient.begin,
        end: widget._linearGradient.end,
        transform:
            _SlidingGradientTransform(slidePercent: _shimmerController.value),
      );

  bool get isSized =>
      (context.findRenderObject() as RenderBox?)?.hasSize ?? false;

  Size get size => (context.findRenderObject()! as RenderBox).size;

  Offset getDescendantOffset({
    required RenderBox descendant,
    Offset offset = Offset.zero,
  }) {
    final shimmerBox = context.findRenderObject()! as RenderBox;
    return descendant.localToGlobal(offset, ancestor: shimmerBox);
  }

  Listenable get shimmerChanges => _shimmerController;

  @override
  Widget build(BuildContext context) {
    return widget.child ?? const SizedBox();
  }
}

class _SlidingGradientTransform extends GradientTransform {
  const _SlidingGradientTransform({
    required this.slidePercent,
  });

  final double slidePercent;

  @override
  Matrix4? transform(Rect bounds, {TextDirection? textDirection}) {
    return Matrix4.translationValues(bounds.width * slidePercent, 0.0, 0.0);
  }
}

/// This Widget will only work when [CellulaShimmer] is higher up in the view hierarchy
class CellulaShimmerLoading extends StatefulWidget {
  const CellulaShimmerLoading({
    required this.isLoading,
    required this.shimmerBoxSize,
    required this.child,
    this.shimmerBoxPadding,
    super.key,
  });

  final bool isLoading;
  final Widget child;
  final Size shimmerBoxSize;
  final EdgeInsets? shimmerBoxPadding;

  @override
  State<CellulaShimmerLoading> createState() => _CellulaShimmerLoadingState();
}

class _CellulaShimmerLoadingState extends State<CellulaShimmerLoading> {
  Listenable? _shimmerChanges;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_shimmerChanges != null) {
      _shimmerChanges!.removeListener(_onShimmerChange);
    }
    _shimmerChanges = CellulaShimmer.of(context)?.shimmerChanges;
    if (_shimmerChanges != null) {
      _shimmerChanges!.addListener(_onShimmerChange);
    }
  }

  @override
  void dispose() {
    _shimmerChanges?.removeListener(_onShimmerChange);
    super.dispose();
  }

  void _onShimmerChange() {
    if (widget.isLoading) {
      setState(() {
        // update the shimmer painting.
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isLoading) {
      return widget.child;
    }

    // Collect ancestor shimmer info.
    final shimmer = CellulaShimmer.of(context)!;
    if (!shimmer.isSized) {
      // The ancestor Shimmer widget has not laid
      // itself out yet. Return an empty box.
      return const SizedBox();
    }
    final shimmerSize = shimmer.size;
    final gradient = shimmer.gradient;
    final renderBox = context.findRenderObject() as RenderBox?;

    if (renderBox == null) {
      return const SizedBox();
    }

    final offsetWithinShimmer = shimmer.getDescendantOffset(
      descendant: renderBox,
    );

    return ShaderMask(
      blendMode: BlendMode.srcATop,
      shaderCallback: (bounds) {
        return gradient.createShader(
          Rect.fromLTWH(
            -offsetWithinShimmer.dx,
            -offsetWithinShimmer.dy,
            shimmerSize.width,
            shimmerSize.height,
          ),
        );
      },
      child: Padding(
        padding: widget.shimmerBoxPadding ?? EdgeInsets.zero,
        child: ColoredBox(
          color: Colors.grey,
          child: SizedBox.fromSize(size: widget.shimmerBoxSize),
        ),
      ),
    );
  }
}
