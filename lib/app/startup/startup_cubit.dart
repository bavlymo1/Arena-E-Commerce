import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

typedef StartupCheck = Future<String> Function();

final class StartupState extends Equatable {
  const StartupState({this.checking = true, this.message});
  final bool checking;
  final String? message;
  @override
  List<Object?> get props => [checking, message];
}

final class StartupCubit extends Cubit<StartupState> {
  StartupCubit(this._check) : super(const StartupState());
  final StartupCheck _check;
  bool _running = false;

  Future<void> retry() async {
    if (_running || isClosed) return;
    _running = true;
    emit(const StartupState());
    try {
      final reason = await _check();
      if (!isClosed) emit(StartupState(checking: false, message: reason));
    } catch (_) {
      if (!isClosed) {
        emit(
          const StartupState(
            checking: false,
            message: 'Startup could not be checked. Please retry.',
          ),
        );
      }
    } finally {
      _running = false;
    }
  }
}
