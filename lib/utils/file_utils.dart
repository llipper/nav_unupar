// lib/utils/file_utils.dart
//
// Utilitários para formatação de dados relacionados a arquivos.

import 'package:intl/intl.dart';

class FileUtils {
  FileUtils._(); // Classe não instanciável

  // ===== FORMATAÇÃO DE TAMANHO =====

  /// Converte bytes para string legível (ex: "2,4 MB")
  static String formatFileSize(int bytes) {
    if (bytes <= 0) return '0 B';
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) {
      final kb = bytes / 1024;
      return '${kb.toStringAsFixed(1)} KB';
    }
    if (bytes < 1024 * 1024 * 1024) {
      final mb = bytes / (1024 * 1024);
      return '${mb.toStringAsFixed(1)} MB';
    }
    final gb = bytes / (1024 * 1024 * 1024);
    return '${gb.toStringAsFixed(2)} GB';
  }

  // ===== FORMATAÇÃO DE DATA E HORA =====

  /// Formata data completa (ex: "06/08/2026")
  static String formatDate(DateTime dateTime) {
    return DateFormat('dd/MM/yyyy').format(dateTime);
  }

  /// Formata hora (ex: "14:32")
  static String formatTime(DateTime dateTime) {
    return DateFormat('HH:mm').format(dateTime);
  }

  /// Formata data e hora juntos (ex: "06/08/2026 às 14:32")
  static String formatDateTime(DateTime dateTime) {
    return '${formatDate(dateTime)} às ${formatTime(dateTime)}';
  }

  /// Formata data relativa (ex: "Hoje", "Ontem", "3 dias atrás")
  static String formatRelativeDate(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays == 0) {
      return 'Hoje às ${formatTime(dateTime)}';
    } else if (difference.inDays == 1) {
      return 'Ontem às ${formatTime(dateTime)}';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} dias atrás';
    } else {
      return formatDate(dateTime);
    }
  }

  // ===== NOMES DE ARQUIVO =====

  /// Sanitiza nome de arquivo removendo caracteres inválidos no Android
  static String sanitizeFileName(String name) {
    // Remove caracteres inválidos para nomes de arquivo no Android
    return name
        .replaceAll(RegExp(r'[<>:"/\\|?*\x00-\x1f]'), '_')
        .replaceAll(RegExp(r'\s+'), '_')
        .trim();
  }

  /// Extrai nome de arquivo de uma URL
  static String fileNameFromUrl(String url) {
    try {
      final uri = Uri.parse(url);
      final pathSegments = uri.pathSegments;
      if (pathSegments.isNotEmpty && pathSegments.last.isNotEmpty) {
        return Uri.decodeComponent(pathSegments.last);
      }
    } catch (_) {}
    // Fallback: usar timestamp como nome
    return 'arquivo_${DateTime.now().millisecondsSinceEpoch}';
  }

  /// Gera um nome de arquivo único adicionando sufixo numérico se já existir
  static String makeUniqueName(String directory, String fileName) {
    // Remove extensão
    final lastDot = fileName.lastIndexOf('.');
    final String baseName;
    final String extension;

    if (lastDot >= 0) {
      baseName = fileName.substring(0, lastDot);
      extension = fileName.substring(lastDot); // inclui o ponto
    } else {
      baseName = fileName;
      extension = '';
    }

    // Tenta sem sufixo primeiro
    final initial = '$directory/$fileName';
    // Retorna o fileName original; a verificação de existência será feita no DownloadService
    return initial;
  }

  // ===== TIPO DE ARQUIVO =====

  /// Retorna a cor associada ao tipo de arquivo (para UI)
  static String colorForFileType(String fileType) {
    switch (fileType.toLowerCase()) {
      case 'docx':
      case 'doc':
        return '#2B7CD3'; // Azul Word
      case 'pdf':
        return '#F40F02'; // Vermelho PDF
      case 'xlsx':
      case 'xls':
        return '#1D6F42'; // Verde Excel
      case 'pptx':
      case 'ppt':
        return '#D04523'; // Laranja PowerPoint
      case 'zip':
      case 'rar':
        return '#F0A500'; // Amarelo arquivo comprimido
      case 'jpg':
      case 'jpeg':
      case 'png':
        return '#9B59B6'; // Roxo imagem
      default:
        return '#607D8B'; // Cinza padrão
    }
  }
}
