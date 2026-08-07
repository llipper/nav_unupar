
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

  final TextEditingController _urlController = TextEditingController();
  final FocusNode _urlFocusNode = FocusNode();

  bool _isEditingUrl = false;

  @override
  void initState() {
    super.initState();

    _webCtrl = context.read<ctrl.WebViewController>();

    _urlController.text = AppConstants.portalUrl;

    _webCtrl.addListener(_syncUrl);

    _urlFocusNode.addListener(_handleFocus);

    _webCtrl.onDownloadComplete = (record) {
      if (!mounted) return;

      context.read<HistoryController>().addRecord(record);

      _dismissDialog();

      AppSnackBar.showSuccess(
        context,
        '✅ "${record.fileName}" baixado com sucesso.',
        actionLabel: kIsWeb ? null : 'Abrir',
        onAction: kIsWeb
            ? null
            : () {
                context.read<HistoryController>().openFile(record);
              },
      );
    };

    _webCtrl.onDownloadError = (message) {
      if (!mounted) return;

      _dismissDialog();

      AppSnackBar.showError(
        context,
        message,
      );
    };
  }

  // ============================================================
  // CONFIGURAÇÕES
  // ============================================================

  InAppWebViewSettings _settings() {
    if (kIsWeb) {
      return InAppWebViewSettings(
        javaScriptEnabled: true,

        iframeAllowFullscreen: true,

        iframeAllow:
            'camera; '
            'microphone; '
            'geolocation; '
            'clipboard-read; '
            'clipboard-write',
      );
    }

    return InAppWebViewSettings(
      userAgent: AppConstants.desktopUserAgent,

      javaScriptEnabled: true,

      domStorageEnabled: true,

      databaseEnabled: true,

      mixedContentMode:
          MixedContentMode.MIXED_CONTENT_ALWAYS_ALLOW,

      allowFileAccess: true,

      geolocationEnabled: true,

      supportMultipleWindows: false,

      useWideViewPort: true,

      loadWithOverviewMode: true,

      builtInZoomControls: true,

      displayZoomControls: false,
    );
  }

  // ============================================================
  // URL
  // ============================================================

  void _syncUrl() {
    if (!mounted) return;

    if (!_isEditingUrl &&
        _webCtrl.currentUrl.isNotEmpty) {
      _urlController.text =
          _webCtrl.currentUrl;
    }
  }

  void _handleFocus() {
    if (!mounted) return;

    if (!_urlFocusNode.hasFocus) {
      setState(() {
        _isEditingUrl = false;
      });

      _urlController.text =
          _webCtrl.currentUrl.isNotEmpty
              ? _webCtrl.currentUrl
              : AppConstants.portalUrl;
    }
  }

  void _navigateToUrl(String input) {
    String url = input.trim();

    if (url.isEmpty) return;

    if (!url.startsWith('http://') &&
        !url.startsWith('https://')) {
      if (url.contains('.') &&
          !url.contains(' ')) {
        url = 'https://$url';
      } else {
        url =
            'https://www.google.com/search?q=${Uri.encodeComponent(url)}';
      }
    }

    _urlController.text = url;

    setState(() {
      _isEditingUrl = false;
    });

    _urlFocusNode.unfocus();

    _webCtrl.webViewController?.loadUrl(
      urlRequest: URLRequest(
        url: WebUri(url),
      ),
    );
  }

  // ============================================================
  // DOWNLOAD
  // ============================================================

  void _dismissDialog() {
    if (!_dialogShowing || !mounted) {
      return;
    }

    Navigator.of(
      context,
      rootNavigator: true,
    ).pop();

    _dialogShowing = false;
  }

  void _showProgressDialog() {
    // O sistema de download via Dio/WebView
    // é usado apenas no Android/nativo.
    if (kIsWeb) return;

    if (_dialogShowing || !mounted) {
      return;
    }

    _dialogShowing = true;

    _cancelToken = CancelToken();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return AnimatedBuilder(
          animation: _webCtrl,
          builder: (_, __) {
            return DownloadProgressDialog(
              fileName:
                  _webCtrl.downloadingFileName,

              downloadedBytes:
                  _webCtrl.downloadedBytes,

              totalBytes:
                  _webCtrl.totalBytes,

              onCancel: () {
                _cancelToken?.cancel();

                _webCtrl.resetDownloadState();

                Navigator.of(ctx).pop();

                _dialogShowing = false;
              },
            );
          },
        );
      },
    ).then((_) {
      _dialogShowing = false;
    });
  }

  // ============================================================
  // WEBVIEW
  // ============================================================

  Widget _buildWebView() {
    return InAppWebView(
      initialUrlRequest: URLRequest(
        url: WebUri(
          AppConstants.portalUrl,
        ),

        // User-Agent customizado somente no
        // Android/nativo.
        headers: kIsWeb
            ? null
            : {
                'User-Agent':
                    AppConstants.desktopUserAgent,
              },
      ),

      initialSettings: _settings(),

      onWebViewCreated: (controller) {
        _webCtrl.webViewController =
            controller;
      },

      onLoadStart: (controller, url) {
        _webCtrl.onPageStarted(
          url?.toString() ?? '',
        );
      },

      onProgressChanged:
          (controller, progress) {
        _webCtrl.onProgressChanged(
          progress,
        );
      },

      onLoadStop:
          (controller, url) async {
        _webCtrl.onPageFinished(
          url?.toString() ?? '',
        );

        _webCtrl.updateNavigationState();
      },

      onTitleChanged:
          (controller, title) {
        _webCtrl.onTitleChanged(
          title ?? '',
        );
      },

      // ========================================================
      // DOWNLOAD
      // ========================================================

      onDownloadStartRequest:
          (controller, request) {
        final url =
            request.url.toString();

        // No navegador deixamos o próprio
        // browser cuidar do download.
        if (kIsWeb) {
          debugPrint(
            'Download WEB: $url',
          );

          return;
        }

        _showProgressDialog();

        _webCtrl.handleDownload(url);
      },

      // ========================================================
      // NAVEGAÇÃO
      // ========================================================

      shouldOverrideUrlLoading:
          (controller, action) async {
        final url =
            action.request.url
                    ?.toString() ??
                '';

        if (url.isEmpty) {
          return NavigationActionPolicy.ALLOW;
        }

        // Na Web não interceptamos navegação.
        //
        // Isso evita bloquear links,
        // formulários e downloads.
        if (kIsWeb) {
          return NavigationActionPolicy.ALLOW;
        }

        final lowerUrl =
            url.toLowerCase().split('?').first;

        const downloadExtensions = [
          '.docx',
          '.doc',
          '.xlsx',
          '.xls',
          '.pptx',
          '.ppt',
          '.pdf',
          '.zip',
          '.rar',
        ];

        for (final ext
            in downloadExtensions) {
          if (lowerUrl.endsWith(ext)) {
            _showProgressDialog();

            _webCtrl.handleDownload(url);

            return NavigationActionPolicy
                .CANCEL;
          }
        }

        return NavigationActionPolicy.ALLOW;
      },

      // ========================================================
      // ERROS
      // ========================================================

      onReceivedError:
          (controller, request, error) {
        debugPrint(
          'WEBVIEW ERROR: '
          '${error.type} '
          '${error.description}',
        );

        final description =
            error.description.toLowerCase();

        if (description.contains(
              'err_internet_disconnected',
            ) ||
            description.contains(
              'err_name_not_resolved',
            )) {
          if (!mounted) return;

          AppSnackBar.showError(
            context,
            'Sem conexão com a internet.',
          );
        }
      },

      // SSL customizado somente no Android.
      onReceivedServerTrustAuthRequest:
          kIsWeb
              ? null
              : (controller,
                    challenge) async {
                  return ServerTrustAuthResponse(
                    action:
                        ServerTrustAuthResponseAction
                            .PROCEED,
                  );
                },

      onUpdateVisitedHistory:
          (controller, url, isReload) {
        _webCtrl.updateNavigationState();
      },
    );
  }

  // ============================================================
  // INTERFACE
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor:
          const Color(0xFF0D1117),

      body: SafeArea(
        child: Column(
          children: [
            _buildNavigationBar(context),

            _buildPageProgressBar(),

            Expanded(
              child: _buildWebView(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNavigationBar(
    BuildContext context,
  ) {
    return Consumer<ctrl.WebViewController>(
      builder: (_, webCtrl, __) {
        return Container(
          color:
              const Color(0xFF161B22),

          padding:
              const EdgeInsets.symmetric(
            horizontal: 4,
            vertical: 6,
          ),

          child: Row(
            children: [
              // VOLTAR

              IconButton(
                icon: const Icon(
                  Icons
                      .arrow_back_ios_new_rounded,
                  size: 18,
                ),

                color: webCtrl.canGoBack
                    ? Colors.white
                    : Colors.white24,

                onPressed:
                    webCtrl.canGoBack
                        ? webCtrl.goBack
                        : null,

                tooltip: 'Voltar',
              ),

              // AVANÇAR

              IconButton(
                icon: const Icon(
                  Icons
                      .arrow_forward_ios_rounded,
                  size: 18,
                ),

                color: webCtrl.canGoForward
                    ? Colors.white
                    : Colors.white24,

                onPressed:
                    webCtrl.canGoForward
                        ? webCtrl.goForward
                        : null,

                tooltip: 'Avançar',
              ),

              // URL

              Expanded(
                child: Container(
                  height: 38,

                  margin:
                      const EdgeInsets.symmetric(
                    horizontal: 4,
                  ),

                  decoration: BoxDecoration(
                    color:
                        const Color(0xFF0D1117),

                    borderRadius:
                        BorderRadius.circular(10),

                    border: Border.all(
                      color:
                          _isEditingUrl
                              ? const Color(
                                  0xFF1A73E8,
                                )
                              : Colors.white12,
                    ),
                  ),

                  child: Row(
                    children: [
                      const SizedBox(width: 10),

                      Icon(
                        webCtrl.currentUrl
                                .startsWith(
                                  'https',
                                )
                            ? Icons.lock_rounded
                            : Icons
                                .lock_open_rounded,

                        size: 13,

                        color: webCtrl.currentUrl
                                .startsWith(
                                  'https',
                                )
                            ? Colors.greenAccent
                            : Colors.orange,
                      ),

                      const SizedBox(width: 8),

                      Expanded(
                        child: TextField(
                          controller:
                              _urlController,

                          focusNode:
                              _urlFocusNode,

                          keyboardType:
                              TextInputType.url,

                          textInputAction:
                              TextInputAction.go,

                          autocorrect: false,

                          enableSuggestions:
                              false,

                          style:
                              const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                          ),

                          decoration:
                              const InputDecoration(
                            border:
                                InputBorder.none,

                            isDense: true,

                            contentPadding:
                                EdgeInsets.zero,
                          ),

                          onSubmitted:
                              _navigateToUrl,

                          onTap: () {
                            setState(() {
                              _isEditingUrl =
                                  true;
                            });
                          },
                        ),
                      ),

                      if (_isEditingUrl)
                        IconButton(
                          icon: const Icon(
                            Icons.close,
                            size: 16,
                          ),

                          color: Colors.white54,

                          onPressed: () {
                            _urlController
                                .clear();

                            _urlFocusNode
                                .requestFocus();
                          },
                        ),
                    ],
                  ),
                ),
              ),

              // RECARREGAR

              IconButton(
                icon: Icon(
                  webCtrl.isLoading
                      ? Icons.close_rounded
                      : Icons.refresh_rounded,
                ),

                color: Colors.white70,

                onPressed:
                    webCtrl.isLoading
                        ? () {
                            webCtrl
                                .webViewController
                                ?.stopLoading();
                          }
                        : webCtrl.reload,

                tooltip:
                    webCtrl.isLoading
                        ? 'Parar'
                        : 'Recarregar',
              ),

              // HISTÓRICO

              IconButton(
                icon: const Icon(
                  Icons.folder_open_rounded,
                ),

                color: Colors.white70,

                onPressed: () {
                  Navigator.of(context)
                      .pushNamed(
                    AppRoutes.history,
                  );
                },

                tooltip: 'Histórico',
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPageProgressBar() {
    return Consumer<ctrl.WebViewController>(
      builder: (_, webCtrl, __) {
        if (!webCtrl.isLoading ||
            webCtrl.loadingProgress >= 1) {
          return const SizedBox.shrink();
        }

        return LinearProgressIndicator(
          value:
              webCtrl.loadingProgress,

          minHeight: 2,

          backgroundColor:
              Colors.transparent,

          valueColor:
              const AlwaysStoppedAnimation<
                  Color>(
            Color(0xFF1A73E8),
          ),
        );
      },
    );
  }

  // ============================================================
  // DISPOSE
  // ============================================================

  @override
  void dispose() {
    _cancelToken?.cancel();

    _webCtrl.removeListener(_syncUrl);

    _webCtrl.onDownloadComplete = null;
    _webCtrl.onDownloadError = null;

    _urlController.dispose();
    _urlFocusNode.dispose();

    super.dispose();
  }
}