import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/models/vendor_access.dart';
import '../../domain/repositories/vendor_access_repository.dart';
import '../vendor_access_strings.dart';
import 'vendor_access_state.dart';

/// Manages silent vendor identity verification and enrollment retry flow.
final class VendorAccessCubit extends Cubit<VendorAccessState> {
  VendorAccessCubit(this._repository, {bool autoStart = true})
    : super(const AccessChecking()) {
    if (autoStart) {
      unawaited(check());
    }
  }

  final VendorAccessRepository _repository;
  bool _inFlight = false;

  /// Checks whether this device is enrolled for vendor management.
  Future<void> check() async {
    if (_inFlight || isClosed) return;
    _inFlight = true;
    if (state is! AccessChecking) {
      emit(const AccessChecking());
    }

    try {
      final access = await _repository.check();
      if (isClosed) return;
      switch (access) {
        case VendorAllowed(:final vendorId):
          emit(AccessAllowed(vendorId));
        case VendorNotEnrolled(:final uid):
          emit(AccessNotEnrolled(uid));
      }
    } catch (_) {
      if (isClosed) return;
      emit(const AccessError(VendorAccessStrings.checkErrorMessage));
    } finally {
      _inFlight = false;
    }
  }

  /// Retries the device enrollment check.
  Future<void> retry() => check();

  @override
  Future<void> close() {
    _inFlight = false;
    return super.close();
  }
}
