import 'dart:async';

import 'package:e_commerce_project/app/startup/startup_cubit.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('coalesces busy retries and ignores completion after close', () async {
    final completion = Completer<String>();
    var calls = 0;
    final cubit = StartupCubit(() {
      calls++;
      return completion.future;
    });
    final attempt = cubit.retry();
    await cubit.retry();
    expect(calls, 1);
    await cubit.close();
    completion.complete('Unavailable');
    await attempt;
    expect(cubit.isClosed, isTrue);
  });
  test('failed check remains unavailable and can be retried', () async {
    var calls = 0;
    final cubit = StartupCubit(() async {
      if (calls++ == 0) throw StateError('Internal detail');
      return 'Configuration missing';
    });
    await cubit.retry();
    expect(cubit.state.checking, isFalse);
    expect(cubit.state.message, 'Startup could not be checked. Please retry.');
    await cubit.retry();
    expect(cubit.state.message, 'Configuration missing');
    await cubit.close();
  });
}
