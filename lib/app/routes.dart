// lib/app/routes.dart
//
// Definição centralizada das rotas nomeadas do aplicativo.

import 'package:flutter/material.dart';

import '../pages/browser_page.dart';
import '../pages/history_page.dart';
import '../pages/home_page.dart';

/// Classe com as constantes de nomes das rotas
class AppRoutes {
  AppRoutes._();

  static const String home = '/';
  static const String browser = '/browser';
  static const String history = '/history';
}

/// Mapa de rotas do MaterialApp
final Map<String, WidgetBuilder> appRoutes = {
  AppRoutes.home: (_) => const HomePage(),
  AppRoutes.browser: (_) => const BrowserPage(),
  AppRoutes.history: (_) => const HistoryPage(),
};
