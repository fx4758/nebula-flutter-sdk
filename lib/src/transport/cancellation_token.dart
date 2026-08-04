/// A cooperative cancellation signal bound to a single transport request.
///
/// Per [docs/06 §2] cancellation must propagate *into* the transport and abort
/// the underlying connection — it must not merely ignore the pending [Future].
/// The token is intentionally independent of any single async primitive so it
/// works across `dart:io` socket teardown.
///
/// Example:
/// ```dart
/// final token = NebulaCancellationToken();
/// final future = transport.send(request.copyWith(cancellationToken: token));
/// // later, on user navigation away:
/// token.cancel();
/// ```
final class NebulaCancellationToken {
  /// Creates a live, uncancelled token.
  NebulaCancellationToken();

  bool _cancelled = false;
  final List<void Function()> _listeners = <void Function()>[];

  /// True once [cancel] has been invoked.
  bool get isCancelled => _cancelled;

  /// Marks this token cancelled and synchronously notifies every registered
  /// listener (typically the transport, which tears down the socket).
  void cancel() {
    if (_cancelled) return;
    _cancelled = true;
    // Snapshot to allow listeners to call [offCancel] without mutating during
    // iteration.
    final List<void Function()> current =
        List<void Function()>.from(_listeners);
    _listeners.clear();
    for (final void Function() listener in current) {
      listener();
    }
  }

  /// Registers [listener] to be invoked when [cancel] fires. If the token is
  /// already cancelled, [listener] is invoked immediately. Returns nothing;
  /// use [offCancel] to detach.
  void onCancel(void Function() listener) {
    if (_cancelled) {
      listener();
      return;
    }
    _listeners.add(listener);
  }

  /// Detaches a previously registered listener.
  void offCancel(void Function() listener) {
    _listeners.remove(listener);
  }
}
