// lib/models/download_record.dart
//
// Modelo que representa um registro de download no histórico.
// Armazenado como JSON no SharedPreferences.

class DownloadRecord {
  /// Identificador único do registro (timestamp em ms)
  final String id;

  /// Nome do arquivo salvo (ex: "Apostila_AV1.docx")
  final String fileName;

  /// Caminho absoluto no dispositivo (ex: "/storage/emulated/0/Documents/Universidade/...")
  final String filePath;

  /// Tipo/extensão do arquivo (ex: "docx", "pdf", "zip")
  final String fileType;

  /// Tamanho em bytes
  final int fileSize;

  /// Data e hora do download
  final DateTime downloadedAt;

  /// URL de origem do arquivo
  final String url;

  const DownloadRecord({
    required this.id,
    required this.fileName,
    required this.filePath,
    required this.fileType,
    required this.fileSize,
    required this.downloadedAt,
    required this.url,
  });

  /// Cria um DownloadRecord a partir de um mapa JSON (deserialização)
  factory DownloadRecord.fromJson(Map<String, dynamic> json) {
    return DownloadRecord(
      id: json['id'] as String,
      fileName: json['fileName'] as String,
      filePath: json['filePath'] as String,
      fileType: json['fileType'] as String,
      fileSize: json['fileSize'] as int,
      downloadedAt: DateTime.parse(json['downloadedAt'] as String),
      url: json['url'] as String,
    );
  }

  /// Converte o registro para mapa JSON (serialização para persistência)
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'fileName': fileName,
      'filePath': filePath,
      'fileType': fileType,
      'fileSize': fileSize,
      'downloadedAt': downloadedAt.toIso8601String(),
      'url': url,
    };
  }

  /// Retorna o ícone emoji correspondente ao tipo de arquivo
  String get typeIcon {
    switch (fileType.toLowerCase()) {
      case 'docx':
      case 'doc':
        return '📄';
      case 'pdf':
        return '📕';
      case 'xlsx':
      case 'xls':
        return '📊';
      case 'pptx':
      case 'ppt':
        return '📊';
      case 'zip':
      case 'rar':
      case '7z':
        return '🗜️';
      case 'jpg':
      case 'jpeg':
      case 'png':
        return '🖼️';
      default:
        return '📎';
    }
  }

  /// Retorna o tipo MIME para compartilhamento e abertura
  String get mimeType {
    switch (fileType.toLowerCase()) {
      case 'docx':
        return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
      case 'doc':
        return 'application/msword';
      case 'pdf':
        return 'application/pdf';
      case 'xlsx':
        return 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
      case 'pptx':
        return 'application/vnd.openxmlformats-officedocument.presentationml.presentation';
      case 'zip':
        return 'application/zip';
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      default:
        return 'application/octet-stream';
    }
  }

  @override
  String toString() =>
      'DownloadRecord(id: $id, fileName: $fileName, fileType: $fileType, fileSize: $fileSize)';
}
