// lib/pages/browser_page.dart
//
// Tela principal do navegador WebView.
//
// Funcionalidades:
// - WebView com User-Agent desktop
// - Barra de navegação (voltar, avançar, recarregar, URL)
// - Barra de progresso de carregamento da página
// - Interceptação de downloads (onDownloadStartRequest)
// - Dialog de progresso durante download
// - Snackbar de resultado após download

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:provider/provider.dart';

import '../app/routes.dart';
import '../controllers/history_controller.dart';
import '../controllers/webview_controller.dart' as ctrl;
import '../utils/constants.dart';
import '../widgets/download_progress_dialog.dart';
import '../widgets/error_snackbar.dart';

class BrowserPage extends StatefulWidget {
  const BrowserPage({super.key});

  @override
  State<BrowserPage> createState() => _BrowserPageState();
}

class _BrowserPageState extends State<BrowserPage> {
  late ctrl.WebViewController _webCtrl;
  CancelToken? _cancelToken;
  bool _dialogShowing = false;

  // Controlador e foco da barra de URL editável
  final TextEditingController _urlController = TextEditingController();
  final FocusNode _urlFocusNode = FocusNode();
  bool _isEditingUrl = false;

  // Configurações da WebView
  final _webViewSettings = InAppWebViewSettings(
    // User-Agent desktop Chrome 138 para Windows
    // Isso é fundamental para o servidor retornar Content-Type correto
    userAgent: AppConstants.desktopUserAgent,

    // Suporte a JavaScript
    javaScriptEnabled: true,

    // Suporte a DOM Storage (necessário para portais modernos)
    domStorageEnabled: true,

    // Suporte a banco de dados local
    databaseEnabled: true,

    // Permite conteúdo misto (HTTP + HTTPS)
    mixedContentMode: MixedContentMode.MIXED_CONTENT_ALWAYS_ALLOW,

    // Permitir downloads múltiplos
    allowFileAccess: true,

    // Suporte a geolocalização
    geolocationEnabled: true,

    // Suporte a tela cheia de vídeos
    supportMultipleWindows: false,

    // Manter o WebView vivo em background
    useWideViewPort: true,
    loadWithOverviewMode: true,

    // Zoom
    builtInZoomControls: true,
    displayZoomControls: false,

    // Aceitar todos os certificados SSL (para portais com cert. universitário)
    // CUIDADO: Em produção, avalie os riscos de segurança
  );

  @override
  void initState() {
    super.initState();
    _webCtrl = context.read<ctrl.WebViewController>();

    // Inicializar a barra de URL com o endereço do portal
    _urlController.text = AppConstants.portalUrl;

    // Sincronizar o texto da URL quando a página muda
    _webCtrl.addListener(() {
      if (!_isEditingUrl && _webCtrl.currentUrl.isNotEmpty) {
        _urlController.text = _webCtrl.currentUrl;
      }
    });

    // Quando o usuário sai do campo de URL sem confirmar, restaurar a URL atual
    _urlFocusNode.addListener(() {
      if (!_urlFocusNode.hasFocus) {
        setState(() => _isEditingUrl = false);
        // Restaurar URL atual se o usuário não confirmou
        _urlController.text = _webCtrl.currentUrl.isNotEmpty
            ? _webCtrl.currentUrl
            : AppConstants.portalUrl;
      }
    });

    // Configurar callbacks de resultado do download
    _webCtrl.onDownloadComplete = (record) {
      // Adicionar ao histórico
      if (mounted) {
        context.read<HistoryController>().addRecord(record);
        _dismissDialog();
        AppSnackBar.showSuccess(
          context,
          '✅ "${record.fileName}" salvo em Documents/Universidade/',
          actionLabel: 'Abrir',
          onAction: () {
            context.read<HistoryController>().openFile(record);
          },
        );
      }
    };

    _webCtrl.onDownloadError = (message) {
      if (mounted) {
        _dismissDialog();
        AppSnackBar.showError(context, message);
      }
    };
  }

  void _dismissDialog() {
    if (_dialogShowing && mounted) {
      Navigator.of(context, rootNavigator: true).pop();
      _dialogShowing = false;
    }
  }

  void _showProgressDialog() {
    if (!_dialogShowing && mounted) {
      _dialogShowing = true;
      _cancelToken = CancelToken();

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) {
          return AnimatedBuilder(
            animation: _webCtrl,
            builder: (_, __) => DownloadProgressDialog(
              fileName: _webCtrl.downloadingFileName,
              downloadedBytes: _webCtrl.downloadedBytes,
              totalBytes: _webCtrl.totalBytes,
              onCancel: () {
                _cancelToken?.cancel();
                _webCtrl.resetDownloadState();
                Navigator.of(ctx).pop();
                _dialogShowing = false;
              },
            ),
          );
        },
      ).then((_) => _dialogShowing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      body: SafeArea(
        child: Column(
          children: [
            // ===== BARRA DE NAVEGAÇÃO =====
            _buildNavigationBar(context),

            // ===== BARRA DE PROGRESSO DA PÁGINA =====
            _buildPageProgressBar(),

            // ===== WEBVIEW =====
            Expanded(child: _buildWebView()),
          ],
        ),
      ),
    );
  }

  /// Navega para a URL digitada pelo usuário, adicionando https:// se necessário
  void _navigateToUrl(String input) {
    String url = input.trim();
    if (url.isEmpty) return;

    // Adicionar esquema se não tiver
    if (!url.startsWith('http://') && !url.startsWith('https://')) {
      // Se parece uma URL (tem ponto), adicionar https://
      // Caso contrário, tratar como busca no Google
      if (url.contains('.') && !url.contains(' ')) {
        url = 'https://$url';
      } else {
        // Pesquisa no Google
        url = 'https://www.google.com/search?q=${Uri.encodeComponent(url)}';
      }
    }

    _urlController.text = url;
    setState(() => _isEditingUrl = false);
    _urlFocusNode.unfocus();

    // Navegar na WebView
    _webCtrl.webViewController?.loadUrl(
      urlRequest: URLRequest(url: WebUri(url)),
    );
  }

  Widget _buildNavigationBar(BuildContext context) {
    return Consumer<ctrl.WebViewController>(
      builder: (_, webCtrl, __) => Container(
        // Altura maior quando editando para acomodar o teclado confortavelmente
        color: const Color(0xFF161B22),
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
        child: Row(
          children: [
            // ── Voltar ──
            IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
              color: webCtrl.canGoBack ? Colors.white : Colors.white24,
              onPressed: webCtrl.canGoBack ? webCtrl.goBack : null,
              tooltip: 'Voltar',
              padding: const EdgeInsets.all(8),
              constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
            ),

            // ── Avançar ──
            IconButton(
              icon: const Icon(Icons.arrow_forward_ios_rounded, size: 18),
              color: webCtrl.canGoForward ? Colors.white : Colors.white24,
              onPressed: webCtrl.canGoForward ? webCtrl.goForward : null,
              tooltip: 'Avançar',
              padding: const EdgeInsets.all(8),
              constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
            ),

            // ── Campo de URL EDITÁVEL ──
            Expanded(
              child: GestureDetector(
                onTap: () {
                  setState(() => _isEditingUrl = true);
                  // Selecionar tudo ao tocar para facilitar substituição
                  _urlController.selection = TextSelection(
                    baseOffset: 0,
                    extentOffset: _urlController.text.length,
                  );
                  _urlFocusNode.requestFocus();
                },
                child: Container(
                  height: 36,
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  decoration: BoxDecoration(
                    color: _isEditingUrl
                        ? const Color(0xFF0D1117)
                        : Colors.white.withOpacity(0.07),
                    borderRadius: BorderRadius.circular(10),
                    border: _isEditingUrl
                        ? Border.all(
                            color: const Color(0xFF1A73E8),
                            width: 1.5,
                          )
                        : null,
                  ),
                  child: Row(
                    children: [
                      const SizedBox(width: 8),

                      // Ícone de cadeado (segurança)
                      if (!_isEditingUrl)
                        Icon(
                          webCtrl.currentUrl.startsWith('https')
                              ? Icons.lock_rounded
                              : Icons.lock_open_rounded,
                          size: 12,
                          color: webCtrl.currentUrl.startsWith('https')
                              ? Colors.greenAccent
                              : Colors.orange,
                        )
                      else
                        const Icon(
                          Icons.search_rounded,
                          size: 14,
                          color: Color(0xFF1A73E8),
                        ),

                      const SizedBox(width: 6),

                      // Campo de texto da URL
                      Expanded(
                        child: TextField(
                          controller: _urlController,
                          focusNode: _urlFocusNode,
                          // Teclado de URL com botão "Ir"
                          keyboardType: TextInputType.url,
                          textInputAction: TextInputAction.go,
                          autocorrect: false,
                          enableSuggestions: false,
                          style: TextStyle(
                            color: _isEditingUrl
                                ? Colors.white
                                : Colors.white.withOpacity(0.8),
                            fontSize: 12.5,
                          ),
                          decoration: const InputDecoration(
                            border: InputBorder.none,
                            isDense: true,
                            contentPadding: EdgeInsets.zero,
                          ),
                          // Ao pressionar "Ir" no teclado
                          onSubmitted: _navigateToUrl,
                          onTap: () {
                            setState(() => _isEditingUrl = true);
                            _urlController.selection = TextSelection(
                              baseOffset: 0,
                              extentOffset: _urlController.text.length,
                            );
                          },
                        ),
                      ),

                      // Botão limpar campo (só aparece ao editar)
                      if (_isEditingUrl)
                        GestureDetector(
                          onTap: () {
                            _urlController.clear();
                            _urlFocusNode.requestFocus();
                          },
                          child: const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 6),
                            child: Icon(
                              Icons.close_rounded,
                              size: 16,
                              color: Colors.white38,
                            ),
                          ),
                        )
                      else
                        const SizedBox(width: 4),
                    ],
                  ),
                ),
              ),
            ),

            // ── Recarregar / Parar ──
            IconButton(
              icon: Icon(
                webCtrl.isLoading
                    ? Icons.close_rounded
                    : Icons.refresh_rounded,
                size: 20,
              ),
              color: Colors.white70,
              onPressed: webCtrl.isLoading
                  ? () => webCtrl.webViewController?.stopLoading()
                  : webCtrl.reload,
              tooltip: webCtrl.isLoading ? 'Parar' : 'Recarregar',
              padding: const EdgeInsets.all(8),
              constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
            ),

            // ── Histórico ──
            IconButton(
              icon: const Icon(Icons.folder_open_rounded, size: 20),
              color: Colors.white70,
              onPressed: () =>
                  Navigator.of(context).pushNamed(AppRoutes.history),
              tooltip: 'Histórico',
              padding: const EdgeInsets.all(8),
              constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPageProgressBar() {
    return Consumer<ctrl.WebViewController>(
      builder: (_, ctrl, __) {
        if (!ctrl.isLoading || ctrl.loadingProgress >= 1.0) {
          return const SizedBox.shrink();
        }
        return LinearProgressIndicator(
          value: ctrl.loadingProgress,
          minHeight: 2,
          backgroundColor: Colors.transparent,
          valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF1A73E8)),
        );
      },
    );
  }

  Widget _buildWebView() {
    return InAppWebView(
      initialUrlRequest: URLRequest(
        url: WebUri(AppConstants.portalUrl),
        headers: {
          'User-Agent': AppConstants.desktopUserAgent,
        },
      ),
      initialSettings: _webViewSettings,

      // ===== EVENTO: WebView criada =====
      onWebViewCreated: (controller) {
        _webCtrl.webViewController = controller;
      },

      // ===== EVENTO: Início do carregamento =====
      onLoadStart: (controller, url) {
        _webCtrl.onPageStarted(url?.toString() ?? '');
      },

      // ===== EVENTO: Progresso de carregamento =====
      onProgressChanged: (controller, progress) {
        _webCtrl.onProgressChanged(progress);
      },

      // ===== EVENTO: Carregamento concluído =====
      onLoadStop: (controller, url) async {
        _webCtrl.onPageFinished(url?.toString() ?? '');
      },

      // ===== EVENTO: Título da página =====
      onTitleChanged: (controller, title) {
        _webCtrl.onTitleChanged(title ?? '');
      },

      // ===== EVENTO PRINCIPAL: DOWNLOAD DETECTADO =====
      // Este evento é disparado quando o navegador detecta que uma URL
      // resultará em um download (pelo Content-Disposition: attachment).
      onDownloadStartRequest: (controller, request) {
        final url = request.url.toString();
        _showProgressDialog();
        _webCtrl.handleDownload(url);
      },

      // ===== INTERCEPTAR NAVEGAÇÃO =====
      // Verifica se a URL deve ser aberta normalmente ou interceptada como download
      shouldOverrideUrlLoading: (controller, action) async {
        final url = action.request.url?.toString() ?? '';

        // URLs que tipicamente levam a downloads de documentos
        final downloadExtensions = [
          '.docx', '.doc', '.xlsx', '.xls', '.pptx', '.ppt',
          '.pdf', '.zip', '.rar',
        ];

        // Verificar se a URL termina com extensão de documento
        final lowerUrl = url.toLowerCase().split('?').first;
        for (final ext in downloadExtensions) {
          if (lowerUrl.endsWith(ext)) {
            _showProgressDialog();
            _webCtrl.handleDownload(url);
            return NavigationActionPolicy.CANCEL;
          }
        }

        return NavigationActionPolicy.ALLOW;
      },

      // ===== ERRO DE CARREGAMENTO =====
      onReceivedError: (controller, request, error) {
        final desc = error.description;
        if (desc.contains('net::ERR_INTERNET_DISCONNECTED') ||
            desc.contains('net::ERR_NAME_NOT_RESOLVED')) {
          if (mounted) {
            AppSnackBar.showError(
              context,
              'Sem conexão com a internet. Verifique sua rede.',
            );
          }
        }
      },

      // ===== ERRO DE CERTIFICADO SSL =====
      // Aceitar certificados universitários customizados
      onReceivedServerTrustAuthRequest: (controller, challenge) async {
        return ServerTrustAuthResponse(
          action: ServerTrustAuthResponseAction.PROCEED,
        );
      },

      // ===== ATUALIZAR ESTADO DE NAVEGAÇÃO =====
      onUpdateVisitedHistory: (controller, url, isReload) {
        _webCtrl.updateNavigationState();
      },
    );
  }

  @override
  void dispose() {
    _cancelToken?.cancel();
    _webCtrl.onDownloadComplete = null;
    _webCtrl.onDownloadError = null;
    _urlController.dispose();
    _urlFocusNode.dispose();
    super.dispose();
  }
}
