import 'package:equatable/equatable.dart';

import '../../domain/models/booking_event.dart';

/// Lifecycle states for the vendor booking updates stream.
enum VendorNotificationsStatus { loading, ready, error }

/// Immutable state for [VendorNotificationsCubit].
final class VendorNotificationsState extends Equatable {
  VendorNotificationsState({
    required this.vendorId,
    this.status = VendorNotificationsStatus.loading,
    List<BookingEvent> events = const <BookingEvent>[],
    Set<String> unreadEventIds = const <String>{},
    this.errorMessage,
  }) : events = List<BookingEvent>.unmodifiable(events),
       unreadEventIds = Set<String>.unmodifiable(unreadEventIds);

  final String vendorId;
  final VendorNotificationsStatus status;
  final List<BookingEvent> events;
  final Set<String> unreadEventIds;
  final String? errorMessage;

  bool get isLoading => status == VendorNotificationsStatus.loading;
  bool get isReady => status == VendorNotificationsStatus.ready;
  bool get hasError => status == VendorNotificationsStatus.error;
  bool get isEmpty =>
      status == VendorNotificationsStatus.ready && events.isEmpty;
  int get unreadCount => unreadEventIds.length;

  VendorNotificationsState copyWith({
    VendorNotificationsStatus? status,
    List<BookingEvent>? events,
    Set<String>? unreadEventIds,
    String? errorMessage,
    bool clearErrorMessage = false,
  }) {
    return VendorNotificationsState(
      vendorId: vendorId,
      status: status ?? this.status,
      events: events ?? this.events,
      unreadEventIds: unreadEventIds ?? this.unreadEventIds,
      errorMessage: clearErrorMessage
          ? null
          : (errorMessage ?? this.errorMessage),
    );
  }

  @override
  List<Object?> get props => <Object?>[
    vendorId,
    status,
    events,
    unreadEventIds,
    errorMessage,
  ];
}
