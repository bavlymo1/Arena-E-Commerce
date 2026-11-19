import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';

import '../cubit/show_form_state.dart';

/// Native [ShowPosterPicker] adapter backed by [ImagePicker].
final class ImagePickerShowPosterAdapter {
  ImagePickerShowPosterAdapter({ImagePicker? picker, bool? isAndroid})
    : _picker = picker ?? ImagePicker(),
      _isAndroidOverride = isAndroid;

  static const double defaultMaxWidth = 900;
  static const double defaultMaxHeight = 900;
  static const int defaultImageQuality = 75;

  final ImagePicker _picker;
  final bool? _isAndroidOverride;
  bool _lostDataChecked = false;

  bool get _supportsLostDataRecovery =>
      _isAndroidOverride ??
      (!kIsWeb && defaultTargetPlatform == TargetPlatform.android);

  /// Picks an image from [source] and returns its bytes, or `null` on cancel.
  Future<Uint8List?> pickPoster(ShowPosterSource source) async {
    final file = await _picker.pickImage(
      source: _toImageSource(source),
      maxWidth: defaultMaxWidth,
      maxHeight: defaultMaxHeight,
      imageQuality: defaultImageQuality,
    );
    if (file == null) return null;
    return _readPoster(file);
  }

  /// Callable [ShowPosterPicker] entrypoint forwarding to [pickPoster].
  Future<Uint8List?> call(ShowPosterSource source) => pickPoster(source);

  /// Retrieves Android lost-activity poster bytes at most once per instance.
  ///
  /// Returns `null` off Android, when nothing was lost, for non-image data, or
  /// on repeat calls; propagates plugin or read errors for caller feedback.
  Future<Uint8List?> retrieveLostPoster() async {
    if (_lostDataChecked) return null;
    // Mark checked before awaiting so concurrent callers cannot double-read.
    _lostDataChecked = true;
    if (!_supportsLostDataRecovery) return null;

    final response = await _picker.retrieveLostData();
    if (response.isEmpty) return null;

    final exception = response.exception;
    if (exception != null) {
      throw exception;
    }

    if (response.type != null && response.type != RetrieveType.image) {
      return null;
    }

    final file = _selectRecoveredFile(response);
    if (file == null) return null;
    return _readPoster(file);
  }

  static Future<Uint8List> _readPoster(XFile file) async {
    final bytes = await file.readAsBytes();
    // Leave the form's existing empty-file and size feedback in charge.
    if (bytes.isNotEmpty &&
        bytes.length <= ShowFormState.maxPosterBytes &&
        (bytes.length < 3 ||
            bytes[0] != 0xff ||
            bytes[1] != 0xd8 ||
            bytes[2] != 0xff)) {
      throw const FormatException('Poster must be JPEG');
    }
    return Uint8List.fromList(bytes);
  }

  static ImageSource _toImageSource(ShowPosterSource source) =>
      switch (source) {
        ShowPosterSource.gallery => ImageSource.gallery,
        ShowPosterSource.camera => ImageSource.camera,
      };

  static XFile? _selectRecoveredFile(LostDataResponse response) {
    if (response.file != null) return response.file;
    final files = response.files;
    if (files != null && files.isNotEmpty) return files.last;
    return null;
  }
}
