import 'dart:ffi' as ffi;
import 'dart:io';

import 'package:ffi/ffi.dart' as ffi;

import 'openjpeg_generated_bindings.dart';

const _lib = 'openjpeg/build/bin/libopenjp2.2.5.0';
final _dylib = () {
  if (Platform.isMacOS || Platform.isIOS) {
    return ffi.DynamicLibrary.open('$_lib.dylib');
  }
  if (Platform.isAndroid || Platform.isLinux) {
    return ffi.DynamicLibrary.open('$_lib.so');
  }
  if (Platform.isWindows) {
    return ffi.DynamicLibrary.open('$_lib.dll');
  }
  throw UnsupportedError('Unknown platform: ${Platform.operatingSystem}');
}();

final _bindings = OpenJpegBindings(_dylib);

void onMessage(ffi.Pointer<ffi.Char> message, ffi.Pointer<ffi.Void> data) {
  stdout.write(message.cast<ffi.Utf8>().toDartString());
}

Future<void> decode(String fileName) async {
  final parameters = ffi.calloc<opj_dparameters_t>();
  _bindings.opj_set_default_decoder_parameters(parameters);
  final codec = _bindings.opj_create_decompress(CODEC_FORMAT.OPJ_CODEC_JP2);
  if (_bindings.opj_setup_decoder(codec, parameters) <= 0) {
    _bindings.opj_destroy_codec(codec);
    ffi.calloc.free(parameters);
    throw ArgumentError('Failed to set up decoder.');
  }

  final callback =
      opj_stream_write_fn.fromFunction<opj_msg_callbackFunction>(onMessage);
  _bindings.opj_set_warning_handler(codec, callback, ffi.nullptr);
  _bindings.opj_set_error_handler(codec, callback, ffi.nullptr);
  _bindings.opj_set_info_handler(codec, callback, ffi.nullptr);

  final file = fileName.toNativeUtf8();
  final stream =
      _bindings.opj_stream_create_default_file_stream(file.cast(), 1);
  final imagePtrPtr = ffi.Pointer<ffi.Pointer<opj_image_t>>.fromAddress(
    ffi.calloc<opj_image_t>().address,
  );
  final imagePtr = imagePtrPtr.value;
  try {
    if (_bindings.opj_read_header(stream, codec, imagePtrPtr) <= 0) {
      throw ArgumentError('Failed to read the header.');
    }
    if (_bindings.opj_decode(codec, stream, imagePtr) <= 0) {
      throw ArgumentError('Failed to decode.');
    }
    if (_bindings.opj_end_decompress(codec, stream) <= 0) {
      throw ArgumentError('Failed to finalize.');
    }
  } finally {
    _bindings.opj_destroy_codec(codec);
    _bindings.opj_stream_destroy(stream);
    _bindings.opj_image_destroy(imagePtr);
    ffi.calloc.free(parameters);
    ffi.calloc.free(file);
  }
}
