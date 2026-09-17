import 'package:flutter/material.dart';

/// Fades and slides its child in with a small stagger based on [index].
/// Respects the platform reduced-motion setting by showing immediately.
class StaggeredIn extends StatefulWidget {
  const StaggeredIn({super.key, required this.index, required this.child});

  /// Position in the list; each step adds ~36ms of delay, capped at 10.
  final int index;
  final Widget child;

  @override
  State<StaggeredIn> createState() => _StaggeredInState();
}

class _StaggeredInState extends State<StaggeredIn>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    final delay = 36 * widget.index.clamp(0, 10);
    final total = delay + 300;
    _controller = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: total),
    );
    _animation = CurvedAnimation(
      parent: _controller,
      curve: Interval(delay / total, 1, curve: Curves.easeOutCubic),
    );
    _controller.forward();
  }

  @override
  void didUpdateWidget(StaggeredIn oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.index != widget.index) {
      _controller
        ..reset()
        ..forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.disableAnimationsOf(context)) return widget.child;
    return FadeTransition(
      opacity: _animation,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.06),
          end: Offset.zero,
        ).animate(_animation),
        child: widget.child,
      ),
    );
  }
}
