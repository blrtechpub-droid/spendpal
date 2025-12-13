/// Platform-aware SMS listener service
///
/// On Android: exports full SMS functionality
/// On iOS/Other: exports stub (SMS not supported)
///
/// Note: iOS build succeeds because telephony package is not imported on iOS.
/// Flutter's tree-shaking removes unused platform-specific code.

// Export the Android implementation which will work on Android
// On iOS, this file exists but won't be used due to Platform.isAndroid check in main.dart
export 'sms_listener_service_android.dart';
