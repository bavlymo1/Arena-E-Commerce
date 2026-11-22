import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/models/app_user.dart';
import '../../domain/repositories/customer_auth_repository.dart';
import 'customer_auth_state.dart';

/// Manages customer authentication session state, login, registration, and logout.
final class CustomerAuthCubit extends Cubit<CustomerAuthState> {
  CustomerAuthCubit(this._repository, {bool autoStart = true})
    : super(const CustomerAuthState()) {
    if (autoStart) {
      unawaited(start());
    }
  }

  static const String streamErrorMessage =
      'Unable to verify your session. Try again.';
  static const String loginErrorMessage =
      'Unable to sign in. Check your email and password and try again.';
  static const String registerErrorMessage =
      'Unable to create account. Check your details and try again.';
  static const String logoutErrorMessage = 'Unable to sign out. Try again.';
  static const String emailRequiredMessage = 'Enter your email address.';
  static const String emailInvalidMessage = 'Enter a valid email address.';
  static const String passwordRequiredMessage = 'Enter your password.';

  static final RegExp _emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  final CustomerAuthRepository _repository;
  StreamSubscription<AppUser?>? _authSubscription;
  Future<void> _cancellation = Future<void>.value();
  Future<void>? _activeStartFuture;
  int _listenGeneration = 0;
  int _authEventSequence = 0;
  bool _awaitingInitialEvent = false;
  bool _openingSubscription = false;
  Object? _activeOperation;

  /// Validates an email address without mutating or exposing credentials.
  static String? validateEmail(String email) {
    final trimmed = email.trim();
    if (trimmed.isEmpty) return emailRequiredMessage;
    if (!_emailPattern.hasMatch(trimmed)) return emailInvalidMessage;
    return null;
  }

  /// Validates that a password was provided without inventing extra complexity rules.
  static String? validatePassword(String password) {
    if (password.isEmpty) return passwordRequiredMessage;
    return null;
  }

  /// Subscribes to authentication state changes, coalescing active startup calls.
  Future<void> start() {
    if (isClosed) return Future<void>.value();
    if ((_awaitingInitialEvent ||
            _openingSubscription ||
            (_authSubscription != null && !state.hasError)) &&
        _activeStartFuture != null) {
      return _activeStartFuture!;
    }
    return _startListening();
  }

  /// Re-subscribes to authentication changes after an error or disconnect.
  Future<void> retry() {
    if (isClosed) return Future<void>.value();
    if (_openingSubscription && _activeStartFuture != null) {
      return _activeStartFuture!;
    }
    return _startListening();
  }

  /// Submits email and password to sign in; identity updates arrive via auth stream.
  Future<void> login(String email, String password) async {
    if (isClosed || state.busy) return;
    final validationError = validateEmail(email) ?? validatePassword(password);
    if (validationError != null) {
      emit(
        state.copyWith(
          status: state.user != null
              ? CustomerAuthStatus.signedIn
              : CustomerAuthStatus.signedOut,
          busy: false,
          errorMessage: validationError,
        ),
      );
      return;
    }
    await _runAuthOperation(
      () => _repository.login(email.trim(), password),
      failureMessage: loginErrorMessage,
    );
  }

  /// Submits email and password to register; identity updates arrive via auth stream.
  Future<void> register(String email, String password) async {
    if (isClosed || state.busy) return;
    final validationError = validateEmail(email) ?? validatePassword(password);
    if (validationError != null) {
      emit(
        state.copyWith(
          status: state.user != null
              ? CustomerAuthStatus.signedIn
              : CustomerAuthStatus.signedOut,
          busy: false,
          errorMessage: validationError,
        ),
      );
      return;
    }
    await _runAuthOperation(
      () => _repository.register(email.trim(), password),
      failureMessage: registerErrorMessage,
    );
  }

  /// Signs out the current customer; identity clearing arrives via auth stream.
  Future<void> logout() async {
    if (isClosed || state.busy) return;
    await _runAuthOperation(
      _repository.logout,
      failureMessage: logoutErrorMessage,
    );
  }

  Future<void> _runAuthOperation(
    Future<void> Function() action, {
    required String failureMessage,
  }) async {
    final operation = Object();
    _activeOperation = operation;
    final startListenGeneration = _listenGeneration;
    final startAuthEventSequence = _authEventSequence;
    emit(state.copyWith(busy: true, clearErrorMessage: true));

    try {
      await action();
      if (!_isCurrentOperation(
        operation,
        startListenGeneration,
        startAuthEventSequence,
      )) {
        return;
      }
      _activeOperation = null;
      emit(state.copyWith(busy: false));
    } catch (_) {
      if (!_isCurrentOperation(
        operation,
        startListenGeneration,
        startAuthEventSequence,
      )) {
        return;
      }
      _activeOperation = null;
      final resolvedStatus = state.status == CustomerAuthStatus.checking
          ? (state.user != null
                ? CustomerAuthStatus.signedIn
                : CustomerAuthStatus.signedOut)
          : state.status;
      emit(
        state.copyWith(
          status: resolvedStatus,
          busy: false,
          errorMessage: failureMessage,
        ),
      );
    }
  }

  bool _isCurrentOperation(
    Object operation,
    int startListenGeneration,
    int startAuthEventSequence,
  ) {
    return !isClosed &&
        identical(_activeOperation, operation) &&
        startListenGeneration == _listenGeneration &&
        startAuthEventSequence == _authEventSequence;
  }

  Future<void> _startListening() {
    final generation = ++_listenGeneration;
    _authEventSequence++;
    _activeOperation = null;
    _awaitingInitialEvent = true;
    _openingSubscription = true;

    emit(const CustomerAuthState(status: CustomerAuthStatus.checking));

    final startFuture = _openSubscription(generation);
    _activeStartFuture = startFuture;
    return startFuture;
  }

  Future<void> _openSubscription(int generation) async {
    try {
      await _cancelSubscription();
      if (isClosed || generation != _listenGeneration) return;
      _authSubscription = _repository.authChanges().listen(
        (user) => _onAuthChanged(generation, user),
        onError: (Object _) => _onStreamError(generation),
        onDone: () {
          if (generation == _listenGeneration) {
            _authSubscription = null;
            _awaitingInitialEvent = false;
          }
        },
      );
    } catch (_) {
      _onStreamError(generation);
      await _cancelSubscription();
    } finally {
      if (generation == _listenGeneration) {
        _openingSubscription = false;
      }
    }
  }

  void _onAuthChanged(int generation, AppUser? user) {
    if (isClosed || generation != _listenGeneration) return;
    _awaitingInitialEvent = false;
    _authEventSequence++;
    _activeOperation = null;

    if (user != null) {
      emit(CustomerAuthState(status: CustomerAuthStatus.signedIn, user: user));
    } else {
      emit(const CustomerAuthState(status: CustomerAuthStatus.signedOut));
    }
  }

  void _onStreamError(int generation) {
    if (isClosed || generation != _listenGeneration) return;
    _awaitingInitialEvent = false;
    _authEventSequence++;
    _activeOperation = null;

    emit(
      CustomerAuthState(
        status: CustomerAuthStatus.error,
        user: state.user,
        errorMessage: streamErrorMessage,
      ),
    );
  }

  Future<void> _cancelSubscription() {
    final subscription = _authSubscription;
    _authSubscription = null;
    if (subscription == null) return _cancellation;
    return _cancellation = Future.wait<void>(<Future<void>>[
      _cancellation,
      Future<void>.sync(subscription.cancel).catchError((Object _) {}),
    ]).then((_) {});
  }

  @override
  Future<void> close() async {
    _listenGeneration++;
    _authEventSequence++;
    _activeOperation = null;
    _awaitingInitialEvent = false;
    await Future.wait<void>(<Future<void>>[
      _cancelSubscription(),
      super.close(),
    ]);
  }
}
