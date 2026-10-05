import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:shove/game_objects/shove_move_notation.dart';
import 'package:shove/interactor/shove_game_interactor.dart';

/// Chess-style list of played moves; tapping one shows the board after it.
class MoveListWidget extends StatefulWidget {
  final ShoveGameInteractor interactor;

  /// Vertical: numbered rows with one move per player. Horizontal: a single scrolling strip.
  final Axis axis;

  const MoveListWidget({
    super.key,
    required this.interactor,
    this.axis = Axis.vertical,
  });

  @override
  State<MoveListWidget> createState() => _MoveListWidgetState();
}

class _MoveListWidgetState extends State<MoveListWidget> {
  final _controller = ScrollController();
  int _lastCount = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _scrollToEndIfNewMove(int count) {
    if (count == _lastCount) return;
    _lastCount = count;
    if (widget.interactor.isViewingHistory) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_controller.hasClients) return;
      _controller.jumpTo(_controller.position.maxScrollExtent);
    });
  }

  @override
  Widget build(BuildContext context) {
    final interactor = widget.interactor;
    final records = interactor.moveRecords;
    _scrollToEndIfNewMove(records.length);

    if (records.isEmpty) {
      return Center(
        child: Text(
          'No moves yet',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      );
    }

    Widget cell(int ply) => _MoveCell(
      record: records[ply - 1],
      isSelected: interactor.shownPly == ply,
      onTap: () => interactor.viewMove(ply),
    );

    if (widget.axis == Axis.horizontal) {
      return ListView.builder(
        controller: _controller,
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        itemCount: records.length,
        itemBuilder: (context, index) => Row(
          children: [
            if (index.isEven)
              Padding(
                padding: const EdgeInsets.only(left: 6, right: 2),
                child: Text(
                  '${index ~/ 2 + 1}.',
                  style: Theme.of(context).textTheme.labelMedium,
                ),
              ),
            cell(index + 1),
          ],
        ),
      );
    }

    final rows = (records.length + 1) ~/ 2;
    return ListView.builder(
      controller: _controller,
      itemCount: rows,
      itemBuilder: (context, row) {
        final first = row * 2 + 1;
        return Row(
          children: [
            SizedBox(
              width: 32,
              child: Text(
                '${row + 1}.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.labelMedium,
              ),
            ),
            Expanded(child: cell(first)),
            Expanded(
              child: first + 1 <= records.length
                  ? cell(first + 1)
                  : const SizedBox.shrink(),
            ),
          ],
        );
      },
    );
  }
}

class _MoveCell extends StatelessWidget {
  final ShoveMoveRecord record;
  final bool isSelected;
  final VoidCallback onTap;

  const _MoveCell({
    required this.record,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final texture = record.texture;

    return Tooltip(
      message: record.description,
      child: InkWell(
        borderRadius: BorderRadius.circular(6),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          decoration: BoxDecoration(
            color: isSelected ? theme.colorScheme.primaryContainer : null,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (texture != null)
                SvgPicture.asset(texture.assetPath, width: 18, height: 18),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  record.notation,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: isSelected ? FontWeight.bold : null,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
