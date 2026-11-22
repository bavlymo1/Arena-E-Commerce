import 'package:equatable/equatable.dart';

import '../../domain/models/alert_permission.dart';
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
    this.alertPermission = AlertPermission.unknown,
    this.errorMessage,
  }) : events = List<BookingEvent>.unmodifiable(events),
       unreadEventIds = Set<String>.unmodifiable(unreadEventIds);

  final String vendorId;
  final VendorNotificationsStatus status;
  final List<BookingEvent> events;
  final Set<String> unreadEventIds;
  final AlertPermission alertPermission;
  final String? errorMessage;

  bool get isLoading => status == VendorNotificationsStatus.loading;
  bool get hasError => status == VendorNotificationsStatus.error;
  bool get isEmpty =>
      status == VendorNotificationsStatus.ready && events.isEmpty;
  int get unreadCount => unreadEventIds.length;
  bool get isAlertPermissionDenied => alertPermission == AlertPermission.denied;

  VendorNotificationsState copyWith({
    VendorNotificationsStatus? status,
    List<BookingEvent>? events,
    Set<String>? unreadEventIds,
    AlertPermission? alertPermission,
    String? errorMessage,
    bool clearErrorMessage = false,
  }) {
    return VendorNotificationsState(
      vendorId: vendorId,
      status: status ?? this.status,
      events: events ?? this.events,
      unreadEventIds: unreadEventIds ?? this.unreadEventIds,
      alertPermission: alertPermission ?? this.alertPermission,
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
    alertPermission,
    errorMessage,
  ];
}
