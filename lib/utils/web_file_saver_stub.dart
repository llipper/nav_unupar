// lib/utils/web_file_saver_stub.dart
import 'dart:typed_data';

/// Stub para plataformas não-web (Android, iOS, Windows, Linux, macOS).
void saveBytesToDevice(Uint8List bytes, String fileName) {
  // Não faz nada em plataformas não-web pois o DownloadService cuida do sistema de arquivos nativo.
}
