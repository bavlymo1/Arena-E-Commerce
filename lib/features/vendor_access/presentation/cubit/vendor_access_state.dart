import 'package:equatable/equatable.dart';

/// Immutable states emitted by [VendorAccessCubit].
sealed class VendorAccessState extends Equatable {
  const VendorAccessState();

  @override
  List<Object?> get props => const <Object?>[];
}

/// Access verification is currently in progress.
final class AccessChecking extends VendorAccessState {
  const AccessChecking();
}

/// Device is enrolled and authorized for [vendorId].
final class AccessAllowed extends VendorAccessState {
  const AccessAllowed(this.vendorId);

  final String vendorId;

  @override
  List<Object?> get props => <Object?>[vendorId];
}

/// Device has an anonymous identity [uid] that is not yet enrolled.
final class AccessNotEnrolled extends VendorAccessState {
  const AccessNotEnrolled(this.uid);

  final String uid;

  @override
  List<Object?> get props => <Object?>[uid];
}

/// Access check failed with a safe user-facing [message].
final class AccessError extends VendorAccessState {
  const AccessError(this.message);

  final String message;

  @override
  List<Object?> get props => <Object?>[message];
}
