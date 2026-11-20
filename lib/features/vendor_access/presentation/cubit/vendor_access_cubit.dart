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
  int _generation = 0;

  /// Checks whether this device is enrolled for vendor management.
  Future<void> check() async {
    if (_inFlight || isClosed) return;
    _inFlight = true;
    final generation = ++_generation;
    if (state is! AccessChecking) {
      emit(const AccessChecking());
    }

    try {
      final access = await _repository.check();
      if (isClosed || generation != _generation) return;
      switch (access) {
        case VendorAllowed(:final vendorId):
          emit(AccessAllowed(vendorId));
        case VendorNotEnrolled(:final uid):
          emit(AccessNotEnrolled(uid));
      }
    } catch (_) {
      if (isClosed || generation != _generation) return;
      emit(const AccessError(VendorAccessStrings.checkErrorMessage));
    } finally {
      if (generation == _generation) {
        _inFlight = false;
      }
    }
  }

  /// Retries the device enrollment check.
  Future<void> retry() => check();

  @override
  Future<void> close() {
    _generation++;
    _inFlight = false;
    return super.close();
  }
}
