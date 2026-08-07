// lib/services/download_service.dart
//
// Serviço responsável por realizar o download de arquivos.
//
// Utiliza Dio para fazer requisições HTTP com:
// - User-Agent desktop (simula Chrome no Windows)
// - Cookies da sessão do WebView (mantém autenticação)
// - Cabeçalhos idênticos ao navegador desktop
// - Detecção automática do tipo real do arquivo por magic bytes
// - Salvamento com extensão correta

import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';

import '../models/download_record.dart';
import '../utils/constants.dart';
import '../utils/file_utils.dart';
import 'file_type_service.dart';

/// Exceção personalizada para erros de download
class DownloadException implements Exception {
  final String message;
  final DownloadErrorType type;

  const DownloadException(this.message, this.type);

  @override
  String toString() => 'DownloadException($type): $message';
}

/// Tipos de erro de download para mensagens localizadas
enum DownloadErrorType {
  noInternet,
  authenticationRequired,
  sessionExpired,
  fileNotFound,
  serverError,
  downloadInterrupted,
  storageError,
  unknown,
}

/// Callback de progresso do download
/// [downloaded]: bytes baixados até agora
/// [total]: total de bytes (-1 se desconhecido)
typedef ProgressCallback = void Function(int downloaded, int total);

class DownloadService {
  late final Dio _dio;

  DownloadService() {
    _dio = Dio(
      BaseOptions(
        // Timeout de conexão
        connectTimeout: Duration(
          seconds: AppConstants.connectionTimeoutSeconds,
        ),
        // Timeout de recebimento
        receiveTimeout: Duration(
          seconds: AppConstants.receiveTimeoutSeconds,
        ),
        // Seguir redirecionamentos automaticamente
        followRedirects: true,
        maxRedirects: AppConstants.maxRedirects,
        // Receber dados como bytes (não como string)
        responseType: ResponseType.bytes,
        // Aceitar todos os status codes para tratar erros manualmente
        validateStatus: (status) => status != null && status < 600,
      ),
    );

    // Interceptor para logging em modo debug
    _dio.interceptors.add(
      LogInterceptor(
        requestHeader: true,
        responseHeader: true,
        requestBody: false,
        responseBody: false,
        error: true,
      ),
    );
  }

  /// Realiza o download de um arquivo a partir de uma URL,
  /// usando os cookies da sessão atual do WebView.
  ///
  /// Parâmetros:
  /// - [url]: URL do arquivo a ser baixado
  /// - [cookies]: string de cookies no formato "nome=valor; nome2=valor2"
  /// - [referer]: URL da página que originou o download (ajuda em portais com CSRF)
  /// - [onProgress]: callback chamado durante o download com bytes baixados/total
  ///
  /// Retorna: [DownloadRecord] com metadados do arquivo salvo
  Future<DownloadRecord> downloadFile({
    required String url,
    required String cookies,
    String? referer,
    ProgressCallback? onProgress,
    CancelToken? cancelToken,
  }) async {
    try {
      // === ETAPA 1: Preparar cabeçalhos HTTP ===
      // Imitamos exatamente o que o Chrome Desktop enviaria ao servidor.
      final headers = _buildHeaders(cookies: cookies, referer: referer ?? url);

      // === ETAPA 2: Fazer a requisição HTTP ===
      onProgress?.call(0, -1); // Sinaliza início

      Response<List<int>> response;
      try {
        response = await _dio.get<List<int>>(
          url,
          options: Options(headers: headers, responseType: ResponseType.bytes),
          cancelToken: cancelToken,
          onReceiveProgress: (received, total) {
            onProgress?.call(received, total);
          },
        );
      } on DioException catch (e) {
        throw _handleDioError(e);
      }

      // === ETAPA 3: Verificar resposta HTTP ===
      if (response.statusCode == 401 || response.statusCode == 403) {
        throw const DownloadException(
          'Sessão expirada ou acesso não autorizado. Faça login novamente.',
          DownloadErrorType.sessionExpired,
        );
      }
      if (response.statusCode == 404) {
        throw const DownloadException(
          'Arquivo não encontrado no servidor.',
          DownloadErrorType.fileNotFound,
        );
      }
      if (response.statusCode != null && response.statusCode! >= 500) {
        throw DownloadException(
          'Erro no servidor (HTTP ${response.statusCode}). Tente novamente mais tarde.',
          DownloadErrorType.serverError,
        );
      }

      final bytes = Uint8List.fromList(response.data ?? []);
      if (bytes.isEmpty) {
        throw const DownloadException(
          'O servidor retornou um arquivo vazio.',
          DownloadErrorType.serverError,
        );
      }

      // === ETAPA 4: Extrair metadados dos cabeçalhos de resposta ===
      final contentType = response.headers.value('content-type');
      final contentDisposition = response.headers.value('content-disposition');

      // === ETAPA 5: Detectar extensão real do arquivo ===
      // Esta é a etapa principal que corrige o problema:
      // mesmo que o servidor diga "application/xml", detectamos pelos magic bytes.
      final detectedExtension = FileTypeService.detectExtension(
        headerBytes: bytes,
        contentType: contentType,
        contentDisposition: contentDisposition,
        url: url,
      );

      // === ETAPA 6: Determinar nome do arquivo ===
      String fileName = _extractFileName(
        contentDisposition: contentDisposition,
        url: url,
        extension: detectedExtension,
      );
      fileName = FileUtils.sanitizeFileName(fileName);

      // === ETAPA 7: Garantir que o arquivo não sobrescreva outro ===
      final savePath = await _getSavePath(fileName);

      // === ETAPA 8: Salvar o arquivo ===
      final file = File(savePath);
      await file.writeAsBytes(bytes, flush: true);

      // Copiar também para Documents/Universidade pública
      _copyToPublicDocuments(file, fileName);

      // === ETAPA 9: Montar e retornar o registro ===
      return DownloadRecord(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        fileName: file.uri.pathSegments.last,
        filePath: savePath,
        fileType: detectedExtension,
        fileSize: bytes.length,
        downloadedAt: DateTime.now(),
        url: url,
      );
    } on DownloadException {
      rethrow; // Já foi tratada
    } catch (e) {
      throw DownloadException(
        'Erro inesperado: ${e.toString()}',
        DownloadErrorType.unknown,
      );
    }
  }

  // ===== MÉTODOS PRIVADOS =====

  /// Constrói os cabeçalhos HTTP simulando o Chrome Desktop
  Map<String, String> _buildHeaders({
    required String cookies,
    required String referer,
  }) {
    return {
      // User-Agent desktop Chrome 138 — crucial para receber Content-Type correto
      'User-Agent': AppConstants.desktopUserAgent,
      // Cookies da sessão do WebView (autenticação)
      if (cookies.isNotEmpty) 'Cookie': cookies,
      // Tipos de conteúdo aceitos (igual ao Chrome)
      'Accept':
          'text/html,application/xhtml+xml,application/xml;q=0.9,'
          'application/pdf,application/vnd.openxmlformats-officedocument.*,'
          '*/*;q=0.8',
      // Encodings aceitos
      'Accept-Encoding': 'gzip, deflate, br',
      // Idioma
      'Accept-Language': 'pt-BR,pt;q=0.9,en-US;q=0.8,en;q=0.7',
      // Página de origem (evita bloqueios por CSRF)
      'Referer': referer,
      // Cache
      'Cache-Control': 'no-cache',
      'Pragma': 'no-cache',
      // Upgrade de conexão
      'Connection': 'keep-alive',
      // Indica que é um download direto
      'Sec-Fetch-Site': 'same-origin',
      'Sec-Fetch-Mode': 'navigate',
      'Sec-Fetch-User': '?1',
      'Sec-Fetch-Dest': 'document',
      // Upgrade para HTTPS se disponível
      'Upgrade-Insecure-Requests': '1',
    };
  }

  /// Obtém o caminho de salvamento no armazenamento do app,
  /// garantindo que o FileProvider tenha permissão para abrir o arquivo.
  Future<String> _getSavePath(String fileName) async {
    Directory? appDir;
    try {
      appDir = await getExternalStorageDirectory();
    } catch (_) {}

    // Fallback para storage de documentos do app se externo não disponível
    appDir ??= await getApplicationDocumentsDirectory();

    final universidadeDir = Directory(
      '${appDir.path}/${AppConstants.downloadFolderName}',
    );

    // Criar diretório se não existir
    if (!await universidadeDir.exists()) {
      await universidadeDir.create(recursive: true);
    }

    // Verificar se arquivo já existe e gerar nome único
    String savePath = '${universidadeDir.path}/$fileName';
    if (await File(savePath).exists()) {
      final lastDot = fileName.lastIndexOf('.');
      final baseName =
          lastDot >= 0 ? fileName.substring(0, lastDot) : fileName;
      final ext = lastDot >= 0 ? fileName.substring(lastDot) : '';
      int counter = 1;
      do {
        savePath = '${universidadeDir.path}/${baseName}_($counter)$ext';
        counter++;
      } while (await File(savePath).exists());
    }

    return savePath;
  }

  /// Copia uma réplica do arquivo baixado para a pasta pública Documents/Universidade
  /// para acesso pelo gerenciador de arquivos do dispositivo.
  void _copyToPublicDocuments(File sourceFile, String fileName) async {
    try {
      final publicDir = Directory(
        '/storage/emulated/0/Documents/${AppConstants.downloadFolderName}',
      );
      if (!await publicDir.exists()) {
        await publicDir.create(recursive: true);
      }
      final targetFile = File('${publicDir.path}/$fileName');
      await sourceFile.copy(targetFile.path);
    } catch (_) {}
  }

  /// Extrai o nome do arquivo dos metadados disponíveis
  String _extractFileName({
    String? contentDisposition,
    required String url,
    required String extension,
  }) {
    // Tentar extrair do Content-Disposition primeiro
    if (contentDisposition != null && contentDisposition.isNotEmpty) {
      // filename*=UTF-8''nome%20arquivo.docx
      final utf8Match = RegExp(
        r"filename\*\s*=\s*(?:UTF-8'')?([^;\s]+)",
        caseSensitive: false,
      ).firstMatch(contentDisposition);

      if (utf8Match != null) {
        String name = Uri.decodeComponent(utf8Match.group(1) ?? '');
        name = _ensureCorrectExtension(name, extension);
        return name;
      }

      // filename="nome arquivo.docx"
      final normalMatch = RegExp(
        r'''filename\s*=\s*["']?([^"';\r\n]+)["']?''',
        caseSensitive: false,
      ).firstMatch(contentDisposition);

      if (normalMatch != null) {
        String name = normalMatch.group(1)?.trim() ?? '';
        name = _ensureCorrectExtension(name, extension);
        return name;
      }
    }

    // Tentar extrair da URL
    String nameFromUrl = FileUtils.fileNameFromUrl(url);
    nameFromUrl = _ensureCorrectExtension(nameFromUrl, extension);
    return nameFromUrl;
  }

  /// Garante que o nome do arquivo tenha a extensão correta detectada
  String _ensureCorrectExtension(String fileName, String correctExtension) {
    if (correctExtension.isEmpty) return fileName;

    final lastDot = fileName.lastIndexOf('.');
    if (lastDot >= 0) {
      final currentExt = fileName.substring(lastDot + 1).toLowerCase();
      // Se extensão atual é suspeita (xml, bin, etc.) ou diferente do detectado
      if (AppConstants.suspectExtensions.contains(currentExt) &&
          currentExt != correctExtension) {
        // Substituir extensão pela detectada
        return '${fileName.substring(0, lastDot)}.$correctExtension';
      }
      // Se extensão atual já está correta
      return fileName;
    }

    // Sem extensão: adicionar a detectada
    return '$fileName.$correctExtension';
  }

  /// Traduz erros do Dio para DownloadException com mensagens amigáveis
  DownloadException _handleDioError(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return const DownloadException(
          'Tempo de conexão esgotado. Verifique sua internet e tente novamente.',
          DownloadErrorType.noInternet,
        );
      case DioExceptionType.connectionError:
        return const DownloadException(
          'Sem conexão com a internet. Verifique sua rede e tente novamente.',
          DownloadErrorType.noInternet,
        );
      case DioExceptionType.cancel:
        return const DownloadException(
          'Download cancelado.',
          DownloadErrorType.downloadInterrupted,
        );
      case DioExceptionType.badResponse:
        final statusCode = e.response?.statusCode;
        if (statusCode == 401 || statusCode == 403) {
          return const DownloadException(
            'Acesso não autorizado. Faça login novamente.',
            DownloadErrorType.authenticationRequired,
          );
        }
        if (statusCode == 404) {
          return const DownloadException(
            'Arquivo não encontrado no servidor.',
            DownloadErrorType.fileNotFound,
          );
        }
        return DownloadException(
          'Erro do servidor: HTTP $statusCode',
          DownloadErrorType.serverError,
        );
      default:
        return DownloadException(
          'Erro de download: ${e.message ?? 'desconhecido'}',
          DownloadErrorType.unknown,
        );
    }
  }
}
