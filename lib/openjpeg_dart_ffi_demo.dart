import 'dart:ffi' as ffi;
import 'dart:io';

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
