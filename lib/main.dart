// lib/main.dart
//
// Ponto de entrada do aplicativo Portal Universitário.
//
// Responsabilidades:
// 1. Inicializar os bindings do Flutter
// 2. Configurar o WebView para Android (InAppWebView) se não estiver na Web
// 3. Solicitar permissões de armazenamento em tempo de execução no Android
// 4. Iniciar o aplicativo

import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:permission_handler/permission_handler.dart';

import 'app/app.dart';

void main() async {
  // Garante que os bindings do Flutter estejam inicializados
  // antes de qualquer operação assíncrona
  WidgetsFlutterBinding.ensureInitialized();

  // Configuração obrigatória do InAppWebView para Android (apenas nativo)
  if (!kIsWeb && Platform.isAndroid) {
    await InAppWebViewController.setWebContentsDebuggingEnabled(false);
  }

  // Solicitar permissões necessárias (apenas Android nativo)
  await _requestPermissions();

  // Iniciar o app
  runApp(const App());
}

/// Solicita permissões de armazenamento para Android 10+ com Scoped Storage.
Future<void> _requestPermissions() async {
  if (kIsWeb || !Platform.isAndroid) return;

  final permissions = <Permission>[
    Permission.storage,
    Permission.manageExternalStorage,
  ];

  final statusMap = await permissions.request();

  final storageGranted = statusMap[Permission.storage]?.isGranted ?? false;
  final manageGranted =
      statusMap[Permission.manageExternalStorage]?.isGranted ?? false;

  debugPrint(
    'Permissões: storage=$storageGranted, manageExternal=$manageGranted',
  );
}

