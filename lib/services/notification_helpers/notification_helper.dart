// lib/services/notification_helper.dart
// Conditional import — web gets the stub (no-op), mobile gets the real impl.
// This makes the incompatible flutter_local_notifications code never compile
// on web, fixing all "Too many positional arguments" and "named param" errors.

export 'notification_helper_stub.dart'
if (dart.library.io) 'notification_helper_mobile.dart';