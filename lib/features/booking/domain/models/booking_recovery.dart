import 'booking.dart';

sealed class BookingRecovery {
  BookingRecovery({required this.bookingId, required this.customerUid}) {
    if (bookingId.trim().isEmpty || customerUid.trim().isEmpty) {
      throw ArgumentError('Recovery reference and original UID are required');
    }
  }

  final String bookingId;
  final String customerUid;
}

final class RecoveryConfirmed extends BookingRecovery {
  RecoveryConfirmed({
    required super.bookingId,
    required super.customerUid,
    required this.booking,
  }) {
    if (booking.request.bookingId != bookingId ||
        booking.request.customerUid != customerUid) {
      throw ArgumentError('Recovery cannot confirm another reference or owner');
    }
  }

  final Booking booking;
}

final class RecoveryAuthoritativelyAbsent extends BookingRecovery {
  RecoveryAuthoritativelyAbsent({
    required super.bookingId,
    required super.customerUid,
  });
}

final class RecoveryUnresolved extends BookingRecovery {
  RecoveryUnresolved({
    required super.bookingId,
    required super.customerUid,
    required this.reason,
  });

  final String reason;
}
