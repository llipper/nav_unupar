// lib/services/file_type_service.dart
//
// Serviço de detecção do tipo real de um arquivo.
//
// PROBLEMA: Portais universitários frequentemente servem arquivos Word (.docx)
// com Content-Type incorreto (application/xml ou text/xml), causando o Android
// a salvar o arquivo como .xml.
//
// SOLUÇÃO: Analisar os "magic bytes" (assinatura binária) do arquivo para
// determinar o tipo real, independentemente do que o servidor declarou.

import 'dart:typed_data';

class FileTypeService {
  // ===== MAGIC BYTES =====
  // Assinaturas binárias que identificam tipos de arquivo.
  // Referência: https://en.wikipedia.org/wiki/List_of_file_signatures

  /// Assinatura ZIP: PK\x03\x04
  /// DOCX, XLSX, PPTX são todos arquivos ZIP com estrutura interna específica.
  static const List<int> _zipSignature = [0x50, 0x4B, 0x03, 0x04];

  /// Assinatura PDF: %PDF
  static const List<int> _pdfSignature = [0x25, 0x50, 0x44, 0x46];

  /// Assinatura PNG: \x89PNG
  static const List<int> _pngSignature = [0x89, 0x50, 0x4E, 0x47];

  /// Assinatura JPEG: \xFF\xD8\xFF
  static const List<int> _jpegSignature = [0xFF, 0xD8, 0xFF];

  /// Assinatura GIF: GIF8
  static const List<int> _gifSignature = [0x47, 0x49, 0x46, 0x38];

  /// Assinatura DOC (Word 97-2003): \xD0\xCF\x11\xE0
  static const List<int> _docSignature = [0xD0, 0xCF, 0x11, 0xE0];

  // ===== MAPEAMENTO CONTENT-TYPE → EXTENSÃO =====

  static const Map<String, String> _contentTypeToExtension = {
    // Formatos Office Open XML (Microsoft Office 2007+)
    'application/vnd.openxmlformats-officedocument.wordprocessingml.document': 'docx',
    'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet': 'xlsx',
    'application/vnd.openxmlformats-officedocument.presentationml.presentation': 'pptx',
    // Formatos Office legados
    'application/msword': 'doc',
    'application/vnd.ms-excel': 'xls',
    'application/vnd.ms-powerpoint': 'ppt',
    // Documentos
    'application/pdf': 'pdf',
    'text/plain': 'txt',
    'text/html': 'html',
    // Imagens
    'image/jpeg': 'jpg',
    'image/png': 'png',
    'image/gif': 'gif',
    'image/webp': 'webp',
    // Comprimidos
    'application/zip': 'zip',
    'application/x-rar-compressed': 'rar',
    'application/x-7z-compressed': '7z',
    // Genérico — não usar sozinho, deve ser combinado com magic bytes
    'application/xml': 'xml',
    'text/xml': 'xml',
    'application/octet-stream': 'bin',
  };

  /// Detecta a extensão correta do arquivo usando múltiplas estratégias,
  /// em ordem de prioridade:
  ///
  /// 1. **Magic bytes** — mais confiável, analisa o conteúdo binário real
  /// 2. **Content-Disposition** — nome sugerido pelo servidor (filename="...")
  /// 3. **Content-Type** — declaração MIME do servidor
  /// 4. **URL** — extensão na URL de origem
  ///
  /// Parâmetros:
  /// - [headerBytes]: primeiros bytes do arquivo (mínimo 4, idealmente 64KB)
  /// - [contentType]: valor do cabeçalho Content-Type
  /// - [contentDisposition]: valor do cabeçalho Content-Disposition
  /// - [url]: URL de origem do arquivo
  static String detectExtension({
    required Uint8List headerBytes,
    String? contentType,
    String? contentDisposition,
    String? url,
  }) {
    // === ESTRATÉGIA 1: MAGIC BYTES ===
    // Esta é a mais confiável pois analisa o conteúdo real do arquivo.
    final magicExt = _detectByMagicBytes(headerBytes);
    if (magicExt != null) {
      // Se os magic bytes indicam ZIP, precisamos verificar se é DOCX, XLSX ou PPTX.
      // Um DOCX é um arquivo ZIP que contém o arquivo "[Content_Types].xml" na raiz.
      if (magicExt == 'zip') {
        // Verificar estrutura interna para distinguir DOCX de ZIP genérico
        final officeExt = _detectOfficeOpenXml(headerBytes, contentDisposition, contentType, url);
        if (officeExt != null) return officeExt;
        return 'zip'; // ZIP genérico
      }
      return magicExt;
    }

    // === ESTRATÉGIA 2: CONTENT-DISPOSITION ===
    // O servidor pode sugerir o nome do arquivo no cabeçalho:
    // Content-Disposition: attachment; filename="apostila.docx"
    if (contentDisposition != null && contentDisposition.isNotEmpty) {
      final ext = _extractExtensionFromDisposition(contentDisposition);
      if (ext != null && ext.isNotEmpty && ext != 'xml') {
        return ext;
      }
    }

    // === ESTRATÉGIA 3: CONTENT-TYPE ===
    // Usar apenas se for um tipo confiável (não xml/octet-stream genérico)
    if (contentType != null && contentType.isNotEmpty) {
      // Normalizar: remover parâmetros como "; charset=utf-8"
      final normalizedCt = contentType.split(';').first.trim().toLowerCase();
      final ext = _contentTypeToExtension[normalizedCt];
      if (ext != null && ext != 'xml' && ext != 'bin') {
        return ext;
      }
    }

    // === ESTRATÉGIA 4: URL ===
    if (url != null && url.isNotEmpty) {
      final ext = _extractExtensionFromUrl(url);
      if (ext != null && ext.isNotEmpty) {
        return ext;
      }
    }

    // Fallback: extensão desconhecida
    return 'bin';
  }

  // ===== IMPLEMENTAÇÕES PRIVADAS =====

  /// Detecta tipo pelo magic bytes
  static String? _detectByMagicBytes(Uint8List bytes) {
    if (bytes.isEmpty) return null;

    if (_startsWith(bytes, _zipSignature)) return 'zip'; // pode ser DOCX/XLSX/PPTX
    if (_startsWith(bytes, _pdfSignature)) return 'pdf';
    if (_startsWith(bytes, _pngSignature)) return 'png';
    if (_startsWith(bytes, _jpegSignature)) return 'jpg';
    if (_startsWith(bytes, _gifSignature)) return 'gif';
    if (_startsWith(bytes, _docSignature)) return 'doc';

    return null;
  }

  /// Verifica se o arquivo ZIP é um documento Office Open XML (DOCX, XLSX, PPTX)
  /// pela presença de strings específicas nos bytes do arquivo
  static String? _detectOfficeOpenXml(
    Uint8List bytes,
    String? contentDisposition,
    String? contentType,
    String? url,
  ) {
    // Converter bytes para string para buscar marcadores internos do ZIP
    // Nota: esta busca é feita nos primeiros bytes carregados (cabeçalho do ZIP)
    // que frequentemente contém os nomes dos arquivos internos
    final bytesAsString = String.fromCharCodes(bytes.take(4096).toList());

    // DOCX contém: word/document.xml ou [Content_Types].xml com tipo Word
    if (bytesAsString.contains('word/') ||
        bytesAsString.contains('wordprocessingml')) {
      return 'docx';
    }

    // XLSX contém: xl/ ou spreadsheetml
    if (bytesAsString.contains('xl/') ||
        bytesAsString.contains('spreadsheetml')) {
      return 'xlsx';
    }

    // PPTX contém: ppt/ ou presentationml
    if (bytesAsString.contains('ppt/') ||
        bytesAsString.contains('presentationml')) {
      return 'pptx';
    }

    // Verificação por Content-Disposition como desempate
    if (contentDisposition != null) {
      final ext = _extractExtensionFromDisposition(contentDisposition);
      if (ext == 'docx' || ext == 'xlsx' || ext == 'pptx') return ext;
    }

    // Verificação por Content-Type como desempate
    if (contentType != null) {
      final ct = contentType.toLowerCase();
      if (ct.contains('wordprocessingml')) return 'docx';
      if (ct.contains('spreadsheetml')) return 'xlsx';
      if (ct.contains('presentationml')) return 'pptx';
    }

    // Verificação pela URL
    if (url != null) {
      final urlExt = _extractExtensionFromUrl(url);
      if (urlExt == 'docx' || urlExt == 'xlsx' || urlExt == 'pptx') {
        return urlExt;
      }
    }

    return null; // ZIP genérico
  }

  /// Extrai extensão do cabeçalho Content-Disposition
  /// Exemplo: 'attachment; filename="apostila.docx"' → 'docx'
  static String? _extractExtensionFromDisposition(String disposition) {
    // Tentar filename*=UTF-8''nome.docx (RFC 5987)
    final utf8Match = RegExp(
      r"filename\*\s*=\s*(?:UTF-8'')?([^;\s]+)",
      caseSensitive: false,
    ).firstMatch(disposition);

    if (utf8Match != null) {
      final name = Uri.decodeComponent(utf8Match.group(1) ?? '');
      return _extensionFromName(name);
    }

    // Tentar filename="nome.docx" ou filename=nome.docx
    final normalMatch = RegExp(
      r'''filename\s*=\s*["']?([^"';\r\n]+)["']?''',
      caseSensitive: false,
    ).firstMatch(disposition);

    if (normalMatch != null) {
      final name = normalMatch.group(1)?.trim() ?? '';
      return _extensionFromName(name);
    }

    return null;
  }

  /// Extrai extensão de uma URL
  static String? _extractExtensionFromUrl(String url) {
    try {
      final uri = Uri.parse(url);
      final path = uri.path;
      final lastDot = path.lastIndexOf('.');
      if (lastDot >= 0 && lastDot < path.length - 1) {
        // Remove query params se houver
        final ext = path.substring(lastDot + 1).split('?').first.toLowerCase();
        if (ext.length <= 5 && RegExp(r'^[a-z0-9]+$').hasMatch(ext)) {
          return ext;
        }
      }
    } catch (_) {}
    return null;
  }

  /// Extrai extensão de um nome de arquivo
  static String? _extensionFromName(String name) {
    final cleanName = name.trim().replaceAll('"', '').replaceAll("'", '');
    final lastDot = cleanName.lastIndexOf('.');
    if (lastDot >= 0 && lastDot < cleanName.length - 1) {
      return cleanName.substring(lastDot + 1).toLowerCase();
    }
    return null;
  }

  /// Verifica se os bytes começam com a assinatura fornecida
  static bool _startsWith(Uint8List bytes, List<int> signature) {
    if (bytes.length < signature.length) return false;
    for (int i = 0; i < signature.length; i++) {
      if (bytes[i] != signature[i]) return false;
    }
    return true;
  }

  /// Retorna o nome amigável do tipo de arquivo
  static String getFriendlyTypeName(String extension) {
    switch (extension.toLowerCase()) {
      case 'docx':
        return 'Documento Word';
      case 'doc':
        return 'Documento Word (Legado)';
      case 'pdf':
        return 'Documento PDF';
      case 'xlsx':
        return 'Planilha Excel';
      case 'xls':
        return 'Planilha Excel (Legado)';
      case 'pptx':
        return 'Apresentação PowerPoint';
      case 'ppt':
        return 'Apresentação PowerPoint (Legado)';
      case 'zip':
        return 'Arquivo Comprimido ZIP';
      case 'rar':
        return 'Arquivo Comprimido RAR';
      case 'jpg':
      case 'jpeg':
        return 'Imagem JPEG';
      case 'png':
        return 'Imagem PNG';
      case 'txt':
        return 'Arquivo de Texto';
      default:
        return 'Arquivo ($extension)';
    }
  }
}
