import 'package:flutter/material.dart';

class DragableSquareWidget extends StatefulWidget {
  final Widget child;
  final Color color;
  final bool isDraggable;
  final Function() onDragStarted;
  final Function() onDragCompleted;
  final Function(Velocity, Offset) onDraggableCanceled;
  final Function() onDraggableFeedback;

  const DragableSquareWidget(
      {required this.child,
      required this.color,
      required this.isDraggable,
      required this.onDragStarted,
      required this.onDragCompleted,
      required this.onDraggableCanceled,
      required this.onDraggableFeedback,
      super.key});

  @override
  createState() => _DragableSquareWidgetState();
}

class _DragableSquareWidgetState extends State<DragableSquareWidget> {
  var _isDragging = false;

  void _onDragStarted() {
    setState(() {
      _isDragging = true;
    });
    widget.onDragStarted();
  }

  void _onDragCompleted() {
    setState(() {
      _isDragging = false;
    });
    widget.onDragCompleted();
  }

  void _onDraggableCanceled(Velocity velocity, Offset offset) {
    setState(() {
      _isDragging = false;
    });
    widget.onDraggableCanceled(velocity, offset);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: widget.color,
      child: _isDragging
          ? Container()
          : widget.isDraggable
              ? Draggable(
                  feedback: widget.child,
                  onDragStarted: _onDragStarted,
                  onDragCompleted: _onDragCompleted,
                  onDraggableCanceled: _onDraggableCanceled,
                  child: widget.child,
                )
              : widget.child,
    );
  }
}
