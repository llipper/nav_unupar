// lib/main.dart
//
// Ponto de entrada do aplicativo Portal Universitário.
//
// Responsabilidades:
// 1. Inicializar os bindings do Flutter
// 2. Configurar o WebView para Android (InAppWebView)
// 3. Solicitar permissões de armazenamento em tempo de execução
// 4. Iniciar o aplicativo

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:permission_handler/permission_handler.dart';

import 'app/app.dart';

void main() async {
  // Garante que os bindings do Flutter estejam inicializados
  // antes de qualquer operação assíncrona
  WidgetsFlutterBinding.ensureInitialized();

  // Configuração obrigatória do InAppWebView para Android
  if (Platform.isAndroid) {
    await InAppWebViewController.setWebContentsDebuggingEnabled(false);
  }

  // Solicitar permissões necessárias
  await _requestPermissions();

  // Iniciar o app
  runApp(const App());
}

/// Solicita permissões de armazenamento para Android 10+ com Scoped Storage.
/// Em Android 13+ (API 33), as permissões granulares são necessárias.
Future<void> _requestPermissions() async {
  if (!Platform.isAndroid) return;

  // Android 13+ (API 33): usa permissões granulares de mídia
  // Android 10-12: usa READ/WRITE_EXTERNAL_STORAGE
  // Nota: com minSdk=29 e targetSdk=35, escrita no scoped storage
  // não requer permissão, mas Documents/ precisa de tratamento especial.

  final permissions = <Permission>[
    Permission.storage,        // Para Android 9-12
    Permission.manageExternalStorage, // Para Android 11+ (acesso a Documents/)
  ];

  // Verificar quais permissões ainda não foram concedidas
  final statusMap = await permissions.request();

  // Verificar se pelo menos a permissão básica foi concedida
  // (manageExternalStorage pode ser negada sem prejudicar o funcionamento básico)
  final storageGranted = statusMap[Permission.storage]?.isGranted ?? false;
  final manageGranted =
      statusMap[Permission.manageExternalStorage]?.isGranted ?? false;

  // Se nenhuma permissão foi concedida, o app ainda funciona
  // pois usamos getExternalStorageDirectory() como fallback (pasta interna do app)
  debugPrint(
    'Permissões: storage=$storageGranted, manageExternal=$manageGranted',
  );
}
