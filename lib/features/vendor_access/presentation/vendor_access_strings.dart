/// User-facing copy for vendor access checking, enrollment, and error states.
abstract final class VendorAccessStrings {
  static const String screenTitle = 'Vendor access';
  static const String checkingMessage = 'Checking this device…';
  static const String notEnrolledTitle = 'Device not enrolled';
  static const String notEnrolledExplanation =
      'This device is not enrolled. Send this ID to the admin.';
  static const String deviceIdLabel = 'Device ID';
  static const String copyDeviceId = 'Copy Device ID';
  static const String deviceIdCopied = 'Device ID copied to clipboard.';
  static const String retry = 'Retry';
  static const String retrying = 'Checking…';
  static const String errorTitle = 'Unable to verify device';
  static const String checkErrorMessage =
      'Unable to check device access. Check your connection and try again.';
}
