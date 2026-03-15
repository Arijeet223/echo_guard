import 'dart:math';
import 'package:flutter/material.dart';
import 'avatar_controller.dart';

// ═══════════════════════════════════════════════════════════════════════
//  AvatarWidget — Floating, animated avatar overlay
// ═══════════════════════════════════════════════════════════════════════
//
//  • Positioned bottom-right, above the BottomNavigationBar
//  • IgnorePointer — never blocks user touches
//  • Spring entrance/exit animation
//  • Continuous floating up/down "breathing" animation
//  • AnimatedSwitcher cross-fade on expression changes
// ═══════════════════════════════════════════════════════════════════════

class AvatarWidget extends StatefulWidget {
  const AvatarWidget({super.key});

  @override
  State<AvatarWidget> createState() => _AvatarWidgetState();
}

class _AvatarWidgetState extends State<AvatarWidget>
    with TickerProviderStateMixin {

  // ── Entrance / Exit ──
  late final AnimationController _entranceCtrl;
  late final Animation<double> _scaleAnim;
  late final Animation<double> _fadeAnim;

  // ── Floating ──
  late final AnimationController _floatCtrl;

  bool _wasVisible = false;

  @override
  void initState() {
    super.initState();

    // Entrance: Spring scale + fade
    _entranceCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _scaleAnim = CurvedAnimation(
      parent: _entranceCtrl,
      curve: Curves.elasticOut,
    );
    _fadeAnim = CurvedAnimation(
      parent: _entranceCtrl,
      curve: Curves.easeIn,
    );

    // Floating: Continuous subtle up-and-down
    _floatCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);

    // Listen to visibility changes
    AvatarController.instance.addListener(_onControllerChange);
  }

  void _onControllerChange() {
    final isVisible = AvatarController.instance.visible;
    if (isVisible && !_wasVisible) {
      _entranceCtrl.forward(from: 0);
    } else if (!isVisible && _wasVisible) {
      _entranceCtrl.reverse();
    }
    _wasVisible = isVisible;
  }

  @override
  void dispose() {
    AvatarController.instance.removeListener(_onControllerChange);
    _entranceCtrl.dispose();
    _floatCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    // Offset for BottomNavigationBar (~60) + safe area + small breathing room
    final bottomOffset = bottomPadding + 70;

    return ListenableBuilder(
      listenable: AvatarController.instance,
      builder: (context, _) {
        final ctrl = AvatarController.instance;

        return Positioned(
          right: 8,
          bottom: bottomOffset,
          child: IgnorePointer(
            child: FadeTransition(
              opacity: _fadeAnim,
              child: ScaleTransition(
                scale: _scaleAnim,
                alignment: Alignment.bottomRight,
                child: AnimatedBuilder(
                  animation: _floatCtrl,
                  builder: (context, child) {
                    // Floating 6px up and down
                    final dy = sin(_floatCtrl.value * pi) * 6;
                    return Transform.translate(
                      offset: Offset(0, -dy),
                      child: child,
                    );
                  },
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 400),
                    transitionBuilder: (child, animation) {
                      return FadeTransition(
                        opacity: animation,
                        child: ScaleTransition(
                          scale: Tween<double>(begin: 0.85, end: 1.0)
                              .animate(animation),
                          child: child,
                        ),
                      );
                    },
                    child: SizedBox(
                      key: ValueKey(ctrl.state),
                      width: 120,
                      height: 120,
                      child: Image.asset(
                        ctrl.state.assetPath,
                        fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
