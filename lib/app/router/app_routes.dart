/// Canonical route patterns, parameter names, and URI path builders for
/// Customer and Vendor navigation graphs.
abstract final class AppRoutes {
  static const String showIdParam = 'showId';
  static const String sessionIdParam = 'sessionId';
  static const String bookingIdParam = 'bookingId';

  static const String customerStartup = '/startup';
  static const String customerLogin = '/login';
  static const String customerRegister = '/register';
  static const String customerAccount = '/account';
  static const String customerDiscover = '/discover';
  static const String customerShowDetails = '/show/:showId';
  static const String customerSeatSelection =
      '/show/:showId/session/:sessionId';
  static const String customerBookingResult =
      '/show/:showId/session/:sessionId/result/:bookingId';

  static const String vendorShows = '/shows';
  static const String vendorAddShow = '/add-show';
  static const String vendorShowDetails = '/show/:showId';
  static const String vendorUpdates = '/updates';

  static String customerShowDetailsPath(String showId) =>
      '/show/${Uri.encodeComponent(showId)}';

  static String customerSeatSelectionPath(String showId, String sessionId) =>
      '${customerShowDetailsPath(showId)}/session/'
      '${Uri.encodeComponent(sessionId)}';

  static String customerBookingResultPath(
    String showId,
    String sessionId,
    String bookingId,
  ) =>
      '${customerSeatSelectionPath(showId, sessionId)}/result/'
      '${Uri.encodeComponent(bookingId)}';

  static String vendorShowDetailsPath(String showId) =>
      '/show/${Uri.encodeComponent(showId)}';
}
