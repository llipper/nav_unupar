// lib/utils/file_saver.dart
import 'dart:typed_data';

import 'web_file_saver_stub.dart'
    if (dart.library.html) 'web_file_saver_web.dart';

class FileSaver {
  /// Salva ou dispara o download de um arquivo com suporte nativo e web.
  static void saveFile({required Uint8List bytes, required String fileName}) {
    saveBytesToDevice(bytes, fileName);
  }
}
