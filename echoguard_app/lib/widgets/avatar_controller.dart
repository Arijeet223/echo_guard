import 'package:flutter/foundation.dart';

// ═══════════════════════════════════════════════════════════════════════
//  Avatar State Enum — maps 1:1 to transparent PNG assets
// ═══════════════════════════════════════════════════════════════════════

enum AvatarState {
  hi,
  thinking,
  happy,
  thumbsUp,
  armsCrossed,
  suspicious,
}

extension AvatarStateAsset on AvatarState {
  String get assetPath {
    switch (this) {
      case AvatarState.hi:
        return 'assets/avatar_states/hi.png';
      case AvatarState.thinking:
        return 'assets/avatar_states/thinking.png';
      case AvatarState.happy:
        return 'assets/avatar_states/happy.png';
      case AvatarState.thumbsUp:
        return 'assets/avatar_states/thumbs_up.png';
      case AvatarState.armsCrossed:
        return 'assets/avatar_states/arms_crossed.png';
      case AvatarState.suspicious:
        return 'assets/avatar_states/suspicious.png';
    }
  }
}

// ═══════════════════════════════════════════════════════════════════════
//  AvatarController — Singleton ChangeNotifier
// ═══════════════════════════════════════════════════════════════════════

class AvatarController extends ChangeNotifier {

  // ── Singleton ──
  AvatarController._();
  static final AvatarController instance = AvatarController._();

  // ── Observable State ──
  bool _visible = false;
  AvatarState _state = AvatarState.hi;

  bool get visible => _visible;
  AvatarState get state => _state;

  // ── Show avatar with a specific expression ──
  void show(AvatarState newState) {
    _state = newState;
    _visible = true;
    notifyListeners();
  }

  // ── Hide avatar ──
  void hide() {
    _visible = false;
    notifyListeners();
  }

  // ── React to analysis data, then auto-hide ──
  /// Call this after receiving an AnalysisResult from the AI pipeline.
  /// It picks the right expression based on the credibility score and
  /// risk level, holds for a few seconds, then fades out.
  Future<void> showResultThenHide(Map<String, dynamic> data) async {
    final double credibility = (data['credibility'] as num?)?.toDouble() ?? 50;
    final String manipLevel = (data['manipulation_level'] as String?) ?? 'LOW';
    final bool isPropaganda = (data['propaganda_flag'] as bool?) ?? false;

    // ── Decision tree ──
    AvatarState reaction;

    if (credibility >= 80) {
      reaction = AvatarState.thumbsUp;   // High credibility → Thumbs up!
    } else if (credibility >= 60) {
      reaction = AvatarState.happy;       // Decent → Happy
    } else if (credibility >= 40) {
      reaction = AvatarState.suspicious;  // Uncertain → Suspicious
    } else if (isPropaganda || manipLevel == 'HIGH') {
      reaction = AvatarState.armsCrossed; // Propaganda/High manipulation → Arms crossed
    } else {
      reaction = AvatarState.armsCrossed; // Low credibility → Disapproval
    }

    // Show the reaction
    show(reaction);

    // Hold for 3 seconds so users notice
    await Future.delayed(const Duration(seconds: 3));

    // Transition to a friendly closing state
    _state = AvatarState.happy;
    notifyListeners();

    // Hold the closing state briefly
    await Future.delayed(const Duration(seconds: 1));

    // Auto-hide
    hide();
  }
}
