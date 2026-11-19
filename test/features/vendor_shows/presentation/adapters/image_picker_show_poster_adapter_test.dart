import 'dart:async';

import 'package:e_commerce_project/features/vendor_shows/presentation/adapters/image_picker_show_poster_adapter.dart';
import 'package:e_commerce_project/features/vendor_shows/presentation/cubit/show_form_cubit.dart';
import 'package:e_commerce_project/features/vendor_shows/presentation/cubit/show_form_state.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../support/fake_shows_repository.dart';

final class _RecordedPickCall {
  const _RecordedPickCall({
    required this.source,
    required this.maxWidth,
    required this.maxHeight,
    required this.imageQuality,
  });

  final ImageSource source;
  final double? maxWidth;
  final double? maxHeight;
  final int? imageQuality;
}

final class _FakeImagePicker extends ImagePicker {
  final List<_RecordedPickCall> pickCalls = <_RecordedPickCall>[];
  int retrieveLostDataCalls = 0;

  Future<XFile?> Function()? onPickImage;
  Future<LostDataResponse> Function()? onRetrieveLostData;

  @override
  Future<XFile?> pickImage({
    required ImageSource source,
    double? maxWidth,
    double? maxHeight,
    int? imageQuality,
    CameraDevice preferredCameraDevice = CameraDevice.rear,
    bool requestFullMetadata = true,
  }) async {
    pickCalls.add(
      _RecordedPickCall(
        source: source,
        maxWidth: maxWidth,
        maxHeight: maxHeight,
        imageQuality: imageQuality,
      ),
    );
    final handler = onPickImage;
    if (handler == null) return null;
    return handler();
  }

  @override
  Future<LostDataResponse> retrieveLostData() async {
    retrieveLostDataCalls++;
    final handler = onRetrieveLostData;
    if (handler == null) return LostDataResponse.empty();
    return handler();
  }
}

final class _FailingXFile extends XFile {
  _FailingXFile() : super('unreadable_poster.jpg');

  @override
  Future<Uint8List> readAsBytes() =>
      Future<Uint8List>.error(StateError('unreadable'));
}

void main() {
  test('maps gallery and camera sources with 900x900 quality 75 defaults and returns defensive byte copies', () async {
    final gallerySource = Uint8List.fromList(<int>[10, 20, 30, 40]);
    final cameraSource = Uint8List.fromList(<int>[50, 60, 70]);
    final picker = _FakeImagePicker()
      ..onPickImage = () async => XFile.fromData(gallerySource);
    final adapter = ImagePickerShowPosterAdapter(picker: picker);

    final ShowPosterPicker callback = adapter.call;
    final galleryBytes = await callback(ShowPosterSource.gallery);
    expect(galleryBytes, <int>[10, 20, 30, 40]);
    galleryBytes![0] = 99;
    expect(gallerySource[0], 10);

    picker.onPickImage = () async => XFile.fromData(cameraSource);
    final cameraBytes = await adapter.pickPoster(ShowPosterSource.camera);
    expect(cameraBytes, <int>[50, 60, 70]);

    expect(picker.pickCalls, hasLength(2));
    expect(picker.pickCalls[0].source, ImageSource.gallery);
    expect(picker.pickCalls[0].maxWidth, 900);
    expect(picker.pickCalls[0].maxHeight, 900);
    expect(picker.pickCalls[0].imageQuality, 75);

    expect(picker.pickCalls[1].source, ImageSource.camera);
    expect(picker.pickCalls[1].maxWidth, 900);
    expect(picker.pickCalls[1].maxHeight, 900);
    expect(picker.pickCalls[1].imageQuality, 75);
  });

  test(
    'returns null on user cancellation for both gallery and camera',
    () async {
      final picker = _FakeImagePicker()..onPickImage = () async => null;
      final adapter = ImagePickerShowPosterAdapter(picker: picker);

      expect(await adapter.pickPoster(ShowPosterSource.gallery), isNull);
      expect(await adapter.pickPoster(ShowPosterSource.camera), isNull);
      expect(picker.pickCalls.map((c) => c.source), <ImageSource>[
        ImageSource.gallery,
        ImageSource.camera,
      ]);
    },
  );

  test('propagates picker plugin and file read failures', () async {
    final picker = _FakeImagePicker()
      ..onPickImage = () async => throw PlatformException(
        code: 'camera_access_denied',
        message: 'denied',
      );
    final adapter = ImagePickerShowPosterAdapter(picker: picker);

    await expectLater(
      adapter.pickPoster(ShowPosterSource.camera),
      throwsA(
        isA<PlatformException>().having(
          (e) => e.code,
          'code',
          'camera_access_denied',
        ),
      ),
    );

    picker.onPickImage = () async => _FailingXFile();
    await expectLater(
      adapter.pickPoster(ShowPosterSource.gallery),
      throwsStateError,
    );
  });

  test('recovers lost Android image from file or files list at most once per adapter instance', () async {
    final picker = _FakeImagePicker()
      ..onRetrieveLostData = () async => LostDataResponse(
        file: XFile.fromData(Uint8List.fromList(<int>[1, 2, 3])),
        type: RetrieveType.image,
      );
    final adapter = ImagePickerShowPosterAdapter(
      picker: picker,
      isAndroid: true,
    );

    expect(await adapter.retrieveLostPoster(), <int>[1, 2, 3]);
    expect(await adapter.retrieveLostPoster(), isNull);
    expect(picker.retrieveLostDataCalls, 1);

    final filesFallbackPicker = _FakeImagePicker()
      ..onRetrieveLostData = () async => LostDataResponse(
        files: <XFile>[
          XFile.fromData(Uint8List.fromList(<int>[4, 5])),
          XFile.fromData(Uint8List.fromList(<int>[6, 7, 8])),
        ],
        type: RetrieveType.image,
      );
    final filesAdapter = ImagePickerShowPosterAdapter(
      picker: filesFallbackPicker,
      isAndroid: true,
    );

    expect(await filesAdapter.retrieveLostPoster(), <int>[6, 7, 8]);
    expect(filesFallbackPicker.retrieveLostDataCalls, 1);
  });

  test('treats empty or non-image lost data as no recovered image and skips non-Android platforms', () async {
    final emptyPicker = _FakeImagePicker()
      ..onRetrieveLostData = () async => LostDataResponse.empty();
    final emptyAdapter = ImagePickerShowPosterAdapter(
      picker: emptyPicker,
      isAndroid: true,
    );
    expect(await emptyAdapter.retrieveLostPoster(), isNull);
    expect(await emptyAdapter.retrieveLostPoster(), isNull);
    expect(emptyPicker.retrieveLostDataCalls, 1);

    final videoPicker = _FakeImagePicker()
      ..onRetrieveLostData = () async => LostDataResponse(
        file: XFile.fromData(Uint8List.fromList(<int>[9, 9])),
        type: RetrieveType.video,
      );
    final videoAdapter = ImagePickerShowPosterAdapter(
      picker: videoPicker,
      isAndroid: true,
    );
    expect(await videoAdapter.retrieveLostPoster(), isNull);
    expect(videoPicker.retrieveLostDataCalls, 1);

    final nonAndroidPicker = _FakeImagePicker();
    final nonAndroidAdapter = ImagePickerShowPosterAdapter(
      picker: nonAndroidPicker,
      isAndroid: false,
    );
    expect(await nonAndroidAdapter.retrieveLostPoster(), isNull);
    expect(nonAndroidPicker.retrieveLostDataCalls, 0);

    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    final iosAdapter = ImagePickerShowPosterAdapter(picker: nonAndroidPicker);
    expect(await iosAdapter.retrieveLostPoster(), isNull);
    expect(nonAndroidPicker.retrieveLostDataCalls, 0);
  });

  test('propagates lost-data exceptions and still enforces one-shot recovery across retries and concurrency', () async {
    final responseErrorPicker = _FakeImagePicker()
      ..onRetrieveLostData = () async => LostDataResponse(
        exception: PlatformException(
          code: 'lost_data_error',
          message: 'failed',
        ),
        type: RetrieveType.image,
      );
    final responseErrorAdapter = ImagePickerShowPosterAdapter(
      picker: responseErrorPicker,
      isAndroid: true,
    );
    await expectLater(
      responseErrorAdapter.retrieveLostPoster(),
      throwsA(
        isA<PlatformException>().having(
          (e) => e.code,
          'code',
          'lost_data_error',
        ),
      ),
    );
    expect(await responseErrorAdapter.retrieveLostPoster(), isNull);
    expect(responseErrorPicker.retrieveLostDataCalls, 1);

    final throwPicker = _FakeImagePicker()
      ..onRetrieveLostData = () async => throw PlatformException(
        code: 'retrieve_failed',
        message: 'plugin error',
      );
    final throwAdapter = ImagePickerShowPosterAdapter(
      picker: throwPicker,
      isAndroid: true,
    );
    await expectLater(
      throwAdapter.retrieveLostPoster(),
      throwsA(
        isA<PlatformException>().having(
          (e) => e.code,
          'code',
          'retrieve_failed',
        ),
      ),
    );
    expect(await throwAdapter.retrieveLostPoster(), isNull);
    expect(throwPicker.retrieveLostDataCalls, 1);

    final unreadablePicker = _FakeImagePicker()
      ..onRetrieveLostData = () async =>
          LostDataResponse(file: _FailingXFile(), type: RetrieveType.image);
    final unreadableAdapter = ImagePickerShowPosterAdapter(
      picker: unreadablePicker,
      isAndroid: true,
    );
    await expectLater(unreadableAdapter.retrieveLostPoster(), throwsStateError);
    expect(await unreadableAdapter.retrieveLostPoster(), isNull);
    expect(unreadablePicker.retrieveLostDataCalls, 1);

    final gate = Completer<LostDataResponse>();
    final concurrentPicker = _FakeImagePicker()
      ..onRetrieveLostData = () => gate.future;
    final concurrentAdapter = ImagePickerShowPosterAdapter(
      picker: concurrentPicker,
      isAndroid: true,
    );

    final firstCall = concurrentAdapter.retrieveLostPoster();
    final secondCall = concurrentAdapter.retrieveLostPoster();
    expect(await secondCall, isNull);

    gate.complete(
      LostDataResponse(
        file: XFile.fromData(Uint8List.fromList(<int>[11, 22])),
        type: RetrieveType.image,
      ),
    );
    expect(await firstCall, <int>[11, 22]);
    expect(concurrentPicker.retrieveLostDataCalls, 1);
  });

  test('preserves form fields across cancel, failure, invalid payloads, and recovered bytes in ShowFormCubit', () async {
    final repo = FakeShowsRepository();
    addTearDown(repo.dispose);

    final picker = _FakeImagePicker()
      ..onPickImage = () async =>
          XFile.fromData(Uint8List.fromList(<int>[1, 2, 3, 4]));
    final adapter = ImagePickerShowPosterAdapter(
      picker: picker,
      isAndroid: true,
    );
    final cubit = ShowFormCubit(
      repo,
      vendorId: 'arena',
      posterPicker: adapter.call,
    );
    addTearDown(cubit.close);

    cubit.updateTitle('Neon Finals');
    cubit.updateDescription('Main arena event');
    cubit.updateShowDate('2026-12-10');
    cubit.updateSessionTime(0, '14:00');
    cubit.addSessionSlot();
    cubit.updateSessionTime(1, '19:00');

    await cubit.pickPoster(ShowPosterSource.gallery);
    expect(cubit.state.posterBytes, <int>[1, 2, 3, 4]);
    expect(cubit.state.posterError, isNull);

    // Cancel keeps prior poster and form fields.
    picker.onPickImage = () async => null;
    await cubit.pickPoster(ShowPosterSource.camera);
    expect(cubit.state.posterBytes, <int>[1, 2, 3, 4]);
    expect(cubit.state.posterError, isNull);
    expect(cubit.state.title, 'Neon Finals');
    expect(cubit.state.description, 'Main arena event');
    expect(cubit.state.showDate, '2026-12-10');
    expect(cubit.state.sessionTimes, <String>['14:00', '19:00']);

    // Picker error keeps prior poster and form fields.
    picker.onPickImage = () async => throw PlatformException(code: 'failed');
    await cubit.pickPoster(ShowPosterSource.camera);
    expect(cubit.state.posterError, ShowFormCubit.posterPickFailedMessage);
    expect(cubit.state.posterBytes, <int>[1, 2, 3, 4]);
    expect(cubit.state.title, 'Neon Finals');

    // Oversized and empty byte payloads use cubit validation without wiping fields.
    picker.onPickImage = () async =>
        XFile.fromData(Uint8List(ShowFormState.maxPosterBytes + 1));
    await cubit.pickPoster(ShowPosterSource.gallery);
    expect(cubit.state.posterError, ShowFormCubit.posterTooLargeMessage);
    expect(cubit.state.posterBytes, <int>[1, 2, 3, 4]);

    picker.onPickImage = () async => XFile.fromData(Uint8List(0));
    await cubit.pickPoster(ShowPosterSource.gallery);
    expect(cubit.state.posterError, ShowFormCubit.posterEmptyMessage);
    expect(cubit.state.posterBytes, <int>[1, 2, 3, 4]);

    // Recovered lost bytes flow into setPosterBytes cleanly.
    picker.onRetrieveLostData = () async => LostDataResponse(
      file: XFile.fromData(Uint8List.fromList(<int>[8, 9, 10])),
      type: RetrieveType.image,
    );
    cubit.setPosterBytes(await adapter.retrieveLostPoster());
    expect(cubit.state.posterBytes, <int>[8, 9, 10]);
    expect(cubit.state.posterError, isNull);
    expect(cubit.state.title, 'Neon Finals');
    expect(cubit.state.sessionTimes, <String>['14:00', '19:00']);

    // Oversized recovered bytes are rejected without clearing prior poster or fields.
    final oversizedRecoveryAdapter = ImagePickerShowPosterAdapter(
      picker: _FakeImagePicker()
        ..onRetrieveLostData = () async => LostDataResponse(
          file: XFile.fromData(Uint8List(ShowFormState.maxPosterBytes + 1)),
          type: RetrieveType.image,
        ),
      isAndroid: true,
    );
    cubit.setPosterBytes(await oversizedRecoveryAdapter.retrieveLostPoster());
    expect(cubit.state.posterError, ShowFormCubit.posterTooLargeMessage);
    expect(cubit.state.posterBytes, <int>[8, 9, 10]);
    expect(cubit.state.title, 'Neon Finals');
  });
}
