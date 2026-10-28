import 'dart:async';

/// Debounces widget refreshes so a burst of saves rebuilds a kind once.
///
/// Apps usually keep one scheduler per kind, so editing one module never
/// rebuilds another module's widget.
class WidgetRefreshScheduler {
  /// Purpose: Create a scheduler.
  /// Inputs: `onRefresh` — rebuilds and publishes the kind; `delay` — quiet
  /// time before it runs (default 2 seconds).
  /// Returns: None.
  /// Side effects: None.
  /// Notes: Errors from `onRefresh` are passed to `onError` and otherwise
  /// swallowed: a stale widget is harmless, a crash in a timer is not.
  WidgetRefreshScheduler({
    required this.onRefresh,
    this.delay = const Duration(seconds: 2),
    this.onError,
  });

  /// Rebuilds and publishes.
  final Future<void> Function() onRefresh;

  /// Quiet time before a scheduled refresh runs.
  final Duration delay;

  /// Receives refresh failures.
  final void Function(Object error, StackTrace stack)? onError;

  Timer? _timer;

  /// Purpose: Whether a refresh is waiting to run.
  /// Inputs: None.
  /// Returns: `bool`.
  /// Side effects: None.
  /// Notes: None.
  bool get isPending => _timer?.isActive ?? false;

  /// Purpose: Schedule a refresh after [delay], restarting any pending one.
  /// Inputs: None.
  /// Returns: None.
  /// Side effects: Starts a timer.
  /// Notes: None.
  void schedule() {
    _timer?.cancel();
    _timer = Timer(delay, () => unawaited(_run()));
  }

  /// Purpose: Run a pending refresh now, or a fresh one when none is pending.
  /// Inputs: None.
  /// Returns: Completes when the refresh finishes.
  /// Side effects: Cancels the timer and calls [onRefresh].
  /// Notes: Use before the app goes to the background.
  Future<void> flush() {
    _timer?.cancel();
    _timer = null;
    return _run();
  }

  /// Purpose: Drop a pending refresh.
  /// Inputs: None.
  /// Returns: None.
  /// Side effects: Cancels the timer.
  /// Notes: None.
  void cancel() {
    _timer?.cancel();
    _timer = null;
  }

  /// Purpose: Call [onRefresh] and route its failure.
  /// Inputs: None.
  /// Returns: Completes when done.
  /// Side effects: Calls [onRefresh] and maybe [onError].
  /// Notes: None.
  Future<void> _run() async {
    try {
      await onRefresh();
    } catch (error, stack) {
      onError?.call(error, stack);
    }
  }
}
