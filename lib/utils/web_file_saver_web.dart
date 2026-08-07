// lib/utils/web_file_saver_web.dart
import 'dart:html' as html;
import 'dart:typed_data';

/// Dispara o download de bytes no navegador web criando um Blob e um link temporário.
void saveBytesToDevice(Uint8List bytes, String fileName) {
  final blob = html.Blob([bytes]);
  final url = html.Url.createObjectUrlFromBlob(blob);
  final anchor = html.AnchorElement(href: url)
    ..setAttribute('download', fileName)
    ..style.display = 'none';
  html.document.body?.children.add(anchor);
  anchor.click();
  anchor.remove();
  html.Url.revokeObjectUrl(url);
}
