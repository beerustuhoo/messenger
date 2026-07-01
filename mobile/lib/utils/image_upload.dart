import 'package:image_picker/image_picker.dart';

class PreparedImage {
  const PreparedImage({
    required this.bytes,
    required this.filename,
    required this.mimeType,
  });

  final List<int> bytes;
  final String filename;
  final String mimeType;
}

String detectImageMimeType(List<int> bytes) {
  if (bytes.length >= 4 &&
      bytes[0] == 0x89 &&
      bytes[1] == 0x50 &&
      bytes[2] == 0x4E &&
      bytes[3] == 0x47) {
    return 'image/png';
  }
  if (bytes.length >= 2 && bytes[0] == 0xFF && bytes[1] == 0xD8) {
    return 'image/jpeg';
  }
  return 'image/jpeg';
}

String ensureImageFilename(String name, String mimeType) {
  final lower = name.toLowerCase();
  if (lower.endsWith('.jpg') || lower.endsWith('.jpeg') || lower.endsWith('.png')) {
    return name;
  }
  return mimeType == 'image/png' ? 'avatar.png' : 'avatar.jpg';
}

bool isAllowedImageMime(String mimeType) {
  return mimeType == 'image/jpeg' || mimeType == 'image/jpg' || mimeType == 'image/png';
}

PreparedImage preparePickedImage(XFile file, List<int> bytes) {
  final mimeType = file.mimeType ?? detectImageMimeType(bytes);
  return PreparedImage(
    bytes: bytes,
    filename: ensureImageFilename(file.name, mimeType),
    mimeType: mimeType,
  );
}
