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

Future<Image> decode(String fileName) async {
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
  try {
    if (_bindings.opj_read_header(stream, codec, imagePtrPtr) <= 0) {
      throw ArgumentError('Failed to read the header.');
    }
    if (_bindings.opj_decode(codec, stream, imagePtrPtr.value) <= 0) {
      throw ArgumentError('Failed to decode.');
    }
    if (_bindings.opj_end_decompress(codec, stream) <= 0) {
      throw ArgumentError('Failed to finalize.');
    }
  } on ArgumentError catch (_) {
    _bindings.opj_image_destroy(imagePtrPtr.value);
    rethrow;
  } finally {
    _bindings.opj_destroy_codec(codec);
    _bindings.opj_stream_destroy(stream);
    ffi.calloc.free(parameters);
    ffi.calloc.free(file);
  }

  final image = imagePtrPtr.value.ref;
  final channels = image.numcomps;
  final Color color;
  switch (channels) {
    case 1:
      color = ColorGray([]);
    case 3:
      color = ColorRgb([]);
    case 4:
      color = ColorRgba([]);
    default:
      throw ArgumentError('Invalid number of channels.');
  }
  final width = image.comps[0].w;
  final height = image.comps[0].h;
  for (var h = 0; h < height; h++) {
    final offset = h * width;
    for (var w = 0; w < width; w++) {
      final i = offset + w;
      switch (color) {
        case ColorRgb(value: final value):
          value.add((
            r: image.comps[0].data[i],
            g: image.comps[1].data[i],
            b: image.comps[2].data[i],
          ));
        case ColorRgba(value: final value):
          value.add((
            r: image.comps[0].data[i],
            g: image.comps[1].data[i],
            b: image.comps[2].data[i],
            a: image.comps[3].data[i],
          ));
        case ColorGray(value: final value):
          value.add(image.comps[0].data[i]);
      }
    }
  }
  _bindings.opj_image_destroy(imagePtrPtr.value);
  return Image(width: width, height: height, color: color);
}

class Image {
  Image({required this.width, required this.height, required this.color});

  final int width;
  final int height;
  final Color color;
}

sealed class Color<T> {
  Color(this.value);

  final List<T> value;

  int get channels;
}

final class ColorRgb extends Color<({int r, int g, int b})> {
  ColorRgb(super.value);

  @override
  int get channels => 3;
}

final class ColorRgba extends Color<({int r, int g, int b, int a})> {
  ColorRgba(super.value);

  @override
  int get channels => 4;
}

final class ColorGray extends Color<int> {
  ColorGray(super.value);

  @override
  int get channels => 1;
}
