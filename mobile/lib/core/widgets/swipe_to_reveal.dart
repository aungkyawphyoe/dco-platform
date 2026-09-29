import 'package:dco_mobile/core/theme/dco_tokens.dart';
import 'package:flutter/material.dart';

class SwipeToReveal extends StatefulWidget {
  const SwipeToReveal({
    super.key,
    required this.child,
    required this.actionsBuilder,
  });

  final Widget child;
  final List<Widget> Function(VoidCallback close) actionsBuilder;

  @override
  State<SwipeToReveal> createState() => _SwipeToRevealState();
}

class _SwipeToRevealState extends State<SwipeToReveal>
    with SingleTickerProviderStateMixin {
  final _panelKey = GlobalKey();
  late final AnimationController _controller;
  double _dragStartPx = 0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, value: 0);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  double get _panelWidth {
    final box = _panelKey.currentContext?.findRenderObject();
    if (box is! RenderBox || !box.hasSize) return 0;
    return box.size.width;
  }

  void _close() {
    if (!mounted) return;
    _controller.animateTo(0);
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    _controller.duration = Duration(milliseconds: tokens.motion.fast);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onHorizontalDragStart: (_) {
        _controller.stop();
        _dragStartPx = _controller.value * _panelWidth;
      },
      onHorizontalDragUpdate: (details) {
        final width = _panelWidth;
        if (width == 0) return;
        final next = (_dragStartPx - (details.primaryDelta ?? 0)).clamp(
          0.0,
          width,
        );
        _controller.value = next / width;
      },
      onHorizontalDragEnd: (details) {
        final width = _panelWidth;
        if (width == 0) return;
        final velocity = details.primaryVelocity ?? 0;
        final open = velocity < -200
            ? true
            : velocity > 200
            ? false
            : _controller.value > 0.4;
        _controller.animateTo(open ? 1 : 0);
      },
      onHorizontalDragCancel: () {
        _controller.animateTo(_controller.value > 0.4 ? 1 : 0);
      },
      onTap: _controller.value > 0 ? _close : null,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          final width = _panelWidth;
          return Stack(
            clipBehavior: Clip.hardEdge,
            children: [
              Positioned(
                right: 0,
                top: 0,
                bottom: 0,
                child: Container(
                  key: _panelKey,
                  color: tokens.background.input,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: widget.actionsBuilder(_close),
                  ),
                ),
              ),
              Transform.translate(
                offset: Offset(-_controller.value * width, 0),
                child: widget.child,
              ),
            ],
          );
        },
      ),
    );
  }
}
