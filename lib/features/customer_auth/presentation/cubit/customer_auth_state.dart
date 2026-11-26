import 'package:equatable/equatable.dart';

import '../../domain/models/app_user.dart';

/// Lifecycle states for the customer authentication gate and screens.
enum CustomerAuthStatus { checking, signedOut, signedIn, error }

/// Immutable authentication state exposed by [CustomerAuthCubit].
final class CustomerAuthState extends Equatable {
  const CustomerAuthState({
    this.status = CustomerAuthStatus.checking,
    this.user,
    this.busy = false,
    this.errorMessage,
  });

  final CustomerAuthStatus status;
  final AppUser? user;
  final bool busy;
  final String? errorMessage;

  bool get isChecking => status == CustomerAuthStatus.checking;
  bool get isSignedIn => status == CustomerAuthStatus.signedIn && user != null;
  bool get hasError => status == CustomerAuthStatus.error;

  CustomerAuthState copyWith({
    CustomerAuthStatus? status,
    AppUser? user,
    bool clearUser = false,
    bool? busy,
    String? errorMessage,
    bool clearErrorMessage = false,
  }) {
    return CustomerAuthState(
      status: status ?? this.status,
      user: clearUser ? null : (user ?? this.user),
      busy: busy ?? this.busy,
      errorMessage: clearErrorMessage
          ? null
          : (errorMessage ?? this.errorMessage),
    );
  }

  @override
  List<Object?> get props => <Object?>[status, user, busy, errorMessage];
}
