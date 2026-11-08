import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// 메시지 버블을 좌측으로 스와이프하면 답장 대상으로 지정하는 래퍼.
/// 카카오톡처럼 드래그하는 동안 버블이 따라 움직이고, 손을 떼면 원위치로 스냅한다.
class SwipeToReply extends StatefulWidget {
  final Widget child;
  final VoidCallback? onReply;

  const SwipeToReply({super.key, required this.child, this.onReply});

  @override
  State<SwipeToReply> createState() => _SwipeToReplyState();
}

class _SwipeToReplyState extends State<SwipeToReply>
    with SingleTickerProviderStateMixin {
  static const double _triggerDistance = 56;
  static const double _maxDrag = 72;

  late final AnimationController _controller;
  double _dragStartDx = 0;
  double _dragDx = 0;
  bool _triggered = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 180),
    );
    _controller.addListener(() {
      setState(() {
        _dragDx = _dragStartDx * (1 - _controller.value);
      });
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onUpdate(DragUpdateDetails details) {
    if (widget.onReply == null) return;
    setState(() {
      _dragDx = (_dragDx + details.delta.dx).clamp(-_maxDrag, 0.0);
      final shouldTrigger = _dragDx <= -_triggerDistance;
      if (shouldTrigger && !_triggered) {
        _triggered = true;
        HapticFeedback.selectionClick();
      } else if (!shouldTrigger && _triggered) {
        _triggered = false;
      }
    });
  }

  void _onEnd(DragEndDetails details) {
    if (widget.onReply == null) return;
    if (_triggered) widget.onReply!();
    _triggered = false;
    _dragStartDx = _dragDx;
    _controller.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onHorizontalDragUpdate: _onUpdate,
      onHorizontalDragEnd: _onEnd,
      child: Stack(
        alignment: Alignment.centerRight,
        children: [
          if (_dragDx < 0)
            Opacity(
              opacity: (-_dragDx / _triggerDistance).clamp(0.0, 1.0),
              child: Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Icon(Icons.reply, size: 20, color: Colors.cyan.shade400),
              ),
            ),
          Transform.translate(
            offset: Offset(_dragDx, 0),
            child: widget.child,
          ),
        ],
      ),
    );
  }
}
