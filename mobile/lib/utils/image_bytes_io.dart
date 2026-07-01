import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image_picker/image_picker.dart';

Future<List<int>> compressPickedImage(XFile file) async {
  return await FlutterImageCompress.compressWithFile(file.path, quality: 70) ??
      await file.readAsBytes();
}
