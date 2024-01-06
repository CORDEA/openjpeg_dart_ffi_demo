import 'package:image/image.dart' as img;
import 'package:openjpeg_dart_ffi_demo/openjpeg_dart_ffi_demo.dart';

Future<void> main(List<String> arguments) async {
  final decoded = await decode(arguments.first);
  final image = img.Image(
    width: decoded.width,
    height: decoded.height,
    numChannels: decoded.color.channels,
  );
  var i = 0;
  for (final img in image) {
    switch (decoded.color) {
      case ColorRgb(value: final value):
        img
          ..r = value[i].r
          ..g = value[i].g
          ..b = value[i].b;
      case ColorRgba(value: final value):
        img
          ..r = value[i].r
          ..g = value[i].g
          ..b = value[i].b
          ..a = value[i].a;
      case ColorGray(value: final value):
        img.r = value[i];
    }
    i++;
  }
  img.encodePngFile('out.png', image);
}
