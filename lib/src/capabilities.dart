abstract interface class NebulaAuth {
  Future<bool> restoreSession();
  Future<void> signOut();
}

abstract interface class NebulaConfig {
  Future<void> refresh();
  bool isEnabled(String key, {bool fallback = false});
}

abstract interface class NebulaAnalytics {
  Future<void> track(String event, {Map<String, Object?> properties});
  Future<void> flush();
}

/// Marker contract. Concrete asset operations are frozen in Sprint F3.
abstract interface class NebulaAsset {}

/// Marker contract. Concrete notification operations are frozen in Sprint F3.
abstract interface class NebulaNotification {}

/// Marker contract. Concrete payment operations are frozen in Sprint F4.
abstract interface class NebulaPayment {}

/// Marker contract. Concrete AI operations are frozen in Sprint F4.
abstract interface class NebulaAi {}
