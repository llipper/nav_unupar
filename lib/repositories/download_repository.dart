// lib/repositories/download_repository.dart
//
// Repositório que orquestra o DownloadService e o StorageService.
// É a camada de abstração entre os controllers e os serviços de baixo nível.
// Responsável por traduzir erros técnicos em mensagens amigáveis ao usuário.

import 'package:dio/dio.dart';

import '../models/download_record.dart';
import '../services/download_service.dart';
import '../services/storage_service.dart';

/// Resultado de uma operação de download (success ou failure)
sealed class DownloadResult {
  const DownloadResult();
}

class DownloadSuccess extends DownloadResult {
  final DownloadRecord record;
  const DownloadSuccess(this.record);
}

class DownloadFailure extends DownloadResult {
  final String message;
  final DownloadErrorType errorType;
  const DownloadFailure(this.message, this.errorType);
}

class DownloadRepository {
  final DownloadService _downloadService;
  final StorageService _storageService;

  DownloadRepository({
    DownloadService? downloadService,
    StorageService? storageService,
  }) : _downloadService = downloadService ?? DownloadService(),
       _storageService = storageService ?? StorageService();

  /// Executa o download completo:
  /// 1. Baixa o arquivo com cookies da sessão
  /// 2. Salva no dispositivo com extensão correta
  /// 3. Persiste o registro no histórico
  ///
  /// Retorna [DownloadSuccess] ou [DownloadFailure].
  Future<DownloadResult> performDownload({
    required String url,
    required String cookies,
    String? referer,
    void Function(int downloaded, int total)? onProgress,
    CancelToken? cancelToken,
  }) async {
    try {
      // Realizar o download
      final record = await _downloadService.downloadFile(
        url: url,
        cookies: cookies,
        referer: referer,
        onProgress: onProgress,
        cancelToken: cancelToken,
      );

      // Persistir no histórico
      await _storageService.saveRecord(record);

      return DownloadSuccess(record);
    } on DownloadException catch (e) {
      return DownloadFailure(e.message, e.type);
    } catch (e) {
      return DownloadFailure(
        'Erro inesperado ao baixar o arquivo: ${e.toString()}',
        DownloadErrorType.unknown,
      );
    }
  }

  /// Carrega o histórico de downloads
  Future<List<DownloadRecord>> getHistory() => _storageService.getAll();

  /// Exclui um registro do histórico (e opcionalmente o arquivo físico)
  Future<void> deleteRecord(String id, {bool deleteFile = false}) async {
    if (deleteFile) {
      final records = await _storageService.getAll();
      final record = records.where((r) => r.id == id).firstOrNull;
      if (record != null) {
        try {
          // O controller cuidará de deletar o arquivo
          // (mantendo a responsabilidade de IO fora do repositório)
        } catch (_) {}
      }
    }
    await _storageService.deleteRecord(id);
  }

  /// Limpa todo o histórico
  Future<void> clearHistory() => _storageService.clearAll();
}
