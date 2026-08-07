// lib/controllers/webview_controller.dart
//
// Controller da WebView (ChangeNotifier para uso com Provider).
// Gerencia o estado da navegação e inicia downloads interceptados.

import 'package:flutter/foundation.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

import '../repositories/download_repository.dart';
import '../models/download_record.dart';

/// Estado possível da operação de download em andamento
enum DownloadState { idle, downloading, success, error }

class WebViewController extends ChangeNotifier {
  final DownloadRepository _repository;

  WebViewController({DownloadRepository? repository})
    : _repository = repository ?? DownloadRepository();

  // ===== ESTADO DA WEBVIEW =====

  /// Controlador da instância do InAppWebView
  InAppWebViewController? webViewController;

  /// Indica se a página está sendo carregada
  bool _isLoading = false;
  bool get isLoading => _isLoading;

  /// Progresso de carregamento da página (0.0 a 1.0)
  double _loadingProgress = 0.0;
  double get loadingProgress => _loadingProgress;

  /// URL atual da WebView
  String _currentUrl = '';
  String get currentUrl => _currentUrl;

  /// Título da página atual
  String _pageTitle = '';
  String get pageTitle => _pageTitle;

  /// Pode voltar para a página anterior?
  bool _canGoBack = false;
  bool get canGoBack => _canGoBack;

  /// Pode avançar para a próxima página?
  bool _canGoForward = false;
  bool get canGoForward => _canGoForward;

  // ===== ESTADO DO DOWNLOAD =====

  /// Estado atual do download
  DownloadState _downloadState = DownloadState.idle;
  DownloadState get downloadState => _downloadState;

  /// Nome do arquivo sendo baixado
  String _downloadingFileName = '';
  String get downloadingFileName => _downloadingFileName;

  /// Bytes baixados até agora
  int _downloadedBytes = 0;
  int get downloadedBytes => _downloadedBytes;

  /// Total de bytes do arquivo (-1 se desconhecido)
  int _totalBytes = -1;
  int get totalBytes => _totalBytes;

  /// Progresso do download (0.0 a 1.0, ou null se desconhecido)
  double? get downloadProgress {
    if (_totalBytes <= 0) return null;
    return _downloadedBytes / _totalBytes;
  }

  /// Último arquivo baixado com sucesso
  DownloadRecord? _lastDownload;
  DownloadRecord? get lastDownload => _lastDownload;

  /// Mensagem de erro do último download
  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  // ===== CALLBACKS EXTERNOS =====

  /// Chamado quando um download é concluído com sucesso
  void Function(DownloadRecord record)? onDownloadComplete;

  /// Chamado quando um download falha
  void Function(String message)? onDownloadError;

  // ===== MÉTODOS DA WEBVIEW =====

  void onPageStarted(String url) {
    _isLoading = true;
    _currentUrl = url;
    _loadingProgress = 0.0;
    notifyListeners();
  }

  void onProgressChanged(int progress) {
    _loadingProgress = progress / 100.0;
    notifyListeners();
  }

  void onPageFinished(String url) async {
    _isLoading = false;
    _currentUrl = url;
    _loadingProgress = 1.0;

    // Atualizar estados de navegação
    if (webViewController != null) {
      _canGoBack = await webViewController!.canGoBack();
      _canGoForward = await webViewController!.canGoForward();
    }

    notifyListeners();
  }

  void onTitleChanged(String title) {
    _pageTitle = title;
    notifyListeners();
  }

  void updateNavigationState() async {
    if (webViewController != null) {
      _canGoBack = await webViewController!.canGoBack();
      _canGoForward = await webViewController!.canGoForward();
      notifyListeners();
    }
  }

  void goBack() {
    webViewController?.goBack();
  }

  void goForward() {
    webViewController?.goForward();
  }

  void reload() {
    webViewController?.reload();
  }

  // ===== MÉTODO PRINCIPAL: INTERCEPTAÇÃO E DOWNLOAD =====

  /// Intercepta uma URL de download e realiza o download corretamente.
  ///
  /// Esta função é chamada pelo InAppWebView quando detecta um link de download.
  /// Usamos os cookies da sessão para autenticar a requisição Dio.
  ///
  /// Parâmetros:
  /// - [url]: URL do arquivo a ser baixado
  Future<void> handleDownload(String url) async {
    if (_downloadState == DownloadState.downloading) {
      // Já tem um download em andamento
      return;
    }

    // Extrair cookies da sessão atual da WebView
    String cookies = '';
    try {
      if (webViewController != null) {
        final cookieManager = CookieManager.instance();
        final webViewCookies = await cookieManager.getCookies(
          url: WebUri(url),
        );
        cookies = webViewCookies
            .map((c) => '${c.name}=${c.value}')
            .join('; ');
      }
    } catch (_) {
      // Continuar sem cookies se não conseguir extraí-los
    }

    // Nome provisional para exibir no dialog
    _downloadingFileName = _extractFileNameFromUrl(url);
    _downloadState = DownloadState.downloading;
    _downloadedBytes = 0;
    _totalBytes = -1;
    _errorMessage = null;
    notifyListeners();

    // Executar download
    final result = await _repository.performDownload(
      url: url,
      cookies: cookies,
      referer: _currentUrl,
      onProgress: (downloaded, total) {
        _downloadedBytes = downloaded;
        _totalBytes = total;
        notifyListeners();
      },
    );

    // Tratar resultado
    switch (result) {
      case DownloadSuccess(:final record):
        _downloadState = DownloadState.success;
        _lastDownload = record;
        _downloadingFileName = record.fileName;
        notifyListeners();
        onDownloadComplete?.call(record);

      case DownloadFailure(:final message):
        _downloadState = DownloadState.error;
        _errorMessage = message;
        notifyListeners();
        onDownloadError?.call(message);
    }
  }

  /// Reseta o estado do download para idle
  void resetDownloadState() {
    _downloadState = DownloadState.idle;
    _downloadedBytes = 0;
    _totalBytes = -1;
    _errorMessage = null;
    notifyListeners();
  }

  // ===== HELPERS PRIVADOS =====

  String _extractFileNameFromUrl(String url) {
    try {
      final uri = Uri.parse(url);
      final segments = uri.pathSegments;
      if (segments.isNotEmpty && segments.last.isNotEmpty) {
        return Uri.decodeComponent(segments.last);
      }
    } catch (_) {}
    return 'Arquivo';
  }

  @override
  void dispose() {
    webViewController = null;
    super.dispose();
  }
}
