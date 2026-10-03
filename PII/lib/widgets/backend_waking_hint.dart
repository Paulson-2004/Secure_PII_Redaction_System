import 'dart:async';

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Central copy + timing for the Render free-tier cold-start waiting UX.
///
/// This is intentionally a *generic* "backend is taking longer than expected"
/// state. PrivLock has no reliable way to know Render is specifically asleep,
/// so the UI only explains that the delay *can* happen because the free
/// backend sleeps after inactivity.
class ColdStartCopy {
  /// How long a backend request must remain unresolved before the hint
  /// appears. Normal network/API latency (< 5s) never triggers the message.
  static const Duration wakeDelay = Duration(seconds: 5);

  static const String title = 'Backend is waking up…';

  static const String body =
      'PrivLock\u2019s free backend may take about a minute to start '
      'after a period of inactivity. Please wait \u2014 your request is '
      'still in progress.';

  static const String footnote =
      'This usually happens after 15 minutes without backend activity.';
}

/// Compact informational status element (NOT an error, NOT a modal).
///
/// Fits the existing blue/slate visual identity: [AppTheme.primaryLight]
/// surface, blue border, [AppTheme.radiusSmall] radius, slate body text.
class BackendWakingHint extends StatelessWidget {
  const BackendWakingHint({super.key});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      label:
          '${ColdStartCopy.title} ${ColdStartCopy.body} ${ColdStartCopy.footnote}',
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: AppTheme.primaryLight,
          borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
          border: Border.all(color: const Color(0xFFBFDBFE), width: 1),
        ),
        child: const Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: EdgeInsets.only(top: 2),
              child: SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
            SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    ColdStartCopy.title,
                    softWrap: true,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.slate900,
                      height: 1.3,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    ColdStartCopy.body,
                    softWrap: true,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: AppTheme.slate600,
                      height: 1.4,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    ColdStartCopy.footnote,
                    softWrap: true,
                    style: TextStyle(
                      fontSize: 11,
                      color: AppTheme.slate500,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Shows [BackendWakingHint] only while [isWaiting] stays true past [delay].
///
/// - 0–[delay]: renders nothing ([SizedBox.shrink]), so the existing
///   loading/progress state is the only thing visible.
/// - After [delay] with the same request still unresolved: renders the hint
///   *alongside* the existing loading state (this widget never replaces or
///   cancels the original request).
/// - When [isWaiting] becomes false (success or failure): the hint is
///   removed immediately and the caller's normal flow continues.
///
/// Single reusable location for the delayed-status behaviour so Dashboard,
/// Login, Register, History and Account do not duplicate timers.
class DelayedBackendWakingHint extends StatefulWidget {
  final bool isWaiting;
  final Duration delay;

  const DelayedBackendWakingHint({
    super.key,
    required this.isWaiting,
    this.delay = ColdStartCopy.wakeDelay,
  });

  @override
  State<DelayedBackendWakingHint> createState() =>
      _DelayedBackendWakingHintState();
}

class _DelayedBackendWakingHintState extends State<DelayedBackendWakingHint> {
  Timer? _timer;
  bool _showHint = false;

  @override
  void initState() {
    super.initState();
    _syncTimer(oldWaiting: false, newWaiting: widget.isWaiting);
  }

  @override
  void didUpdateWidget(DelayedBackendWakingHint oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isWaiting != widget.isWaiting ||
        oldWidget.delay != widget.delay) {
      _syncTimer(oldWaiting: oldWidget.isWaiting, newWaiting: widget.isWaiting);
    }
  }

  void _syncTimer({required bool oldWaiting, required bool newWaiting}) {
    // Became idle (success / failure / cancelled): hide immediately.
    if (!newWaiting) {
      _timer?.cancel();
      _timer = null;
      if (_showHint && mounted) {
        setState(() => _showHint = false);
      } else {
        _showHint = false;
      }
      return;
    }
    // Already showing or already counting down for the same request: keep it.
    if (_showHint || _timer != null) return;
    // Newly waiting: start the delayed reveal; do NOT show immediately.
    _timer = Timer(widget.delay, () {
      if (!mounted) return;
      // Only reveal if the *same* request is still unresolved.
      if (widget.isWaiting) {
        setState(() => _showHint = true);
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _timer = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isWaiting || !_showHint) {
      return const SizedBox.shrink();
    }
    // Top gap only exists while the hint is visible, so fast responses
    // leave the existing layout byte-for-byte unchanged.
    return const Padding(
      padding: EdgeInsets.only(top: 12),
      child: BackendWakingHint(),
    );
  }
}
