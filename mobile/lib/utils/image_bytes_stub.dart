import 'package:image_picker/image_picker.dart';

Future<List<int>> compressPickedImage(XFile file) => file.readAsBytes();
